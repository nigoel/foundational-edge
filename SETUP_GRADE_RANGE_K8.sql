-- Foundational Edge — open up grade range to Kindergarten through Grade 8.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe,
-- AFTER all previous SETUP_*.sql files have already run.
--
-- Every table that constrains `grade` to ('3','4','5','6','7','8') gets that
-- constraint widened to ('K','1','2','3','4','5','6','7','8'). Grade values
-- are stored as text throughout this project (not integers) specifically so
-- 'K' fits alongside the numbers without a type change.
--
-- Known constraints being widened: questions.grade, quizzes.grade.
-- The migration ALSO checks registrations.grade defensively, in case it has
-- its own constraint that was never captured in this repo's tracked SQL
-- (it's possible it does, since the registrations table itself predates
-- these tracked setup files and isn't created by any of them) — if it finds
-- one, it widens it the same way; if there isn't one, it does nothing there
-- and simply reports that in a NOTICE.
--
-- This finds each constraint by inspecting what's actually on the grade
-- column (via information_schema), rather than guessing at
-- auto-generated constraint names — safe to run even if a name differs
-- from what you'd expect.
--
-- Safe to run multiple times.

do $$
declare
  tbl text;
  cname text;
begin
  foreach tbl in array array['questions', 'quizzes', 'registrations']
  loop
    -- Find any CHECK constraint that references this table's grade column.
    select con.conname into cname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_attribute att on att.attrelid = rel.oid and att.attnum = any(con.conkey)
    where rel.relname = tbl
      and att.attname = 'grade'
      and con.contype = 'c'
    limit 1;

    if cname is not null then
      execute format('alter table %I drop constraint %I', tbl, cname);
      execute format(
        'alter table %I add constraint %I check (grade in (''K'',''1'',''2'',''3'',''4'',''5'',''6'',''7'',''8''))',
        tbl, cname
      );
      raise notice 'Widened % on table % to include K, 1, 2', cname, tbl;
    else
      raise notice 'No grade CHECK constraint found on table % — nothing to widen there', tbl;
    end if;
  end loop;
end $$;

-- After this runs: questions.grade, quizzes.grade, and (if it had one)
-- registrations.grade all accept 'K', '1', '2' in addition to '3'-'8'.
-- Nothing else changes — RLS policies, RPC signatures, and every other
-- constraint are untouched.
