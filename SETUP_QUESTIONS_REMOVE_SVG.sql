-- Foundational Edge — replace hand-drawn SVG diagrams with uploaded
-- Supabase Storage images.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe,
-- AFTER you have uploaded the 9 provided PNG files to the 'question-images'
-- bucket (see SETUP_QUESTIONS_STORAGE.sql for the bucket setup) using the
-- EXACT filenames below — the URLs this script sets assume those names.
--
-- Drops the image_svg column entirely (questions now use image_url only)
-- and points the 9 diagram questions at their uploaded image.
--
-- Safe to run once, after the 9 files are uploaded.

-- 1. Point each question at its uploaded image.
update questions set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/grade4_q6_paper_fold_diagonal.png'
  where grade = '4' and order_num = 6;

update questions set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/grade4_q7_paper_fold_edge.png'
  where grade = '4' and order_num = 7;

update questions set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/grade4_q8_double_fold_punch.png'
  where grade = '4' and order_num = 8;

update questions set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/grade4_q9_notch_pattern.png'
  where grade = '4' and order_num = 9;

update questions set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/grade4_q10_diagonal_double_punch.png'
  where grade = '4' and order_num = 10;

update questions set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/grade5_q17_quadrilateral_triangles.png'
  where grade = '5' and order_num = 17;

update questions set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/grade5_q18_rectangle_dimensions.png'
  where grade = '5' and order_num = 18;

update questions set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/grade5_q19_cube.png'
  where grade = '5' and order_num = 19;

update questions set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/grade5_q20_letter_r_flip.png'
  where grade = '5' and order_num = 20;

-- 2. Drop image_svg now that every diagram question uses image_url instead.
alter table questions drop column if exists image_svg;

-- 3. get_quiz_questions() must be dropped and recreated (not just replaced)
--    because CREATE OR REPLACE cannot change a function's output column
--    list (42P13) — same constraint noted in the earlier migration files.
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
  image_url text
)
language sql
security definer
set search_path = public
as $$
  select q.id, q.section, q.difficulty, q.order_num, q.question_text,
         q.option_a, q.option_b, q.option_c, q.option_d, q.image_url
  from questions q
  where q.grade = p_grade
    and q.active = true
  order by q.order_num;
$$;

revoke all on function public.get_quiz_questions(text) from public;
grant execute on function public.get_quiz_questions(text) to anon;
