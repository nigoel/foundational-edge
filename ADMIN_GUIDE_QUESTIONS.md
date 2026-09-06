# Adding or editing quizzes and questions (no code required)

The site (`skill-check.html`) pulls everything live from Supabase: which
quiz to show, its questions, and its attempt limit. To add, edit, retire,
or reorder any of it, you only need access to the Supabase dashboard — no
code changes, no redeploying the site.

## How it fits together

- **`quizzes`** — one row per quiz: a grade, a type (`Free-Skill-Test`,
  `Weekly-Practice`, or `Monthly-Competition`), a skill focus, a publish
  date, an optional expiry date, and a max-attempts cap.
- **`questions`** — each question belongs to exactly one quiz, via its
  `quiz_id`.
- **`quiz_attempts`** — each submitted attempt records which `quiz_id` it
  was for, and counts against that quiz's `max_attempts`.

For the free skill check, when a family opens `skill-check.html?grade=5`,
the site looks up the **active, non-expired quiz for grade 5 with type
`Free-Skill-Test`, picking the one with the latest publish date** if more
than one matches. This means you can publish a refreshed version of a
quiz (new `quizzes` row, later `publish_date`) without touching or
deleting the old one — the site switches over automatically, and past
attempts against the old version stay intact for review.

## One-time setup (developer does this once)

Run, in order: `SETUP_QUESTIONS.sql`, `SETUP_QUESTIONS_STORAGE.sql`,
`SETUP_QUESTIONS_REMOVE_SVG.sql`, `SETUP_ATTEMPTS_AND_REREGISTRATION.sql`,
`SETUP_QUIZZES.sql`, in the Supabase SQL editor for project
`wwmbpgtddsyettfdakbe`. Together these set up the `quizzes`, `questions`,
and `quiz_attempts` tables, the RPC functions the site uses to read/grade/
review, a public Storage bucket for uploaded images, and seed the initial
Grade 4 and Grade 5 free skill checks.

## Adding a new quiz (ops does this ongoing)

Use this to publish a refreshed version of an existing quiz, add a new
grade, or (once the site supports it) a Weekly-Practice or
Monthly-Competition quiz.

1. Go to the [Supabase Table Editor](https://supabase.com/dashboard/project/wwmbpgtddsyettfdakbe/editor) → `quizzes` table.
2. Click **Insert row** and fill in:

   | Column | What to put |
   |---|---|
   | `quiz_type` | `Free-Skill-Test`, `Weekly-Practice`, or `Monthly-Competition` |
   | `grade` | `'3'` through `'8'` |
   | `skill` | `verbal`, `reasoning`, `maths`, or `all` |
   | `max_attempts` | how many times a student may take this quiz (the free skill check currently uses `3`) |
   | `publish_date` | defaults to today; set a future date to schedule it, or backdate for historical record-keeping |
   | `expiry_date` | optional — leave empty for "never expires" |
   | `title` | optional, for your own reference |
   | `active` | `true` to make it eligible to be picked |

3. Save, then add its questions (below) with this quiz's `id` as their `quiz_id`.

To **retire an old quiz** without deleting its history, set `active` to
`false` — its past attempts remain reviewable, it just won't be picked as
the current one anymore.

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
   | `quiz_id` | the `id` of the quiz this question belongs to (copy it from the `quizzes` table) |
   | `section` | e.g. `Logical Reasoning`, `Quantitative Aptitude`, `Verbal Reasoning`, `Geometry & Spatial Reasoning` — questions are grouped and shown in the order they appear |
   | `difficulty` | one of `Easy`, `Easy-Medium`, `Medium`, `Medium-Advanced`, `Advanced` (optional, for your own reference) |
   | `order_num` | a number controlling display order within the quiz — leave gaps (10, 20, 30…) so you can insert questions later without renumbering everything |
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
- Each grade needs at least one **active quiz** with at least one **active
  question**, or the site shows the "we don't have an active skill check
  for this grade" fallback message.
- A student gets exactly `max_attempts` tries at a given quiz (identified
  by `quiz_id`, not just grade) — publishing a new quiz version resets
  that count for everyone, since it's a different `quiz_id`.

## Where results go

Every submitted skill check is stored in the `quiz_attempts` table (which
quiz it was for, Registration ID, grade, answers, score, timestamp — plus
a full snapshot of each question as it appeared, for review). View it the
same way in the Table Editor — filter by `reg_id` to find a specific
child's attempts, matching the Registration ID from `registrations`.
