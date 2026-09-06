-- Foundational Edge — fix image_url paths after images were reorganized
-- in Storage into a Quiz/<quiz_id>/<filename> folder structure (previously
-- flat at the bucket root).
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe,
-- AFTER SETUP_QUIZZES.sql has already run (this needs the quiz_id column
-- on questions to exist) AND after the 9 image files have been moved to
-- their new Quiz/<quiz_id>/<filename> locations in the question-images
-- bucket.
--
-- Each question's own quiz_id is used to build its image's new path —
-- no need to know the actual quiz UUIDs ahead of time, since the query
-- reads them from the row itself (via a scoped subquery, to make sure
-- each update only touches the intended grade's quiz).
--
-- Safe to run multiple times.

update questions
set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/Quiz/' || quiz_id::text || '/grade4_q6_paper_fold_diagonal.png'
where quiz_id = (select id from quizzes where quiz_type = 'Free-Skill-Test' and grade = '4' order by publish_date desc limit 1)
  and order_num = 6;

update questions
set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/Quiz/' || quiz_id::text || '/grade4_q7_paper_fold_edge.png'
where quiz_id = (select id from quizzes where quiz_type = 'Free-Skill-Test' and grade = '4' order by publish_date desc limit 1)
  and order_num = 7;

update questions
set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/Quiz/' || quiz_id::text || '/grade4_q8_double_fold_punch.png'
where quiz_id = (select id from quizzes where quiz_type = 'Free-Skill-Test' and grade = '4' order by publish_date desc limit 1)
  and order_num = 8;

update questions
set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/Quiz/' || quiz_id::text || '/grade4_q9_notch_pattern.png'
where quiz_id = (select id from quizzes where quiz_type = 'Free-Skill-Test' and grade = '4' order by publish_date desc limit 1)
  and order_num = 9;

update questions
set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/Quiz/' || quiz_id::text || '/grade4_q10_diagonal_double_punch.png'
where quiz_id = (select id from quizzes where quiz_type = 'Free-Skill-Test' and grade = '4' order by publish_date desc limit 1)
  and order_num = 10;

update questions
set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/Quiz/' || quiz_id::text || '/grade5_q17_quadrilateral_triangles.png'
where quiz_id = (select id from quizzes where quiz_type = 'Free-Skill-Test' and grade = '5' order by publish_date desc limit 1)
  and order_num = 17;

update questions
set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/Quiz/' || quiz_id::text || '/grade5_q18_rectangle_dimensions.png'
where quiz_id = (select id from quizzes where quiz_type = 'Free-Skill-Test' and grade = '5' order by publish_date desc limit 1)
  and order_num = 18;

update questions
set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/Quiz/' || quiz_id::text || '/grade5_q19_cube.png'
where quiz_id = (select id from quizzes where quiz_type = 'Free-Skill-Test' and grade = '5' order by publish_date desc limit 1)
  and order_num = 19;

update questions
set image_url = 'https://wwmbpgtddsyettfdakbe.supabase.co/storage/v1/object/public/question-images/Quiz/' || quiz_id::text || '/grade5_q20_letter_r_flip.png'
where quiz_id = (select id from quizzes where quiz_type = 'Free-Skill-Test' and grade = '5' order by publish_date desc limit 1)
  and order_num = 20;

-- Sanity check: run this after the updates above to eyeball the new URLs
-- before/while testing the site.
-- select grade_lookup.grade, q.order_num, q.image_url
-- from questions q
-- join quizzes grade_lookup on grade_lookup.id = q.quiz_id
-- where q.image_url is not null
-- order by grade_lookup.grade, q.order_num;
