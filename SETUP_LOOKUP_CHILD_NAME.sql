-- Foundational Edge — add child_name to lookup_registration()'s output.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe,
-- AFTER SETUP.sql has already run.
--
-- WHY: lookup_registration() (used by the "Returning student" tab on
-- practice-test.html) only ever returned { id, tier_link } — deliberately
-- minimal, to avoid anon being able to read anything beyond exactly what's
-- needed for one already-uniquely-matched row. That meant the client had
-- no way to display the child's actual name for a returning student, and
-- was instead guessing it by parsing the regId string itself (e.g.
-- "PriyaNair@..." -> "Priya Nair") — fragile, and wrong whenever the name
-- doesn't split cleanly. This adds child_name to the same single-row,
-- already-matched result — it does not loosen the "one exact match only,
-- never a listing" guarantee, since the row is already fully identified
-- by the existing id / name+phone match before this column is read.
--
-- Safe to run multiple times.

-- CREATE OR REPLACE can't change a function's output column set (42P13) —
-- explicit DROP first, same pattern used elsewhere in this repo whenever
-- a function's return shape changes.
drop function if exists public.lookup_registration(text, text, text);

create or replace function public.lookup_registration(
  p_id text default null,
  p_name text default null,
  p_phone text default null
)
returns table (id text, tier_link text, child_name text)
language sql
security definer
set search_path = public
as $$
  select r.id, r.tier_link, r.child_name
  from registrations r
  where
    (p_id is not null and lower(r.id) = lower(p_id))
    or (p_name is not null and p_phone is not null
        and lower(r.child_name) = lower(p_name) and r.whatsapp = p_phone)
  limit 1;
$$;

revoke all on function public.lookup_registration(text, text, text) from public;
grant execute on function public.lookup_registration(text, text, text) to anon;
