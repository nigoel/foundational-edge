-- Foundational Edge — one-time Supabase setup for practice-test.html's
-- registration/lookup feature. Run this in the Supabase SQL editor for
-- project wwmbpgtddsyettfdakbe (https://supabase.com/dashboard/project/wwmbpgtddsyettfdakbe).
--
-- Design: `anon` has NO direct privileges on the `registrations` table at
-- all — no SELECT, INSERT, or UPDATE grant/policy. Every operation goes
-- through one of two narrow SECURITY DEFINER functions below, each doing
-- exactly one controlled thing:
--   - register_child(...): upserts one row, returns only id + tier_link
--   - lookup_registration(...): finds one row by exact id or name+phone,
--     returns only id + tier_link
-- Neither function can be used to list, dump, or bulk-read the table.
--
-- (History: an earlier version of this script tried granting `anon` direct
-- INSERT/UPDATE policies instead. That turned out to be a dead end —
-- INSERT ... ON CONFLICT DO UPDATE requires SELECT-level RLS visibility to
-- check for an existing row, which conflicts with intentionally not
-- granting anon any SELECT access. Routing the whole upsert through a
-- SECURITY DEFINER function sidesteps that restriction entirely.)
--
-- Safe to run multiple times / even if `registrations` already has rows.

-- 1. Drop any direct-access policies from earlier attempts — anon should
--    have zero standing privileges on this table now.
drop policy if exists "public select" on registrations;
drop policy if exists "public insert" on registrations;
drop policy if exists "public update" on registrations;

-- 2. register_child(): the only way anon can write to this table. Performs
--    the insert-or-update itself as the function owner, bypassing RLS,
--    then returns just enough for the client to continue (id + tier link).
--    Explicit DROP first: CREATE OR REPLACE can't change a function's
--    output column names/types (42P13), and an earlier version of this
--    script created this function with different output column names.
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
-- Note: the output columns are deliberately NOT named `id`/`tier_link` —
-- RETURNS TABLE creates implicit PL/pgSQL variables with those names, which
-- would collide with (and shadow) the actual `id`/`tier_link` *columns*
-- referenced below in `on conflict (id)` etc., causing a "column reference
-- is ambiguous" error (42702). The client ignores this function's response
-- body entirely, so the exact output names don't matter to it.
returns table (result_id text, result_tier_link text)
language plpgsql
security definer
set search_path = public
as $$
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

  return query select p_id, p_tier_link;
end;
$$;

revoke all on function public.register_child(text, text, text, text, text, text, text, text, text) from public;
grant execute on function public.register_child(text, text, text, text, text, text, text, text, text) to anon;

-- 3. lookup_registration(): the only way anon can read from this table —
--    one exact match by id or by child_name + whatsapp, returning only
--    id + tier_link. Never a listing of the table.
create or replace function public.lookup_registration(
  p_id text default null,
  p_name text default null,
  p_phone text default null
)
returns table (id text, tier_link text)
language sql
security definer
set search_path = public
as $$
  select r.id, r.tier_link
  from registrations r
  where
    (p_id is not null and lower(r.id) = lower(p_id))
    or (p_name is not null and p_phone is not null
        and lower(r.child_name) = lower(p_name) and r.whatsapp = p_phone)
  limit 1;
$$;

revoke all on function public.lookup_registration(text, text, text) from public;
grant execute on function public.lookup_registration(text, text, text) to anon;

-- After this runs: anon can register_child() and lookup_registration(),
-- and nothing else — no direct table access of any kind.
