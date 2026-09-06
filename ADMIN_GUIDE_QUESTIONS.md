# Adding or editing skill-check questions (no code required)

The free skill check on the website (`skill-check.html`) pulls its questions
live from a Supabase table called `questions`. To add, edit, retire, or
reorder questions, you only need access to the Supabase dashboard — no code
changes, no redeploying the site.

## One-time setup (developer does this once)

Run `SETUP_QUESTIONS.sql` in the Supabase SQL editor for project
`wwmbpgtddsyettfdakbe`. This creates the `questions` table (and the
`quiz_attempts` table that stores results), plus two functions the website
uses to read questions and grade submissions. It also seeds 20 Grade 4 and
20 Grade 5 questions to start with.

## Adding a new question (ops/teacher does this ongoing)

1. Go to the [Supabase Table Editor](https://supabase.com/dashboard/project/wwmbpgtddsyettfdakbe/editor) → `questions` table.
2. Click **Insert row** and fill in:

   | Column | What to put |
   |---|---|
   | `grade` | `'3'` through `'8'` |
   | `section` | e.g. `Logical Reasoning`, `Quantitative Aptitude`, `Verbal Reasoning`, `Geometry & Spatial Reasoning` — questions are grouped and shown in the order they appear |
   | `difficulty` | one of `Easy`, `Easy-Medium`, `Medium`, `Medium-Advanced`, `Advanced` (optional, for your own reference) |
   | `order_num` | a number controlling display order within that grade — leave gaps (10, 20, 30…) so you can insert questions later without renumbering everything |
   | `question_text` | the question itself |
   | `option_a` / `option_b` / `option_c` / `option_d` | the four answer choices |
   | `correct_answer` | `A`, `B`, `C`, or `D` — must match one of the options above |
   | `explanation` | shown to the student after they submit, explaining the right answer |
   | `active` | `true` to make it live, `false` to hide it without deleting |

3. Save. The question appears on the site immediately — no deploy needed.

## Retiring or fixing a question

- To temporarily hide a question, set its `active` to `false`.
- To fix a typo or wrong answer, just edit the row directly — changes apply
  to the next student who loads the quiz. (Anyone already mid-quiz keeps
  the version they loaded.)

## Important constraints

- **Questions must be multiple choice** (4 options, one correct answer).
  This keeps grading simple and fully automatic. If you need a free-response
  question later, talk to your developer — it needs a different grading
  path.
- Each grade needs at least one active question, or the site shows the
  "we don't have an active skill check for this grade" fallback message.

## Where results go

Every submitted skill check is stored in the `quiz_attempts` table
(Registration ID, grade, answers, score, timestamp). View it the same way
in the Table Editor — filter by `reg_id` to find a specific child's
attempt, matching the Registration ID from `registrations`.
