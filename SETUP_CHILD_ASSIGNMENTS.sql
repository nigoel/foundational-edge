-- Foundational Edge — creates the `assignments` table (per-child quiz
-- targeting, on top of the grade-wide quiz model).
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe,
-- AFTER SETUP_QUIZZES.sql and SETUP_LOGIN_AND_WORKSPACE.sql have both
-- already run. Follow it with SETUP_WORKSPACE_ASSIGNMENTS_ONLY.sql,
-- which is what actually defines current workspace behavior.
--
-- WHY: originally, every quiz was broadcast to every student in its
-- grade (quizzes.grade = registrations.grade), with no way to give one
-- specific child a quiz individually. This table is that missing piece —
-- one row per (quiz, child) assignment.
--
-- NOTE ON HISTORY: this file used to also define get_workspace_quizzes()
-- (grade-wide broadcast UNIONed with targeted assignments, plus a
-- free-check-suppression rule). That's gone — superseded by
-- SETUP_WORKSPACE_ASSIGNMENTS_ONLY.sql, which makes the workspace purely
-- assignment-driven instead (no more broadcast, no suppression rule
-- needed). Keeping both versions in the repo was causing confusion about
-- which one is actually live, so the old definition was removed from
-- here entirely rather than left as a stale reference.
--
-- Design (same conventions as every other table here): anon has zero
-- direct access to `assignments` — no policies, no grants. The only way
-- anon sees an assignment is through get_workspace_quizzes() (defined in
-- SETUP_WORKSPACE_ASSIGNMENTS_ONLY.sql). Creating an assignment is an
-- ops action, done via the Table Editor (same as creating a quiz in
-- SETUP_QUIZZES.sql) — there's no anon-facing "assign" RPC in this repo
-- (the separate foundational-edge-admin site has one, gated by its own
-- conventions), since that would let any site visitor assign quizzes to
-- any child.
--
-- Safe to run multiple times.

-- =========================================================
-- 1. ASSIGNMENTS TABLE
-- =========================================================
create table if not exists assignments (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references quizzes(id) on delete cascade,
  reg_id text not null references registrations(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  unique (quiz_id, reg_id)  -- can't assign the same quiz to the same child twice
);

alter table assignments enable row level security;
-- No policies — anon has zero direct access, same pattern as every other
-- table in this project. All access goes through get_workspace_quizzes().

create index if not exists assignments_reg_idx on assignments (reg_id);

-- To assign a quiz to a specific child: insert one row here via the
-- Table Editor, e.g.
--   insert into assignments (quiz_id, reg_id) values ('<quiz uuid>', '<reg_id>');
-- Find quiz_id in the `quizzes` table, and reg_id in `registrations`
-- (search by child_name).


-- =========================================================
-- 2. get_workspace_quizzes(reg_id) — SUPERSEDED.
--    The version that used to live here (grade-wide broadcast UNIONed
--    with targeted assignments, plus a free-check-suppression rule) has
--    been replaced entirely by SETUP_WORKSPACE_ASSIGNMENTS_ONLY.sql,
--    which makes the workspace purely assignment-driven instead. Run
--    that file (after this one) for the current definition — don't use
--    an older copy of this file as a reference, it no longer matches
--    what's actually deployed.
-- =========================================================
