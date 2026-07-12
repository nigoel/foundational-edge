-- Foundational Edge — skill_check_forms config table.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe
-- (https://supabase.com/dashboard/project/wwmbpgtddsyettfdakbe).
--
-- This is an admin-managed catalog of the Google Forms used for skill
-- checks — one row per (grade, skill type, test type) combination. It is
-- NOT yet wired into the live site (practice-test.html / skill-check.html
-- still use the hardcoded TIER_FORMS map) — this just creates the table so
-- you can start populating it via the Supabase Table Editor or SQL.
--
-- RLS is enabled with no policies at all, so `anon` (the site's public key)
-- has zero access to this table -- only you, via the Supabase dashboard
-- (which authenticates as you, not as anon), can read or write it. That's
-- deliberate: nothing here needs to be public yet. If/when you want the
-- live site to pick forms from this table automatically, say so and I'll
-- add a narrow security-definer function (same pattern as
-- lookup_registration/register_child in SETUP.sql) that exposes only
-- exactly what a page needs -- never a raw table read.

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
