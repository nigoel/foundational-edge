-- Foundational Edge — remove the legacy Google Forms skill-check plumbing.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe.
--
-- skill-check.html no longer calls get_active_skill_form() (it now uses
-- get_quiz_questions() / submit_quiz_attempt() from SETUP_QUESTIONS.sql
-- instead), so the skill_check_forms table and this function are dead —
-- nothing in the codebase references them anymore. This drops both.
--
-- Safe to run once. If you'd rather keep the historical data instead of
-- deleting it, skip the "drop table" line and just drop the function.

drop function if exists public.get_active_skill_form(text);
drop table if exists skill_check_forms;
