-- Foundational Edge — registration-exists detection, and quiz attempt
-- limiting (max 3) with full review support.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe,
-- AFTER SETUP.sql, SETUP_QUESTIONS.sql, and SETUP_QUESTIONS_STORAGE.sql
-- have already run.
--
-- Two independent changes:
--   1. register_child() now also returns whether the id already existed,
--      so practice-test.html can tell the family "you're already
--      registered" instead of silently re-saving over their old answers.
--   2. quiz_attempts gains a per-attempt snapshot (question text, options,
--      correct answer, explanation — not just the score) and a hard cap
--      of 3 attempts per (reg_id, grade), enforced server-side in
--      submit_quiz_attempt(). A new get_quiz_attempts() RPC lets
--      skill-check.html show past attempts and let the student review
--      any of them, exactly as they appeared at submission time (a
--      snapshot, so later question edits don't change historical review).
--
-- Safe to run multiple times.

-- =========================================================
-- 1. register_child() — add a was_existing flag to the response
-- =========================================================
-- Explicit DROP first: CREATE OR REPLACE can't change a function's output
-- column list (42P13), same constraint as every other migration here.
drop function if exists public.register_child(text, text, text, text, text, text, text, text, text);
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
returns table (result_id text, result_tier_link text, was_existing boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existed boolean;
begin
  select exists(select 1 from registrations where id = p_id) into v_existed;

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

  return query select p_id, p_tier_link, v_existed;
end;
$$;

revoke all on function public.register_child(text, text, text, text, text, text, text, text, text) from public;
grant execute on function public.register_child(text, text, text, text, text, text, text, text, text) to anon;

-- =========================================================
-- 2. quiz_attempts — add attempt_number + a full results snapshot
-- =========================================================
alter table quiz_attempts add column if not exists attempt_number integer;
alter table quiz_attempts add column if not exists results jsonb;

-- =========================================================
-- 3. submit_quiz_attempt() — cap at 3 attempts per (reg_id, grade),
--    snapshot full question/answer detail (not just the score) so it
--    can be reviewed later even if the question is edited or retired.
-- =========================================================
drop function if exists public.submit_quiz_attempt(text, text, jsonb);
create or replace function public.submit_quiz_attempt(
  p_reg_id text,
  p_grade text,
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
  v_prior_attempts integer;
  v_attempt_number integer;
  v_score integer := 0;
  v_total integer := 0;
  v_results jsonb := '[]'::jsonb;
  v_row record;
  v_given text;
  v_correct boolean;
begin
  -- Attempt counting only applies when we have a reg_id to key on; a null
  -- reg_id (shouldn't normally happen — practice-test.html always passes
  -- one) can't be limited, so let it through same as before.
  if p_reg_id is not null then
    select count(*) into v_prior_attempts
    from quiz_attempts
    where reg_id = p_reg_id and grade = p_grade;

    if v_prior_attempts >= 3 then
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
    where q.grade = p_grade and q.active = true
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

  insert into quiz_attempts (reg_id, grade, answers, score, total, attempt_number, results)
  values (p_reg_id, p_grade, p_answers, v_score, v_total, v_attempt_number, v_results);

  return query select true, null::text, v_attempt_number, v_score, v_total, v_results;
end;
$$;

revoke all on function public.submit_quiz_attempt(text, text, jsonb) from public;
grant execute on function public.submit_quiz_attempt(text, text, jsonb) to anon;

-- =========================================================
-- 4. get_quiz_attempts(reg_id, grade) — lets skill-check.html show past
--    attempts (score, when taken) and review any of them via the stored
--    results snapshot, without needing separate table access.
-- =========================================================
create or replace function public.get_quiz_attempts(p_reg_id text, p_grade text)
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
  where a.reg_id = p_reg_id and a.grade = p_grade
  order by a.attempt_number asc;
$$;

revoke all on function public.get_quiz_attempts(text, text) from public;
grant execute on function public.get_quiz_attempts(text, text) to anon;
