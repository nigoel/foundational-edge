-- Foundational Edge — add optional diagrams to skill-check questions.
-- Run this in the Supabase SQL editor for project wwmbpgtddsyettfdakbe,
-- AFTER SETUP_QUESTIONS.sql has already been run once.
--
-- Adds an `image_svg` column to `questions` (nullable — most questions have
-- none) and updates get_quiz_questions() to return it. The SVGs are plain
-- inline vector diagrams (no external image hosting, no extra network request)
-- for the paper-folding and geometry questions that are hard to picture from
-- text alone. Safe to run multiple times.

alter table questions add column if not exists image_svg text;

-- get_quiz_questions() must be dropped and recreated (not just replaced) because
-- CREATE OR REPLACE cannot change a function's output column list (42P13) —
-- same constraint noted in SETUP.sql for register_child().
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
  image_svg text
)
language sql
security definer
set search_path = public
as $$
  select q.id, q.section, q.difficulty, q.order_num, q.question_text,
         q.option_a, q.option_b, q.option_c, q.option_d, q.image_svg
  from questions q
  where q.grade = p_grade
    and q.active = true
  order by q.order_num;
$$;

revoke all on function public.get_quiz_questions(text) from public;
grant execute on function public.get_quiz_questions(text) to anon;

-- Attach diagrams to the specific questions that benefit from one.
-- To add a diagram to any OTHER question later: just update its image_svg
-- column with inline <svg>...</svg> markup via the Table Editor — no code
-- or deploy needed, same as adding a question.

update questions set image_svg = '<svg viewBox="0 0 340 170" xmlns="http://www.w3.org/2000/svg">
  <rect x="30" y="20" width="120" height="120" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <line x1="30" y1="140" x2="150" y2="20" stroke="#B8892B" stroke-width="2" stroke-dasharray="6,5"/>
  <text x="90" y="158" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="#16283D" text-anchor="middle">Before (1 layer)</text>

  <path d="M 175 80 L 210 80" stroke="#16283D" stroke-width="2" marker-end="url(#arrow6)"/>
  <defs><marker id="arrow6" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#16283D"/></marker></defs>

  <polygon points="230,140 350,140 230,20" fill="#F8F5EE" stroke="#16283D" stroke-width="2" transform="translate(-10,0)"/>
  <text x="290" y="158" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="#16283D" text-anchor="middle">After (2 layers)</text>
</svg>'
  where grade = '4' and order_num = 6;

update questions set image_svg = '<svg viewBox="0 0 340 170" xmlns="http://www.w3.org/2000/svg">
  <rect x="30" y="20" width="120" height="120" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <line x1="90" y1="20" x2="90" y2="140" stroke="#B8892B" stroke-width="2" stroke-dasharray="6,5"/>
  <text x="90" y="158" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="#16283D" text-anchor="middle">Before</text>

  <path d="M 175 80 L 210 80" stroke="#16283D" stroke-width="2" marker-end="url(#arrow7)"/>
  <defs><marker id="arrow7" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#16283D"/></marker></defs>

  <rect x="230" y="20" width="60" height="120" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <text x="260" y="158" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="#16283D" text-anchor="middle">After — what shape?</text>
</svg>'
  where grade = '4' and order_num = 7;

update questions set image_svg = '<svg viewBox="0 0 340 170" xmlns="http://www.w3.org/2000/svg">
  <rect x="20" y="30" width="70" height="70" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <circle cx="55" cy="65" r="5" fill="#C0392B"/>
  <text x="55" y="118" font-family="IBM Plex Sans, sans-serif" font-size="11.5" fill="#16283D" text-anchor="middle">Folded twice,</text>
  <text x="55" y="132" font-family="IBM Plex Sans, sans-serif" font-size="11.5" fill="#16283D" text-anchor="middle">punch this corner</text>

  <path d="M 120 65 L 155 65" stroke="#16283D" stroke-width="2" marker-end="url(#arrow8)"/>
  <defs><marker id="arrow8" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#16283D"/></marker></defs>

  <rect x="180" y="20" width="130" height="130" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <circle cx="220" cy="60" r="5" fill="#C0392B"/>
  <circle cx="270" cy="60" r="5" fill="#C0392B"/>
  <circle cx="220" cy="110" r="5" fill="#C0392B"/>
  <circle cx="270" cy="110" r="5" fill="#C0392B"/>
  <text x="245" y="163" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="#16283D" text-anchor="middle">Unfolded — how many holes?</text>
</svg>'
  where grade = '4' and order_num = 8;

update questions set image_svg = '<svg viewBox="0 0 340 170" xmlns="http://www.w3.org/2000/svg">
  <rect x="20" y="30" width="80" height="60" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <polygon points="88,30 100,30 100,42" fill="#B8892B"/>
  <text x="60" y="112" font-family="IBM Plex Sans, sans-serif" font-size="11.5" fill="#16283D" text-anchor="middle">Folded twice, notch</text>
  <text x="60" y="126" font-family="IBM Plex Sans, sans-serif" font-size="11.5" fill="#16283D" text-anchor="middle">the free corner</text>

  <path d="M 130 65 L 165 65" stroke="#16283D" stroke-width="2" marker-end="url(#arrow9)"/>
  <defs><marker id="arrow9" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#16283D"/></marker></defs>

  <rect x="190" y="20" width="130" height="100" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <polygon points="245,60 255,55 265,60 255,65" fill="#B8892B"/>
  <text x="255" y="140" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="#16283D" text-anchor="middle">Unfolded — how many notches,</text>
  <text x="255" y="155" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="#16283D" text-anchor="middle">what shape do they form?</text>
</svg>'
  where grade = '4' and order_num = 9;

update questions set image_svg = '<svg viewBox="0 0 340 170" xmlns="http://www.w3.org/2000/svg">
  <polygon points="20,100 90,100 20,30" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <circle cx="35" cy="85" r="4" fill="#C0392B"/>
  <circle cx="60" cy="60" r="4" fill="#3E7C6B"/>
  <text x="55" y="122" font-family="IBM Plex Sans, sans-serif" font-size="11" fill="#16283D" text-anchor="middle">Folded twice (triangle),</text>
  <text x="55" y="135" font-family="IBM Plex Sans, sans-serif" font-size="11" fill="#16283D" text-anchor="middle">two punch spots marked</text>

  <path d="M 125 75 L 160 75" stroke="#16283D" stroke-width="2" marker-end="url(#arrow10)"/>
  <defs><marker id="arrow10" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#16283D"/></marker></defs>

  <rect x="185" y="20" width="130" height="130" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <circle cx="210" cy="45" r="4" fill="#C0392B"/><circle cx="290" cy="45" r="4" fill="#C0392B"/>
  <circle cx="210" cy="125" r="4" fill="#C0392B"/><circle cx="290" cy="125" r="4" fill="#C0392B"/>
  <circle cx="250" cy="55" r="4" fill="#3E7C6B"/><circle cx="250" cy="115" r="4" fill="#3E7C6B"/>
  <circle cx="225" cy="85" r="4" fill="#3E7C6B"/><circle cx="275" cy="85" r="4" fill="#3E7C6B"/>
  <text x="250" y="163" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="#16283D" text-anchor="middle">Unfolded — how many holes total?</text>
</svg>'
  where grade = '4' and order_num = 10;

update questions set image_svg = '<svg viewBox="0 0 300 170" xmlns="http://www.w3.org/2000/svg">
  <polygon points="60,140 240,140 200,30 100,30" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <line x1="60" y1="140" x2="200" y2="30" stroke="#B8892B" stroke-width="2" stroke-dasharray="6,5"/>
  <text x="105" y="105" font-family="IBM Plex Sans, sans-serif" font-size="13" fill="#3E7C6B" font-weight="600">180°</text>
  <text x="185" y="80" font-family="IBM Plex Sans, sans-serif" font-size="13" fill="#3E7C6B" font-weight="600">180°</text>
  <text x="150" y="160" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="#16283D" text-anchor="middle">One diagonal splits any quadrilateral into 2 triangles</text>
</svg>'
  where grade = '5' and order_num = 17;

update questions set image_svg = '<svg viewBox="0 0 300 160" xmlns="http://www.w3.org/2000/svg">
  <rect x="60" y="30" width="180" height="80" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <text x="150" y="22" font-family="IBM Plex Sans, sans-serif" font-size="13" fill="#16283D" text-anchor="middle">length = 8 cm</text>
  <text x="255" y="74" font-family="IBM Plex Sans, sans-serif" font-size="13" fill="#B8892B" font-weight="600" text-anchor="middle" transform="rotate(90 255 74)">width = ?</text>
  <text x="150" y="140" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="#16283D" text-anchor="middle">Perimeter = 28 cm</text>
</svg>'
  where grade = '5' and order_num = 18;

update questions set image_svg = '<svg viewBox="0 0 260 170" xmlns="http://www.w3.org/2000/svg">
  <polygon points="60,110 160,110 160,40 60,40" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <polygon points="60,40 100,20 200,20 160,40" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <polygon points="160,40 200,20 200,90 160,110" fill="#F8F5EE" stroke="#16283D" stroke-width="2"/>
  <line x1="60" y1="110" x2="100" y2="90" stroke="#16283D" stroke-width="2" stroke-dasharray="4,4"/>
  <line x1="100" y1="90" x2="200" y2="90" stroke="#16283D" stroke-width="2" stroke-dasharray="4,4"/>
  <line x1="100" y1="90" x2="100" y2="20" stroke="#16283D" stroke-width="2" stroke-dasharray="4,4"/>
  <text x="130" y="150" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="#16283D" text-anchor="middle">A cube — count its faces, edges, and vertices</text>
</svg>'
  where grade = '5' and order_num = 19;

update questions set image_svg = '<svg viewBox="0 0 300 160" xmlns="http://www.w3.org/2000/svg">
  <text x="80" y="100" font-family="Source Serif 4, Georgia, serif" font-size="72" font-weight="700" fill="#16283D" text-anchor="middle">R</text>
  <text x="80" y="140" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="#16283D" text-anchor="middle">Original</text>

  <line x1="150" y1="20" x2="150" y2="150" stroke="#C9C2B2" stroke-width="1.5" stroke-dasharray="4,4"/>

  <text x="220" y="100" font-family="Source Serif 4, Georgia, serif" font-size="72" font-weight="700" fill="#B8892B" text-anchor="middle" transform="scale(-1,1) translate(-440,0)">R</text>
  <text x="220" y="140" font-family="IBM Plex Sans, sans-serif" font-size="12" fill="#16283D" text-anchor="middle">Flipped horizontally</text>
</svg>'
  where grade = '5' and order_num = 20;
