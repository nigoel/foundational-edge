-- Foundational Edge — per-child quiz assignments, on top of the existing
-- grade-wide quiz model.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe,
-- AFTER SETUP_QUIZZES.sql and SETUP_LOGIN_AND_WORKSPACE.sql have both
-- already run.
--
-- WHY: today every quiz is broadcast to every student in its grade
-- (quizzes.grade = registrations.grade). There's no way to give one
-- specific child a quiz individually — e.g. a Weekly-Practice quiz meant
-- for just one student, or a quiz from a different grade for a student
-- working above/below grade level. This adds that as an ADDITIVE layer:
-- existing grade-wide quizzes keep working exactly as before; a row in
-- `assignments` is an extra, individually-targeted quiz on top.
--
-- Design (same conventions as every other table here): anon has zero
-- direct access to `assignments` — no policies, no grants. The only way
-- anon sees an assignment is through get_workspace_quizzes() below.
-- Creating an assignment is an ops action, done via the Table Editor
-- (same as creating a quiz in SETUP_QUIZZES.sql) — there's no anon-facing
-- "assign" RPC, since that would let any site visitor assign quizzes to
-- any child.
--
-- ALSO ADDS: the rule that the Free Skill Check drops out of the
-- workspace list once a child has a pending (not yet attempted)
-- individually-targeted assignment. It does NOT drop because of
-- ordinary grade-wide Weekly-Practice/Monthly-Competition quizzes —
-- only a specific, targeted assignment counts as "something else to do
-- first." If you'd rather have ANY pending grade-wide quiz also suppress
-- it, that's a one-line change (flagged in a comment below).
--
-- Safe to run multiple times.

-- =========================================================
-- 1. ASSIGNMENTS TABLE
-- =========================================================
create table if not exists assignments (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references quizzes(id) on delete cascade,
  reg_id text not null references registrations(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  unique (quiz_id, reg_id)  -- can't assign the same quiz to the same child twice
);

alter table assignments enable row level security;
-- No policies — anon has zero direct access, same pattern as every other
-- table in this project. All access goes through get_workspace_quizzes().

create index if not exists assignments_reg_idx on assignments (reg_id);

-- To assign a quiz to a specific child: insert one row here via the
-- Table Editor, e.g.
--   insert into assignments (quiz_id, reg_id) values ('<quiz uuid>', '<reg_id>');
-- Find quiz_id in the `quizzes` table, and reg_id in `registrations`
-- (search by child_name).


-- =========================================================
-- 2. get_workspace_quizzes(reg_id) — replaced to also include targeted
--    assignments, and to apply the free-check-drops-when-assigned rule.
--    Same output signature as before, so workspace.html needs NO changes.
-- =========================================================
create or replace function public.get_workspace_quizzes(p_reg_id text)
returns table (
  quiz_id uuid,
  quiz_type text,
  title text,
  max_attempts integer,
  attempts_used integer,
  latest_score integer,
  latest_total integer,
  latest_attempt_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  with candidate_quizzes as (
    -- existing behavior: every active, non-expired quiz for the child's own grade
    select z.*
    from quizzes z
    join registrations r on r.grade = z.grade
    where r.id = p_reg_id
      and z.active = true
      and (z.expiry_date is null or z.expiry_date >= current_date)

    union

    -- new: any quiz individually assigned to this specific child,
    -- regardless of grade match
    select z.*
    from quizzes z
    join assignments a on a.quiz_id = z.id
    where a.reg_id = p_reg_id
      and z.active = true
      and (z.expiry_date is null or z.expiry_date >= current_date)
  ),
  pending_targeted_assignments as (
    -- how many individually-assigned quizzes has this child NOT yet attempted?
    select count(*) as n
    from assignments a
    where a.reg_id = p_reg_id
      and not exists (
        select 1 from quiz_attempts qa
        where qa.reg_id = p_reg_id and qa.quiz_id = a.quiz_id
      )
  )
  select
    cq.id,
    cq.quiz_type,
    coalesce(cq.title, cq.quiz_type || ' — Grade ' || cq.grade),
    cq.max_attempts,
    coalesce(c.attempts_used, 0),
    la.score,
    la.total,
    la.submitted_at
  from candidate_quizzes cq
  left join lateral (
    select count(*) as attempts_used
    from quiz_attempts qa
    where qa.reg_id = p_reg_id and qa.quiz_id = cq.id
  ) c on true
  left join lateral (
    select qa.score, qa.total, qa.submitted_at
    from quiz_attempts qa
    where qa.reg_id = p_reg_id and qa.quiz_id = cq.id
    order by qa.attempt_number desc
    limit 1
  ) la on true
  where not (
    cq.quiz_type = 'Free-Skill-Test'
    and coalesce(c.attempts_used, 0) = 0   -- only suppress while un-taken; once completed it still shows in history
    and (select n from pending_targeted_assignments) > 0
    -- ^ to instead suppress the free check whenever ANY grade-wide
    --   Weekly-Practice/Monthly-Competition quiz is pending too, change
    --   this line to reference a count over `candidate_quizzes` filtered
    --   to quiz_type <> 'Free-Skill-Test' and attempts_used = 0 instead.
  )
  order by
    case cq.quiz_type
      when 'Free-Skill-Test' then 1
      when 'Weekly-Practice' then 2
      when 'Monthly-Competition' then 3
      else 4
    end,
    cq.publish_date desc;
$$;

revoke all on function public.get_workspace_quizzes(text) from public;
grant execute on function public.get_workspace_quizzes(text) to anon;
