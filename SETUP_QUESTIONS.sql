-- Foundational Edge — custom skill-check questions system.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe
-- (https://supabase.com/dashboard/project/wwmbpgtddsyettfdakbe).
--
-- Replaces the Google Forms embed (skill_check_forms / get_active_skill_form,
-- see SETUP_SKILL_FORMS.sql) with a first-party question bank that a
-- non-technical operations person can manage directly from the Supabase
-- Table Editor — no Google Forms account, no code changes, no redeploy.
--
-- Security follows the same pattern as SETUP.sql / SETUP_SKILL_FORMS.sql:
-- RLS is enabled on both tables with ZERO direct policies for anon. The
-- public site can only reach this data through two narrow SECURITY DEFINER
-- functions:
--   - get_quiz_questions(grade): returns question text + options only —
--     never correct_answer or explanation, so the answer key can't be
--     read from the browser before submitting.
--   - submit_quiz_attempt(reg_id, grade, answers): grades the submission
--     SERVER-SIDE against the real correct_answer, stores the attempt,
--     and returns the score plus a review (correct answers + explanations)
--     for AFTER submission only.
--
-- Safe to run multiple times.

-- =========================================================
-- 1. QUESTIONS TABLE — this is what ops/teachers manage day-to-day
-- =========================================================
create table if not exists questions (
  id uuid primary key default gen_random_uuid(),

  grade text not null
    check (grade in ('3','4','5','6','7','8')),

  section text not null,       -- e.g. 'Logical Reasoning', 'Quantitative Aptitude'
  difficulty text
    check (difficulty in ('Easy','Easy-Medium','Medium','Medium-Advanced','Advanced')),

  order_num integer not null,  -- controls display order within a grade

  question_text text not null,

  -- Multiple choice only, by design — this keeps grading simple, reliable,
  -- and fully server-side. If you need free-text/numeric answers later,
  -- add a question_type column and a second grading path.
  option_a text not null,
  option_b text not null,
  option_c text not null,
  option_d text not null,
  correct_answer text not null check (correct_answer in ('A','B','C','D')),

  explanation text,            -- shown to the student after they submit

  active boolean not null default true,  -- set false to retire a question without deleting it

  created_at timestamptz not null default now()
);

alter table questions enable row level security;
-- No policies created — anon has zero direct read/write access to this
-- table. All access goes through get_quiz_questions() below.

create index if not exists questions_lookup_idx
  on questions (grade, active, order_num);

-- =========================================================
-- 2. QUIZ ATTEMPTS TABLE — one row per submitted skill check
-- =========================================================
create table if not exists quiz_attempts (
  id uuid primary key default gen_random_uuid(),

  reg_id text,          -- ties back to registrations.id (practice-test.html), nullable in case of edge cases
  grade text not null,

  answers jsonb not null,   -- { "<question_id>": "A", ... } as submitted
  score integer not null,
  total integer not null,

  submitted_at timestamptz not null default now()
);

alter table quiz_attempts enable row level security;
-- No policies created — anon cannot read attempts back directly. Ops can
-- view results via the Supabase Table Editor (which uses the service role,
-- bypassing RLS) or a future admin-only view.

create index if not exists quiz_attempts_reg_idx
  on quiz_attempts (reg_id);

-- =========================================================
-- 3. get_quiz_questions(grade) — the only way anon can read questions
-- =========================================================
-- Deliberately excludes correct_answer and explanation from the return
-- type, so a student inspecting network requests in the browser cannot
-- see the answer key before submitting.
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
  option_d text
)
language sql
security definer
set search_path = public
as $$
  select q.id, q.section, q.difficulty, q.order_num, q.question_text,
         q.option_a, q.option_b, q.option_c, q.option_d
  from questions q
  where q.grade = p_grade
    and q.active = true
  order by q.order_num;
$$;

revoke all on function public.get_quiz_questions(text) from public;
grant execute on function public.get_quiz_questions(text) to anon;

-- =========================================================
-- 4. submit_quiz_attempt(reg_id, grade, answers) — grades server-side
-- =========================================================
-- p_answers is a jsonb object: { "<question_id>": "A" | "B" | "C" | "D", ... }
-- Returns the score/total plus a per-question review (correct answer +
-- explanation) — safe to reveal only now that the attempt is submitted
-- and stored.
create or replace function public.submit_quiz_attempt(
  p_reg_id text,
  p_grade text,
  p_answers jsonb
)
returns table (
  score integer,
  total integer,
  results jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_score integer := 0;
  v_total integer := 0;
  v_results jsonb := '[]'::jsonb;
  v_row record;
  v_given text;
  v_correct boolean;
begin
  for v_row in
    select q.id, q.correct_answer, q.explanation, q.order_num
    from questions q
    where q.grade = p_grade and q.active = true
    order by q.order_num
  loop
    v_total := v_total + 1;
    v_given := p_answers ->> v_row.id::text;
    v_correct := (v_given is not null and upper(v_given) = v_row.correct_answer);
    if v_correct then
      v_score := v_score + 1;
    end if;

    v_results := v_results || jsonb_build_object(
      'question_id', v_row.id,
      'given_answer', v_given,
      'correct_answer', v_row.correct_answer,
      'is_correct', v_correct,
      'explanation', v_row.explanation
    );
  end loop;

  insert into quiz_attempts (reg_id, grade, answers, score, total)
  values (p_reg_id, p_grade, p_answers, v_score, v_total);

  return query select v_score, v_total, v_results;
end;
$$;

revoke all on function public.submit_quiz_attempt(text, text, jsonb) from public;
grant execute on function public.submit_quiz_attempt(text, text, jsonb) to anon;

-- =========================================================
-- 5. SEED DATA — Grade 4 and Grade 5 free skill-check questions
-- =========================================================
-- Sourced from the teacher-provided practice sets, cleaned up into
-- multiple-choice format for reliable auto-grading (a couple of flagged
-- answer-key issues were also fixed — e.g. Grade 4 Q13's original
-- non-whole-number version, and Grade 5's duplicate set that had a
-- broken unscramble question was dropped in favor of the clean set).
--
-- To ADD MORE QUESTIONS later (e.g. Grade 3, 6, 7, 8), insert more rows
-- into `questions` the same way — via the Supabase Table Editor or more
-- INSERT statements like the one below. No code or deploy needed.
-- Seed data: Grade 4 and Grade 5 free skill-check questions
-- Generated from teacher-provided practice sets (cleaned up into MCQ format
-- for reliable auto-grading; a couple of flagged answer-key issues were fixed).
insert into questions
  (grade, section, difficulty, order_num, question_text, option_a, option_b, option_c, option_d, correct_answer, explanation, active)
values
  ('4', 'Logical Reasoning', 'Easy', 1, 'Look at the pattern: 2, 4, 6, 8, __, 12. What number belongs in the blank?', '9', '10', '11', '14', 'B', 'The pattern adds 2 each time: 2, 4, 6, 8, 10, 12.', true),
  ('4', 'Logical Reasoning', 'Easy-Medium', 2, 'If all Zorbs are Trilbs, and all Trilbs are Wimps, which statement MUST be true?', 'All Wimps are Zorbs', 'All Zorbs are Wimps', 'No Zorbs are Wimps', 'All Trilbs are Zorbs', 'B', 'By the transitive property: Zorb implies Trilb, and Trilb implies Wimp, so Zorb implies Wimp.', true),
  ('4', 'Logical Reasoning', 'Medium', 3, 'Four friends — Ana, Ben, Cara, and Dan — sit in a row of 4 chairs numbered 1 to 4. Ana sits next to Ben. Cara sits in chair 1. Dan does not sit next to Cara. Who sits in chair 4?', 'Ana', 'Ben', 'Cara', 'Dan', 'D', 'Cara is in chair 1, so chair 2 cannot be Dan (he cannot sit next to Cara). Ana and Ben must be adjacent, which only works in chairs 2-3, leaving Dan in chair 4.', true),
  ('4', 'Logical Reasoning', 'Medium-Advanced', 4, 'A sequence follows the rule: "Add 3, then subtract 1, then add 3, then subtract 1..." Starting at 5, what is the 6th number in the sequence (including the starting number as the 1st)?', '10', '11', '12', '14', 'C', 'Sequence: 5, 8, 7, 10, 9, 12 — the 6th term is 12.', true),
  ('4', 'Logical Reasoning', 'Advanced', 5, 'In a code, CAT is written as 3-1-20, using each letter''s position in the alphabet. Using the same code, what word is represented by 4-15-7?', 'DOG', 'EOG', 'COG', 'FOG', 'A', 'D is the 4th letter, O is the 15th letter, G is the 7th letter — spelling DOG.', true),
  ('4', 'Paper Folding & Spatial Reasoning', 'Easy', 6, 'A square piece of paper is folded in half once, corner to corner, forming a triangle. How many layers of paper are there after this one fold?', '1', '2', '3', '4', 'B', 'One fold always doubles the paper into 2 layers.', true),
  ('4', 'Paper Folding & Spatial Reasoning', 'Easy-Medium', 7, 'A square paper is folded exactly in half (edge to edge) one time. What shape is formed?', 'Triangle', 'Rectangle', 'Square', 'Pentagon', 'B', 'Folding a square edge-to-edge halves its width, producing a rectangle.', true),
  ('4', 'Paper Folding & Spatial Reasoning', 'Medium', 8, 'A square sheet of paper is folded in half twice (first edge to edge, then edge to edge again), forming a smaller square. A single hole is punched through the corner where all folded edges meet. When unfolded, how many holes will appear in the paper?', '1', '2', '4', '8', 'C', 'Two folds create 4 layers at that corner, so one punch makes 4 holes when unfolded.', true),
  ('4', 'Paper Folding & Spatial Reasoning', 'Medium-Advanced', 9, 'A rectangular piece of paper is folded in half from left to right, then folded in half again from top to bottom. A triangle-shaped notch is cut from the free corner (no folded edges). When fully unfolded, how many notches will there be, and what pattern do they form near the center?', '1 notch', '2 notches', '4 notches, forming a diamond-like pattern', '8 notches', 'C', 'Two folds create 4 layers; cutting the free corner produces 4 notches that form a diamond/rhombus-like pattern near the center when unfolded.', true),
  ('4', 'Paper Folding & Spatial Reasoning', 'Advanced', 10, 'A square paper is folded diagonally to form a triangle, then folded diagonally again to form a smaller triangle. One hole is punched near the folded point that touches all layers, and one hole is punched near the outer open edge. When unfolded, how many total holes appear?', '4', '6', '8', '16', 'C', 'Each fold doubles the layers (2 folds = 4 layers), so each of the two punch locations produces 4 holes — 4 + 4 = 8 total.', true),
  ('4', 'Quantitative Aptitude', 'Easy', 11, 'Maria has 24 stickers. She gives 1/3 of them to her brother. How many stickers does Maria have left?', '8', '12', '16', '18', 'C', '1/3 of 24 is 8, so Maria gives away 8 and keeps 24 − 8 = 16.', true),
  ('4', 'Quantitative Aptitude', 'Easy-Medium', 12, 'A rectangular garden is 8 feet long and 5 feet wide. What is the perimeter of the garden?', '13 feet', '26 feet', '40 feet', '45 feet', 'B', 'Perimeter = 2 × (length + width) = 2 × (8 + 5) = 26 feet.', true),
  ('4', 'Quantitative Aptitude', 'Medium', 13, 'The sum of two numbers is 48. One number is 3 times the other. What are the two numbers?', '12 and 36', '15 and 33', '9 and 39', '20 and 28', 'A', 'Let the smaller number be n, so n + 3n = 48 → 4n = 48 → n = 12. The numbers are 12 and 36.', true),
  ('4', 'Quantitative Aptitude', 'Medium-Advanced', 14, 'A store sells pencils in packs of 6 and erasers in packs of 4. Jordan wants the exact same number of pencils and erasers, using the smallest number of packs possible. How many packs of each, and how many pencils/erasers in total?', '2 packs of pencils, 3 packs of erasers (12 each)', '3 packs of pencils, 2 packs of erasers (18 and 8)', '1 pack of each (6 and 4)', '4 packs of pencils, 6 packs of erasers (24 each)', 'A', 'The smallest matching total is the LCM of 6 and 4, which is 12 — needing 2 packs of pencils (2×6=12) and 3 packs of erasers (3×4=12).', true),
  ('4', 'Quantitative Aptitude', 'Advanced', 15, 'A number is multiplied by 4, then 7 is subtracted from the result, giving 41. What was the original number?', '9', '10', '12', '14', 'C', '4n − 7 = 41 → 4n = 48 → n = 12.', true),
  ('4', 'Verbal Reasoning', 'Easy', 16, 'Choose the word that does NOT belong with the others: apple, banana, carrot, grape', 'Apple', 'Banana', 'Carrot', 'Grape', 'C', 'Carrot is a vegetable; the others are all fruits.', true),
  ('4', 'Verbal Reasoning', 'Easy-Medium', 17, 'Complete the analogy: Puppy is to Dog as Kitten is to ____.', 'Cat', 'Dog', 'Kitten', 'Feline', 'A', 'A puppy is a baby dog, just as a kitten is a baby cat.', true),
  ('4', 'Verbal Reasoning', 'Medium', 18, 'Complete the analogy: Author is to Book as Composer is to ____.', 'Music', 'Painting', 'Sculpture', 'Poem', 'A', 'An author creates a book, just as a composer creates a piece of music.', true),
  ('4', 'Verbal Reasoning', 'Medium-Advanced', 19, 'Unscramble the letters T-N-E-I-G-A to form a real word, then choose its synonym.', 'Small', 'Huge', 'Quiet', 'Fast', 'B', 'The unscrambled word is GIANT, which means Huge.', true),
  ('4', 'Verbal Reasoning', 'Advanced', 20, '"Every time the wind blew hard, the old lighthouse creaked, but it never once let its flame go dark, even during the fiercest storms." Which word BEST describes the lighthouse?', 'Fragile', 'Reliable', 'Silent', 'New', 'B', 'Despite the storms, the lighthouse kept its light on — a sign of reliability.', true),
  ('5', 'Logical Reasoning', 'Easy', 1, 'Look at the pattern: 2, 5, 8, 11, __, 17. What number belongs in the blank?', '13', '14', '15', '16', 'B', 'The pattern adds 3 each time: 2, 5, 8, 11, 14, 17.', true),
  ('5', 'Logical Reasoning', 'Easy-Medium', 2, 'If all Florps are Wibbles, and no Wibbles are Zants, which statement MUST be true?', 'All Florps are Zants', 'No Florps are Zants', 'Some Florps are Zants', 'All Zants are Wibbles', 'B', 'Since all Florps are Wibbles, and no Wibbles are Zants, Florps cannot be Zants either.', true),
  ('5', 'Logical Reasoning', 'Medium', 3, 'Five kids — Maya, Noah, Priya, Quinn, and Ravi — stand in a line of 5 spots. Priya is first. Maya is not first or last. Noah stands immediately after Maya. Quinn stands immediately before Ravi. Ravi is not last. What is the full order, first to last?', 'Priya, Quinn, Ravi, Maya, Noah', 'Priya, Maya, Noah, Quinn, Ravi', 'Quinn, Priya, Ravi, Maya, Noah', 'Priya, Ravi, Quinn, Maya, Noah', 'A', 'Testing the clues, the only order that satisfies all of them is: Priya, Quinn, Ravi, Maya, Noah.', true),
  ('5', 'Logical Reasoning', 'Medium-Advanced', 4, 'A sequence follows the rule: "Add 4, then subtract 2, then add 4, then subtract 2..." Starting at 3, what is the 5th number in the sequence (including the starting number as the 1st)?', '5', '7', '9', '11', 'B', 'Sequence: 3, 7, 5, 9, 7 — the 5th term is 7.', true),
  ('5', 'Logical Reasoning', 'Advanced', 5, 'You have 8 identical-looking coins, but one is fake and slightly lighter. Using a two-pan balance scale, what is the minimum number of weighings needed to guarantee finding the fake coin?', '1', '2', '3', '4', 'B', 'Split into groups of 3, 3, and 2. Weigh the two groups of 3: if they balance, the fake is in the group of 2 (1 more weighing finds it); if not, weigh 2 of the lighter group of 3 against each other.', true),
  ('5', 'Quantitative Aptitude', 'Easy', 6, 'A pizza is cut into 8 equal slices. If Ben eats 3 slices, what fraction of the pizza is left?', '3/8', '5/8', '3/5', '5/5', 'B', '8 − 3 = 5 slices remain out of 8, so 5/8 of the pizza is left.', true),
  ('5', 'Quantitative Aptitude', 'Easy-Medium', 7, 'A rectangular classroom is 20 feet by 15 feet. What is its area, in square feet?', '35', '150', '300', '600', 'C', 'Area = length × width = 20 × 15 = 300 square feet.', true),
  ('5', 'Quantitative Aptitude', 'Medium', 8, 'Sarah has $45. She spends 2/5 of it on a book. How much money does she have left?', '$18', '$25', '$27', '$30', 'C', '2/5 of $45 = $18 spent, leaving $45 − $18 = $27.', true),
  ('5', 'Quantitative Aptitude', 'Medium-Advanced', 9, 'What is the smallest positive number that is divisible by both 6 and 8?', '12', '16', '24', '48', 'C', 'The least common multiple of 6 (2×3) and 8 (2³) is 2³×3 = 24.', true),
  ('5', 'Quantitative Aptitude', 'Advanced', 10, 'A number increased by 15% equals 69. What is the original number?', '54', '58.65', '60', '65', 'C', 'If the original number is n, then 1.15n = 69, so n = 69 ÷ 1.15 = 60.', true),
  ('5', 'Verbal Reasoning', 'Easy', 11, 'Choose the word that does NOT belong with the others: hammer, screwdriver, wrench, apple', 'Hammer', 'Screwdriver', 'Wrench', 'Apple', 'D', 'Apple is a fruit; the others are all tools.', true),
  ('5', 'Verbal Reasoning', 'Easy-Medium', 12, 'Complete the analogy: Bird is to Nest as Bee is to ____.', 'Hive', 'Flower', 'Honey', 'Nest', 'A', 'A bird lives in a nest, just as a bee lives in a hive.', true),
  ('5', 'Verbal Reasoning', 'Medium', 13, 'Choose the best antonym (opposite) of "generous":', 'Kind', 'Stingy', 'Wealthy', 'Happy', 'B', '"Generous" means willing to give freely; its opposite is "stingy."', true),
  ('5', 'Verbal Reasoning', 'Medium-Advanced', 14, 'Unscramble the letters R-E-V-A-B to form a real word, then choose its synonym.', 'Fearful', 'Courageous', 'Weak', 'Tired', 'B', 'The unscrambled word is BRAVE, which means Courageous.', true),
  ('5', 'Verbal Reasoning', 'Advanced', 15, '"Even though the coach benched him for the first half, Marcus never complained; he cheered loudly for his teammates and studied every play from the sideline." Which word BEST describes Marcus?', 'Selfish', 'Supportive', 'Angry', 'Careless', 'B', 'Marcus stayed positive and encouraged his teammates even while benched — a supportive attitude.', true),
  ('5', 'Geometry & Spatial Reasoning', 'Easy', 16, 'How many sides does a hexagon have?', '5', '6', '7', '8', 'B', 'A hexagon has 6 sides by definition.', true),
  ('5', 'Geometry & Spatial Reasoning', 'Easy-Medium', 17, 'What is the sum of the interior angles of any quadrilateral (a 4-sided figure)?', '180°', '270°', '360°', '540°', 'C', 'A quadrilateral can be split into two triangles (180° each), so its angles sum to 360°.', true),
  ('5', 'Geometry & Spatial Reasoning', 'Medium', 18, 'A rectangle has a perimeter of 28 cm and a length of 8 cm. What is its width?', '4 cm', '6 cm', '10 cm', '12 cm', 'B', 'Perimeter = 2 × (length + width): 28 = 2 × (8 + w) → 14 = 8 + w → w = 6 cm.', true),
  ('5', 'Geometry & Spatial Reasoning', 'Medium-Advanced', 19, 'How many faces, edges, and vertices does a cube have?', '6 faces, 12 edges, 8 vertices', '4 faces, 6 edges, 4 vertices', '6 faces, 8 edges, 12 vertices', '8 faces, 12 edges, 6 vertices', 'A', 'A cube has 6 faces, 12 edges, and 8 vertices — satisfying Euler''s formula: F + V − E = 6 + 8 − 12 = 2.', true),
  ('5', 'Geometry & Spatial Reasoning', 'Advanced', 20, 'Look at the capital letter "R." If you flip it horizontally (creating its mirror image), will the resulting shape look the same as the original letter "R"?', 'Yes, because R is symmetrical', 'No, because R is not vertically symmetrical', 'Yes, all letters look the same flipped', 'No, because R has sharp corners', 'B', 'The letter "R" is not symmetrical along a vertical axis, so its mirror image looks backward — unlike symmetrical letters like "A" or "H."', true);
