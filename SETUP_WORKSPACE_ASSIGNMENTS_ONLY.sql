-- Foundational Edge — make the workspace purely assignment-driven, and
-- auto-assign each new registration's Free Skill Test.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe,
-- AFTER SETUP.sql, SETUP_QUIZZES.sql, SETUP_LOGIN_AND_WORKSPACE.sql, and
-- SETUP_CHILD_ASSIGNMENTS.sql have all already run.
--
-- WHAT THIS CHANGES:
--
-- 1. get_workspace_quizzes(reg_id) no longer shows every grade-wide
--    active quiz automatically — it ONLY shows quizzes that have a row
--    in `assignments` for that child. The old grade-broadcast behavior
--    (every quiz for the child's grade, whether or not anyone assigned
--    it) is gone. Same output signature as before, so workspace.html
--    needs NO changes.
--
-- 2. Because of #1, a brand-new registration would otherwise land on an
--    empty workspace — nothing is auto-visible anymore. So
--    register_child() now also creates an assignment for that child's
--    grade's active Free Skill Test, right in the same transaction,
--    before the registration call even returns. This is what "added to
--    the assignment table before the workspace is shown" means in
--    practice: it happens server-side, synchronously, as part of
--    registering — there's no separate client-side step that could be
--    skipped or fail independently.
--
-- 3. One side effect worth knowing: the old rule where the Free Skill
--    Test would drop out of the workspace once something else was
--    individually assigned no longer applies — under this model the free
--    check is itself just another assignment row, so it and any other
--    assigned quiz (Weekly Practice, Monthly Competition) show side by
--    side like anything else. That suppression rule was built for the
--    grade-broadcast model this migration replaces; if you want it back
--    in some form, that's a follow-up, not something this migration
--    attempts to preserve.
--
-- 4. Backfill: every EXISTING registration gets an assignment to their
--    grade's active Free Skill Test too, so nobody who registered before
--    this change ends up with a suddenly-empty workspace.
--
-- Safe to run multiple times.

-- =========================================================
-- 1. register_child(...) — same signature/output as before (CREATE OR
--    REPLACE is safe, no DROP needed), now also auto-assigns the Free
--    Skill Test for the child's grade.
-- =========================================================
create or replace function public.register_child(
  p_id text,
  p_child_name text,
  p_parent_name text,
  p_country text,
  p_grade text,
  p_competitions text,
  p_expectations text,
  p_whatsapp text,
  p_tier_link text
)
returns table (result_id text, result_tier_link text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_quiz_id uuid;
begin
  insert into registrations
    (id, child_name, parent_name, country, grade, competitions, expectations, whatsapp, tier_link)
  values
    (p_id, p_child_name, p_parent_name, p_country, p_grade, p_competitions, p_expectations, p_whatsapp, p_tier_link)
  on conflict (id) do update set
    child_name = excluded.child_name,
    parent_name = excluded.parent_name,
    country = excluded.country,
    grade = excluded.grade,
    competitions = excluded.competitions,
    expectations = excluded.expectations,
    whatsapp = excluded.whatsapp,
    tier_link = excluded.tier_link;

  -- Auto-assign this grade's active Free Skill Test so the workspace
  -- (which now only shows what's actually assigned — see
  -- get_workspace_quizzes below) isn't empty the moment they register.
  -- Runs on every registration/re-registration; on conflict do nothing
  -- makes it a harmless no-op if the assignment already exists. If no
  -- active Free-Skill-Test quiz exists yet for this grade, this quietly
  -- does nothing rather than failing the registration itself.
  select gaq.quiz_id into v_quiz_id
  from get_active_quiz(p_grade, 'Free-Skill-Test') gaq;

  if v_quiz_id is not null then
    insert into assignments (quiz_id, reg_id)
    values (v_quiz_id, p_id)
    on conflict (quiz_id, reg_id) do nothing;
  end if;

  return query select p_id, p_tier_link;
end;
$$;

revoke all on function public.register_child(text, text, text, text, text, text, text, text, text) from public;
grant execute on function public.register_child(text, text, text, text, text, text, text, text, text) to anon;


-- =========================================================
-- 2. get_workspace_quizzes(reg_id) — now purely assignment-driven. No
--    more grade-wide broadcast join, no more free-check-suppression
--    logic (not needed — everything shown is already something that was
--    explicitly assigned, the free check included).
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
  select
    z.id,
    z.quiz_type,
    coalesce(z.title, z.quiz_type || ' — Grade ' || z.grade),
    z.max_attempts,
    coalesce(c.attempts_used, 0),
    la.score,
    la.total,
    la.submitted_at
  from assignments a
  join quizzes z on z.id = a.quiz_id
  left join lateral (
    select count(*) as attempts_used
    from quiz_attempts qa
    where qa.reg_id = p_reg_id and qa.quiz_id = z.id
  ) c on true
  left join lateral (
    select qa.score, qa.total, qa.submitted_at
    from quiz_attempts qa
    where qa.reg_id = p_reg_id and qa.quiz_id = z.id
    order by qa.attempt_number desc
    limit 1
  ) la on true
  where a.reg_id = p_reg_id
    and z.active = true
    and (z.expiry_date is null or z.expiry_date >= current_date)
  order by
    case z.quiz_type
      when 'Free-Skill-Test' then 1
      when 'Weekly-Practice' then 2
      when 'Monthly-Competition' then 3
      else 4
    end,
    z.publish_date desc;
$$;

revoke all on function public.get_workspace_quizzes(text) from public;
grant execute on function public.get_workspace_quizzes(text) to anon;


-- =========================================================
-- 3. Backfill — every existing registration also gets an assignment to
--    their grade's active Free Skill Test, so nobody who registered
--    before this migration lands on a suddenly-empty workspace.
-- =========================================================
insert into assignments (quiz_id, reg_id)
select gaq.quiz_id, r.id
from registrations r
cross join lateral get_active_quiz(r.grade, 'Free-Skill-Test') gaq
where gaq.quiz_id is not null
on conflict (quiz_id, reg_id) do nothing;
