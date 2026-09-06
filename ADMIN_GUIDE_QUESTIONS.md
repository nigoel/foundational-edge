# Adding or editing skill-check questions (no code required)

The free skill check on the website (`skill-check.html`) pulls its questions
live from a Supabase table called `questions`. To add, edit, retire, or
reorder questions, you only need access to the Supabase dashboard — no code
changes, no redeploying the site.

## One-time setup (developer does this once)

Run `SETUP_QUESTIONS.sql`, then `SETUP_QUESTIONS_STORAGE.sql`, in that order,
in the Supabase SQL editor for project `wwmbpgtddsyettfdakbe`. Together
these create the `questions` table (and the `quiz_attempts` table that
stores results), the two functions the website uses to read questions and
grade submissions, a public Storage bucket called `question-images` for
uploaded diagrams/photos, and seed the initial Grade 4 and Grade 5
questions.

## Adding an image to a question (ops/teacher does this ongoing)

Every image is an uploaded file — there's no code-based diagram option, so
this is always the same simple flow:

1. Go to the [Supabase Storage section](https://supabase.com/dashboard/project/wwmbpgtddsyettfdakbe/storage/buckets/question-images) → `question-images` bucket.
2. Click **Upload file** and choose your image (JPG, PNG, or WebP — keep
   it under ~500 KB so the quiz stays fast to load; resize large photos
   first if needed).
3. Click the uploaded file → **Copy URL** (this gives you its public link,
   since the bucket is public — no extra sharing step needed, unlike
   Google Drive).
4. Go to the `questions` table → open the row for that question → paste
   the copied URL into `image_url`.
5. Save. The image appears on the site immediately — no deploy needed.

To replace an image, just upload a new file and update the URL in the
same way. To remove an image from a question, clear its `image_url` field.

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
   | `image_url` | optional — see "Adding an image to a question" above. Leave empty for a text-only question. |
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
