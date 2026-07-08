# Foundational Edge — Marketing Website

A static, no-build-step landing page. Plain HTML/CSS/JS — no framework, no bundler,
so it can be hosted for free and edited by anyone comfortable with basic HTML.

## Project structure

```
foundational-edge/
├── index.html        All page content and structure
├── css/
│   └── styles.css    All styling (colors, type, layout, responsive rules)
├── js/
│   └── main.js        Mobile nav toggle, pricing region toggle, scroll reveal
├── assets/            Put real photos/logo files here when you have them
└── README.md
```

## Before you launch — things to edit

| What | Where | Find |
|---|---|---|
| WhatsApp number | `index.html` | search `wa.me/910000000000` — replace with your real WhatsApp Business number, no `+` or spaces |
| Contact email | `index.html` | search `hello@foundationaledge.com` (appears twice) |
| India / international prices | `index.html` | inside `<section id="pricing">`, each `<div class="amount" data-india="..." data-intl="...">` |
| Sample rank card (Ananya R.) | `index.html` | inside `<div class="rankcard">` in the hero — replace with a real anonymized example once you have one, or keep as an illustrative sample |
| Testimonials | `index.html` | inside `<section id="stories">` — replace placeholders with real parent quotes once collected |
| Brand name / logo text | `index.html` | search `Foundational<span class="dot">·</span>Edge` (appears in header and footer) |
| Colors / fonts | `css/styles.css` | edit the CSS variables at the very top of the file under `:root` |

## Preview locally

No install needed beyond a browser. Two options:

**Simplest:** double-click `index.html` to open it directly in a browser.

**With a local server** (avoids some browser file-access quirks, closer to production):
```bash
npx serve .
# or
python3 -m http.server 8000
```
Then open `http://localhost:8000` (or the port `serve` prints).

## Deploying (free)

**Recommended: Cloudflare Pages**
1. Create a free Cloudflare account.
2. Go to Workers & Pages → Create → Pages → Upload assets (or connect a GitHub repo containing this folder).
3. Upload this whole `foundational-edge` folder. Cloudflare serves it over HTTPS on a free `*.pages.dev` URL immediately.
4. Add your own domain under the project's Custom Domains tab once you've registered one.

**Alternatives (equally fine, same free-tier idea):** Netlify (drag-and-drop deploy) or GitHub Pages.

**Domain:** register via Cloudflare Registrar or Namecheap — roughly ₹800–1,200/year for a `.com`.
Point its DNS to your Cloudflare Pages / Netlify site (a few clicks in their dashboard).

**Total cost to go live:** just the domain — hosting is free at this traffic scale.

## Known placeholder / not-yet-wired items

- The "free skill check" buttons currently link to WhatsApp/email — there's no actual quiz yet.
  For Phase 1, the simplest fix is linking them to a Google Form or Typeform with your real questions.
- No form on this page submits anywhere (there is no signup form yet, by design — WhatsApp/email
  are the current capture mechanism). If you add an email capture form later, Formspree or Tally
  are free, no-backend-needed options that work well with a static site like this.
