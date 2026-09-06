-- Foundational Edge — Supabase Storage support for question images.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe,
-- AFTER SETUP_QUESTIONS.sql and SETUP_QUESTIONS_IMAGES.sql have already run.
--
-- This adds a second, simpler way to attach an image to a question:
-- upload a photo/screenshot to a Storage bucket and paste its public URL
-- into image_url — no SVG markup needed. A question can use EITHER
-- image_svg (hand-drawn inline diagram) OR image_url (an uploaded photo),
-- whichever fits; skill-check.html checks image_svg first and falls back
-- to image_url.
--
-- Safe to run multiple times.

-- =========================================================
-- 1. Storage bucket — public, so uploaded images are servable directly
--    via a stable URL without any extra auth or signed-URL logic.
-- =========================================================
-- Marking a bucket "public" means its objects are servable at
--   {SUPABASE_URL}/storage/v1/object/public/question-images/<path>
-- with NO row-level-security check on read — this is the intended,
-- documented behavior for public buckets, not a security gap. Nothing
-- sensitive should ever go in this bucket (it's just question diagrams).
insert into storage.buckets (id, name, public)
values ('question-images', 'question-images', true)
on conflict (id) do update set public = true;

-- No storage.objects policies are needed for READS — public-bucket reads
-- bypass RLS by design (see above). Uploads happen through the Supabase
-- dashboard's Storage UI, which authenticates as the project owner (not
-- anon), so no anon INSERT policy is added either — anon still cannot
-- upload, list, or delete files in this bucket, only read what's already
-- there via the public URL.

-- =========================================================
-- 2. questions.image_url — the column ops pastes an uploaded image's
--    public URL into.
-- =========================================================
alter table questions add column if not exists image_url text;

-- =========================================================
-- 3. get_quiz_questions() must be dropped and recreated (not just
--    replaced) because CREATE OR REPLACE cannot change a function's
--    output column list (42P13) — same constraint noted in
--    SETUP_QUESTIONS_IMAGES.sql / SETUP.sql.
-- =========================================================
drop function if exists public.get_quiz_questions(text);
create or replace function public.get_quiz_questions(p_grade text)
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
  image_svg text,
  image_url text
)
language sql
security definer
set search_path = public
as $$
  select q.id, q.section, q.difficulty, q.order_num, q.question_text,
         q.option_a, q.option_b, q.option_c, q.option_d, q.image_svg, q.image_url
  from questions q
  where q.grade = p_grade
    and q.active = true
  order by q.order_num;
$$;

revoke all on function public.get_quiz_questions(text) from public;
grant execute on function public.get_quiz_questions(text) to anon;
