-- Foundational Edge — skill_check_forms config table.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe
-- (https://supabase.com/dashboard/project/wwmbpgtddsyettfdakbe).
--
-- This is an admin-managed catalog of the Google Forms used for skill
-- checks — one row per (grade, skill type, test type) combination. You
-- manage rows via the Supabase Table Editor or SQL editor.
--
-- RLS is enabled with no direct policies for anon -- the site can only
-- reach this table through get_active_skill_form() below, a narrow
-- security-definer function (same pattern as lookup_registration /
-- register_child in SETUP.sql) that returns only form_url + regid_entry
-- for the single active row matching a grade, never a raw table read.
-- practice-test.html / skill-check.html use this to pick the free-test
-- form dynamically instead of a hardcoded map.

create table if not exists skill_check_forms (
  id uuid primary key default gen_random_uuid(),

  grade text not null
    check (grade in ('3','4','5','6','7','8')),

  skill_type text not null default 'all'
    check (skill_type in ('all','logical','quantitative','verbal')),

  type text not null default 'Free-Test'
    check (type in ('Free-Test','Weekly','Monthly','Competition')),

  competition_name text,

  form_url text not null,
  regid_entry text,  -- the form's entry.NNNNNN field id for the Registration ID question, if it has one

  publish_date date not null default current_date,
  last_response_date date,  -- null = no deadline, stays open indefinitely

  active boolean not null default true,

  created_at timestamptz not null default now(),

  -- competition_name should be set for Competition rows and empty otherwise, to keep the data clean
  constraint competition_name_matches_type check (
    (type = 'Competition' and competition_name is not null and competition_name <> '')
    or (type <> 'Competition' and competition_name is null)
  )
);

alter table skill_check_forms enable row level security;
-- No policies created -- RLS enabled with zero policies means nobody using
-- the anon/authenticated API keys can read or write this table at all.

create index if not exists skill_check_forms_lookup_idx
  on skill_check_forms (grade, skill_type, type, active);

-- get_active_skill_form(): the only way anon can read this table. Returns
-- the form for the free skill check matching a grade -- active rows only,
-- and when more than one matches, the one with the latest publish_date
-- wins. Intentionally scoped to type = 'Free-Test' (the only type the
-- public site currently offers a form for; Weekly/Monthly/Competition
-- rows are for future admin-side use, not yet exposed here) and skill_type
-- = 'all' or 'logical' is NOT filtered -- if you later add more than one
-- skill_type per grade for Free-Test, add a p_skill_type param here rather
-- than changing this comment and hoping.
create or replace function public.get_active_skill_form(p_grade text)
returns table (form_url text, regid_entry text)
language sql
security definer
set search_path = public
as $$
  select f.form_url, f.regid_entry
  from skill_check_forms f
  where f.grade = p_grade
    and f.active = true
    and f.type = 'Free-Test'
  order by f.publish_date desc
  limit 1;
$$;

revoke all on function public.get_active_skill_form(text) from public;
grant execute on function public.get_active_skill_form(text) to anon;
