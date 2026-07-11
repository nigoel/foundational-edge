-- Foundational Edge — one-time Supabase setup for practice-test.html's
-- registration/lookup feature. Run this in the Supabase SQL editor for
-- project wwmbpgtddsyettfdakbe (https://supabase.com/dashboard/project/wwmbpgtddsyettfdakbe).
--
-- Context: the original "public select" policy let anyone holding the
-- page's anon key read every row in `registrations` (every family's name,
-- WhatsApp number, country, grade) with a single REST call. This migration
-- removes that policy and replaces the "returning student" lookup with a
-- security-definer function that only ever returns the id + tier_link for
-- one exact match — never a listing of the table.
--
-- Safe to run even if `registrations` already has rows; it only touches
-- policies and adds a function.

-- 1. Remove the wide-open read policy.
drop policy if exists "public select" on registrations;

-- 1b. The registration form upserts (INSERT ... ON CONFLICT (id) DO UPDATE)
--     so a family re-registering with the same child+phone updates their
--     existing row instead of erroring. That conflict-update branch needs
--     an UPDATE policy — the original setup only granted INSERT, which
--     means re-registration would fail with a permission error. Anon is
--     already fully trusted for insert under this MVP design, so this
--     matches that same trust level rather than adding a new gap.
drop policy if exists "public update" on registrations;
create policy "public update" on registrations for update to anon using (true) with check (true);

-- 2. Narrow lookup function: returns id + tier_link for a single match by
--    registration id, or by child_name + whatsapp — nothing else, and never
--    more than one row. SECURITY DEFINER lets it read the table on behalf
--    of the anon caller without anon having a direct SELECT grant.
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

-- After this runs: anon can still INSERT (new registrations) and can call
-- lookup_registration() (returning-student lookups), but can no longer
-- SELECT the registrations table directly.
