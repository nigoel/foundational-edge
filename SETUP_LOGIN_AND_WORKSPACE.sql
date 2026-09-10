-- Foundational Edge — returning-student login + personal workspace.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe,
-- AFTER SETUP.sql, SETUP_QUESTIONS.sql, SETUP_QUESTIONS_STORAGE.sql,
-- SETUP_ATTEMPTS_AND_REREGISTRATION.sql, and SETUP_QUIZZES.sql have all
-- already run.
--
-- Adds four new narrow, security-definer RPCs — same pattern as every
-- other table here: anon has zero direct table access, only these
-- specific, limited-output functions.
--
--   1. lookup_registrations_by_phone(phone) — returns every child
--      registered under that WhatsApp number (id, child_name, grade).
--      Lets a parent with more than one child log in with just their
--      phone number and pick which child's workspace to open, instead
--      of needing to remember/retype an exact regId.
--   2. get_student_profile(reg_id) — child_name + grade for a known
--      regId, so workspace.html can show "Welcome back, X!" even if
--      opened directly (bookmarked link) rather than via login.html.
--   3. get_workspace_quizzes(reg_id) — every active quiz for that
--      student's grade (Free Skill Check, Weekly Practice, Monthly
--      Competition alike), each row annotated with that student's own
--      attempt history (attempts used, latest score, latest attempt
--      date) — this single query is both the "assigned" and
--      "completed" list; the client buckets by attempts_used.
--   4. get_quiz_by_id(quiz_id) — same output shape as the existing
--      get_active_quiz(), but looked up by exact id instead of
--      grade+type. Lets skill-check.html deep-link straight to one
--      specific quiz from the workspace (e.g. a Weekly-Practice quiz)
--      for a real, gradable attempt — distinct from the existing
--      previewQuizId path, which is admin-only and never submits.
--
-- Safe to run multiple times.

-- =========================================================
-- 1. lookup_registrations_by_phone(phone)
-- =========================================================
create or replace function public.lookup_registrations_by_phone(p_phone text)
returns table (id text, child_name text, grade text)
language sql
security definer
set search_path = public
as $$
  select r.id, r.child_name, r.grade
  from registrations r
  where r.whatsapp = p_phone
  order by r.child_name;
$$;

revoke all on function public.lookup_registrations_by_phone(text) from public;
grant execute on function public.lookup_registrations_by_phone(text) to anon;

-- =========================================================
-- 2. get_student_profile(reg_id)
-- =========================================================
create or replace function public.get_student_profile(p_reg_id text)
returns table (child_name text, grade text)
language sql
security definer
set search_path = public
as $$
  select r.child_name, r.grade
  from registrations r
  where r.id = p_reg_id
  limit 1;
$$;

revoke all on function public.get_student_profile(text) from public;
grant execute on function public.get_student_profile(text) to anon;

-- =========================================================
-- 3. get_workspace_quizzes(reg_id)
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
  from quizzes z
  join registrations r on r.grade = z.grade
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
  where r.id = p_reg_id
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
-- 4. get_quiz_by_id(quiz_id) — same shape as get_active_quiz(), looked
--    up by exact id so skill-check.html can deep-link to one specific
--    quiz for a real attempt.
-- =========================================================
create or replace function public.get_quiz_by_id(p_quiz_id uuid)
returns table (
  quiz_id uuid,
  max_attempts integer,
  skill text,
  title text,
  quiz_type text,
  grade text
)
language sql
security definer
set search_path = public
as $$
  select z.id, z.max_attempts, z.skill, z.title, z.quiz_type, z.grade
  from quizzes z
  where z.id = p_quiz_id
    and z.active = true
    and (z.expiry_date is null or z.expiry_date >= current_date)
  limit 1;
$$;

revoke all on function public.get_quiz_by_id(uuid) from public;
grant execute on function public.get_quiz_by_id(uuid) to anon;

-- After this runs: anon can additionally look up every child under a
-- phone number, a single student's display profile, that student's
-- full quiz workspace (assigned + completed in one call), and any one
-- quiz by exact id — still with zero direct table access, same as
-- every other function in this project.
