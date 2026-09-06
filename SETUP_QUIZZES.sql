-- Foundational Edge — introduce a proper `quizzes` table instead of
-- hardcoding "grade" directly on questions/attempts.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe,
-- AFTER SETUP_QUESTIONS.sql, SETUP_QUESTIONS_STORAGE.sql,
-- SETUP_QUESTIONS_REMOVE_SVG.sql, and SETUP_ATTEMPTS_AND_REREGISTRATION.sql
-- have all already run (this migration assumes the `grade` column and the
-- attempt_number/results columns from those scripts already exist).
--
-- WHY: today every question/attempt is tied directly to a grade, and the
-- free skill check is the only quiz type. This introduces a `quizzes`
-- table — one row per (publish date, grade, quiz type, skill, max
-- attempts) — so:
--   - Each question belongs to exactly one quiz (quiz_id), not a bare grade.
--   - Each attempt records which quiz it belongs to (quiz_id).
--   - "Which quiz should this student see" becomes a real lookup: for a
--     given grade + quiz_type (e.g. 'Free-Skill-Test'), pick the active,
--     non-expired quiz with the latest publish_date — so you can publish
--     a new version of a quiz and the site picks it up automatically.
--   - max_attempts is now configurable PER QUIZ instead of a hardcoded 3
--     everywhere — a future Weekly-Practice or Monthly-Competition quiz
--     can have a different cap.
--
-- Safe to run multiple times.

-- =========================================================
-- 1. QUIZZES TABLE
-- =========================================================
create table if not exists quizzes (
  id uuid primary key default gen_random_uuid(),

  quiz_type text not null
    check (quiz_type in ('Free-Skill-Test', 'Weekly-Practice', 'Monthly-Competition')),

  grade text not null
    check (grade in ('3','4','5','6','7','8')),

  skill text not null default 'all'
    check (skill in ('verbal', 'reasoning', 'maths', 'all')),

  max_attempts integer not null default 3
    check (max_attempts > 0),

  publish_date date not null default current_date,
  expiry_date date,  -- null = never expires

  title text,  -- optional display name, e.g. "Grade 5 Free Skill Check — Sep 2026"

  active boolean not null default true,

  created_at timestamptz not null default now()
);

alter table quizzes enable row level security;
-- No policies created — anon has zero direct access. All access goes
-- through get_active_quiz() below (same pattern as every other table
-- here).

create index if not exists quizzes_lookup_idx
  on quizzes (grade, quiz_type, active, publish_date desc);

-- Seed the two quizzes that already implicitly exist today (the Grade 4
-- and Grade 5 free skill checks), so the questions/attempts backfill
-- below has something to point at. Ops can add more quizzes later
-- (new grades, Weekly-Practice, Monthly-Competition, or a fresh
-- Free-Skill-Test with a later publish_date to replace this one) the
-- same way — insert a row via the Table Editor.
insert into quizzes (quiz_type, grade, skill, max_attempts, publish_date, title)
select 'Free-Skill-Test', '4', 'all', 3, current_date, 'Grade 4 Free Skill Check'
where not exists (
  select 1 from quizzes where quiz_type = 'Free-Skill-Test' and grade = '4'
);

insert into quizzes (quiz_type, grade, skill, max_attempts, publish_date, title)
select 'Free-Skill-Test', '5', 'all', 3, current_date, 'Grade 5 Free Skill Check'
where not exists (
  select 1 from quizzes where quiz_type = 'Free-Skill-Test' and grade = '5'
);

-- =========================================================
-- 2. QUESTIONS — replace the bare `grade` column with quiz_id
-- =========================================================
alter table questions add column if not exists quiz_id uuid references quizzes(id);

-- Backfill: every existing question's grade maps to the Free-Skill-Test
-- quiz for that grade seeded above.
update questions q
set quiz_id = z.id
from quizzes z
where q.quiz_id is null
  and z.quiz_type = 'Free-Skill-Test'
  and z.grade = q.grade;

alter table questions alter column quiz_id set not null;
alter table questions drop column if exists grade;

drop index if exists questions_lookup_idx;  -- old grade-based index
create index if not exists questions_quiz_lookup_idx
  on questions (quiz_id, active, order_num);

-- =========================================================
-- 3. QUIZ_ATTEMPTS — add quiz_id (grade column is kept as a convenient
--    denormalized snapshot for display, but quiz_id is now the real key)
-- =========================================================
alter table quiz_attempts add column if not exists quiz_id uuid references quizzes(id);

update quiz_attempts a
set quiz_id = z.id
from quizzes z
where a.quiz_id is null
  and z.quiz_type = 'Free-Skill-Test'
  and z.grade = a.grade;

create index if not exists quiz_attempts_quiz_idx
  on quiz_attempts (reg_id, quiz_id);

-- =========================================================
-- 4. get_active_quiz(grade, quiz_type) — the lookup that replaces
--    hardcoding a grade filter directly. Picks the active, non-expired
--    quiz with the latest publish_date when more than one matches.
-- =========================================================
create or replace function public.get_active_quiz(
  p_grade text,
  p_quiz_type text default 'Free-Skill-Test'
)
returns table (
  quiz_id uuid,
  max_attempts integer,
  skill text,
  title text
)
language sql
security definer
set search_path = public
as $$
  select z.id, z.max_attempts, z.skill, z.title
  from quizzes z
  where z.grade = p_grade
    and z.quiz_type = p_quiz_type
    and z.active = true
    and (z.expiry_date is null or z.expiry_date >= current_date)
  order by z.publish_date desc
  limit 1;
$$;

revoke all on function public.get_active_quiz(text, text) from public;
grant execute on function public.get_active_quiz(text, text) to anon;

-- =========================================================
-- 5. get_quiz_questions(quiz_id) — now takes quiz_id instead of grade.
--    Drops the old grade-based version from SETUP_QUESTIONS.sql /
--    SETUP_QUESTIONS_STORAGE.sql / SETUP_QUESTIONS_REMOVE_SVG.sql.
-- =========================================================
drop function if exists public.get_quiz_questions(text);
create or replace function public.get_quiz_questions(p_quiz_id uuid)
returns table (
  id uuid,
  section text,
  difficulty text,
  order_num integer,
  question_text text,
  option_a text,
  option_b text,
  option_c text,
  option_d text,
  image_url text
)
language sql
security definer
set search_path = public
as $$
  select q.id, q.section, q.difficulty, q.order_num, q.question_text,
         q.option_a, q.option_b, q.option_c, q.option_d, q.image_url
  from questions q
  where q.quiz_id = p_quiz_id
    and q.active = true
  order by q.order_num;
$$;

revoke all on function public.get_quiz_questions(uuid) from public;
grant execute on function public.get_quiz_questions(uuid) to anon;

-- =========================================================
-- 6. submit_quiz_attempt(reg_id, quiz_id, answers) — now takes quiz_id,
--    and reads max_attempts from the quiz row instead of a hardcoded 3.
--    Drops the old (text, text, jsonb) version from
--    SETUP_ATTEMPTS_AND_REREGISTRATION.sql.
-- =========================================================
drop function if exists public.submit_quiz_attempt(text, text, jsonb);
create or replace function public.submit_quiz_attempt(
  p_reg_id text,
  p_quiz_id uuid,
  p_answers jsonb
)
returns table (
  success boolean,
  error_message text,
  attempt_number integer,
  score integer,
  total integer,
  results jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max_attempts integer;
  v_grade text;
  v_prior_attempts integer;
  v_attempt_number integer;
  v_score integer := 0;
  v_total integer := 0;
  v_results jsonb := '[]'::jsonb;
  v_row record;
  v_given text;
  v_correct boolean;
begin
  select z.max_attempts, z.grade into v_max_attempts, v_grade
  from quizzes z
  where z.id = p_quiz_id;

  if v_max_attempts is null then
    return query select false, 'quiz_not_found'::text, null::integer, null::integer, null::integer, null::jsonb;
    return;
  end if;

  if p_reg_id is not null then
    select count(*) into v_prior_attempts
    from quiz_attempts
    where reg_id = p_reg_id and quiz_id = p_quiz_id;

    if v_prior_attempts >= v_max_attempts then
      return query select false, 'max_attempts_reached'::text, v_prior_attempts, null::integer, null::integer, null::jsonb;
      return;
    end if;
    v_attempt_number := v_prior_attempts + 1;
  else
    v_attempt_number := 1;
  end if;

  for v_row in
    select q.id, q.section, q.order_num, q.question_text,
           q.option_a, q.option_b, q.option_c, q.option_d,
           q.correct_answer, q.explanation
    from questions q
    where q.quiz_id = p_quiz_id and q.active = true
    order by q.order_num
  loop
    v_total := v_total + 1;
    v_given := p_answers ->> v_row.id::text;
    v_correct := (v_given is not null and upper(v_given) = v_row.correct_answer);
    if v_correct then
      v_score := v_score + 1;
    end if;

    v_results := v_results || jsonb_build_object(
      'question_id', v_row.id,
      'section', v_row.section,
      'order_num', v_row.order_num,
      'question_text', v_row.question_text,
      'option_a', v_row.option_a,
      'option_b', v_row.option_b,
      'option_c', v_row.option_c,
      'option_d', v_row.option_d,
      'given_answer', v_given,
      'correct_answer', v_row.correct_answer,
      'is_correct', v_correct,
      'explanation', v_row.explanation
    );
  end loop;

  insert into quiz_attempts (reg_id, grade, quiz_id, answers, score, total, attempt_number, results)
  values (p_reg_id, v_grade, p_quiz_id, p_answers, v_score, v_total, v_attempt_number, v_results);

  return query select true, null::text, v_attempt_number, v_score, v_total, v_results;
end;
$$;

revoke all on function public.submit_quiz_attempt(text, uuid, jsonb) from public;
grant execute on function public.submit_quiz_attempt(text, uuid, jsonb) to anon;

-- =========================================================
-- 7. get_quiz_attempts(reg_id, quiz_id) — now takes quiz_id instead of
--    grade. Drops the old (text, text) version from
--    SETUP_ATTEMPTS_AND_REREGISTRATION.sql.
-- =========================================================
drop function if exists public.get_quiz_attempts(text, text);
create or replace function public.get_quiz_attempts(p_reg_id text, p_quiz_id uuid)
returns table (
  attempt_number integer,
  score integer,
  total integer,
  submitted_at timestamptz,
  results jsonb
)
language sql
security definer
set search_path = public
as $$
  select a.attempt_number, a.score, a.total, a.submitted_at, a.results
  from quiz_attempts a
  where a.reg_id = p_reg_id and a.quiz_id = p_quiz_id
  order by a.attempt_number asc;
$$;

revoke all on function public.get_quiz_attempts(text, uuid) from public;
grant execute on function public.get_quiz_attempts(text, uuid) to anon;
