# Chapter Sub-Nav (In-Page Section TOC) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Under the active chapter in the left nav, show that chapter's `<h2>` sections as a clickable, scroll-spy table of contents.

**Architecture:** Build-time in Eleventy — a small owned `markdown-it` rule gives headings `id`s, and an owned filter renders the active chapter's H2 list into `track.njk`. The only runtime code is a scroll-spy highlight using the native `IntersectionObserver`.

**Tech Stack:** Eleventy 3, markdown-it 14 (already present), vanilla JS + CSS. Tests use Node's built-in `node:test` and the already-present Playwright — **no new dependencies**.

## Global Constraints

- **No new npm dependencies.** Do not add `markdown-it-anchor` or any package. Use the existing `markdown-it` and Node/Playwright built-ins only.
- **No external or runtime services.** All generation is at build time; the only browser code is `IntersectionObserver` (native).
- **pathPrefix is `/tt-quietbox2-guide/`.** Sub-nav links are pure `#id` fragments, so they are unaffected — never prefix them.
- **Shared logic lives in `lib/` (repo root), outside `src/content`** (Eleventy's input dir) so Eleventy never processes it.
- Follow existing style: vanilla guarded IIFEs in `main.js`, CSS custom properties (`var(--persona-color, var(--teal))`, `var(--muted)`, `var(--bg2)`).

---

### Task 1: Heading utilities library + unit tests

**Files:**
- Create: `lib/headings.js`
- Create: `test/headings.test.js`
- Modify: `package.json` (add a `test` script)

**Interfaces:**
- Produces: `slugify(text: string) => string`, `headingAnchors(md: MarkdownIt) => void` (a markdown-it plugin that sets `id` on `h2`/`h3`/`h4`, deduped per render), `extractH2Headings(html: string) => Array<{id: string, text: string}>`. Exported via CommonJS `module.exports`.

- [ ] **Step 1: Add the test script to `package.json`**

In the `"scripts"` block, add:

```json
    "test": "node --test"
```

- [ ] **Step 2: Write the failing tests**

Create `test/headings.test.js`:

```js
const test = require("node:test");
const assert = require("node:assert");
const MarkdownIt = require("markdown-it");
const { slugify, headingAnchors, extractH2Headings } = require("../lib/headings.js");

test("slugify lowercases, hyphenates, trims", () => {
  assert.equal(slugify("Is This Thing On?"), "is-this-thing-on");
  assert.equal(slugify("The Three Environments, Explained"), "the-three-environments-explained");
  assert.equal(slugify("  Trailing --- dashes  "), "trailing-dashes");
  assert.equal(slugify("Disk & Storage"), "disk-storage");
});

test("headingAnchors adds ids to h2/h3 and dedupes within a render", () => {
  const md = new MarkdownIt().use(headingAnchors);
  const html = md.render("## Setup\n\n## Setup\n\n### Notes");
  assert.match(html, /<h2 id="setup">Setup<\/h2>/);
  assert.match(html, /<h2 id="setup-2">Setup<\/h2>/);
  assert.match(html, /<h3 id="notes">Notes<\/h3>/);
});

test("extractH2Headings returns h2 id+text, strips inner tags, skips h3", () => {
  const html = `<h2 id="a">Alpha</h2><p>x</p><h3 id="b">Beta</h3><h2 id="c">Gamma <code>x</code></h2>`;
  assert.deepEqual(extractH2Headings(html), [
    { id: "a", text: "Alpha" },
    { id: "c", text: "Gamma x" },
  ]);
});

test("extractH2Headings decodes basic entities", () => {
  assert.deepEqual(extractH2Headings('<h2 id="e">Disk &amp; Storage</h2>'), [
    { id: "e", text: "Disk & Storage" },
  ]);
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `npm test`
Expected: FAIL — `Cannot find module '../lib/headings.js'`.

- [ ] **Step 4: Implement `lib/headings.js`**

Create `lib/headings.js`:

```js
"use strict";

// Shared heading helpers. Dependency-free and pure so they can be unit-tested
// with `node --test` and reused from .eleventy.js. Kept in lib/ (outside
// src/content) so Eleventy never treats this as a template.

// Turn heading text into a URL-safe slug.
function slugify(text) {
  return String(text)
    .toLowerCase()
    .replace(/<[^>]+>/g, "")       // strip any inline HTML tags
    .replace(/&[a-z]+;/g, " ")     // named entities -> space (so &amp; splits words)
    .replace(/[^a-z0-9]+/g, "-")   // any run of non-alphanumerics -> single hyphen
    .replace(/^-+|-+$/g, "");      // trim leading/trailing hyphens
}

// markdown-it plugin: give every h2/h3/h4 a unique id. Dedupes within a single
// render using a Set stored on state.env. Never clobbers an explicit id.
function headingAnchors(md) {
  md.core.ruler.push("heading_anchors", (state) => {
    const used = new Set();
    const tokens = state.tokens;
    for (let i = 0; i < tokens.length; i++) {
      const t = tokens[i];
      if (t.type !== "heading_open" || !/^h[234]$/.test(t.tag)) continue;
      const existing = t.attrGet("id");
      if (existing) { used.add(existing); continue; }
      const inline = tokens[i + 1];
      const text = inline && inline.type === "inline" ? inline.content : "";
      const base = slugify(text) || "section";
      let slug = base;
      let n = 2;
      while (used.has(slug)) slug = `${base}-${n++}`;
      used.add(slug);
      t.attrSet("id", slug);
    }
    return true;
  });
}

// Decode the handful of HTML entities that appear in heading text, so Nunjucks
// can re-escape them exactly once when printing.
function decodeEntities(s) {
  return s
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

// Pull h2 headings (id + visible text) out of rendered HTML for the sub-nav TOC.
function extractH2Headings(html) {
  const out = [];
  const re = /<h2\b[^>]*\bid="([^"]+)"[^>]*>([\s\S]*?)<\/h2>/gi;
  let m;
  while ((m = re.exec(String(html))) !== null) {
    const id = m[1];
    const text = decodeEntities(m[2].replace(/<[^>]+>/g, "")).replace(/\s+/g, " ").trim();
    if (id && text) out.push({ id, text });
  }
  return out;
}

module.exports = { slugify, headingAnchors, extractH2Headings };
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `npm test`
Expected: PASS — all 4 tests green.

- [ ] **Step 6: Commit**

```bash
git add lib/headings.js test/headings.test.js package.json
git commit -m "feat: heading slug/anchor/TOC utils with unit tests"
```

---

### Task 2: Wire heading anchors + TOC filter into Eleventy

**Files:**
- Modify: `.eleventy.js` (require the lib near the top with the other requires; `md.use(...)` right before `eleventyConfig.setLibrary("md", md)` at line ~44; add the filter nearby)

**Interfaces:**
- Consumes: `headingAnchors`, `extractH2Headings` from `lib/headings.js`.
- Produces: every rendered `h2`/`h3`/`h4` now has an `id`; a Nunjucks filter `chapterHeadings(content) => Array<{id, text}>`.

- [ ] **Step 1: Require the lib**

At the top of `.eleventy.js`, alongside the existing `require`s (after line 4), add:

```js
const { headingAnchors, extractH2Headings } = require("./lib/headings.js");
```

- [ ] **Step 2: Register the markdown-it plugin**

Immediately before `eleventyConfig.setLibrary("md", md);` (currently line 44), add:

```js
  md.use(headingAnchors);
```

- [ ] **Step 3: Register the filter**

Right after `eleventyConfig.setLibrary("md", md);`, add:

```js
  // TOC data for the active chapter's left-nav sub-nav (see layouts/track.njk).
  eleventyConfig.addFilter("chapterHeadings", extractH2Headings);
```

- [ ] **Step 4: Build and verify heading ids exist**

Run:
```bash
npm run build
grep -oE '<h2 id="[^"]+">' _site/ml-practitioner/03-vllm-on-qb2/index.html | head
```
Expected: several lines like `<h2 id="...">` (previously there were none).

- [ ] **Step 5: Commit**

```bash
git add .eleventy.js
git commit -m "feat: add heading ids + chapterHeadings filter to eleventy build"
```

---

### Task 3: Render the sub-nav under the active chapter

**Files:**
- Modify: `src/_includes/layouts/track.njk` (the `{% for ch in persona.chapters %}` loop)

**Interfaces:**
- Consumes: the `chapterHeadings` filter (Task 2), the layout's `content` variable (current page's rendered HTML = active chapter).
- Produces: `<ul class="chapter-subnav">` with `<a class="chapter-subnav-item" href="#id">` items, inserted directly after the active `.chapter-nav-item`.

- [ ] **Step 1: Edit the chapter loop**

Replace the existing loop body:

```njk
    {% for ch in persona.chapters %}
    <a href="/{{ persona.id }}/{{ ch.slug }}/"
       class="chapter-nav-item{% if ch.slug == currentChapter %} active{% endif %}">
      {{ loop.index }}. {{ ch.title }}
    </a>
    {% endfor %}
```

with:

```njk
    {% for ch in persona.chapters %}
    <a href="/{{ persona.id }}/{{ ch.slug }}/"
       class="chapter-nav-item{% if ch.slug == currentChapter %} active{% endif %}">
      {{ loop.index }}. {{ ch.title }}
    </a>
    {% if ch.slug == currentChapter %}
    {% set _headings = content | chapterHeadings %}
    {% if _headings.length %}
    <ul class="chapter-subnav">
      {% for h in _headings %}
      <li><a class="chapter-subnav-item" href="#{{ h.id }}">{{ h.text }}</a></li>
      {% endfor %}
    </ul>
    {% endif %}
    {% endif %}
    {% endfor %}
```

- [ ] **Step 2: Build and verify the sub-nav renders with matching counts**

Run:
```bash
npm run build
echo "subnav items:"; grep -oE 'class="chapter-subnav-item" href="#[^"]+"' _site/ml-practitioner/03-vllm-on-qb2/index.html | wc -l
echo "h2 in content:"; grep -oE '<h2 id="[^"]+">' _site/ml-practitioner/03-vllm-on-qb2/index.html | wc -l
```
Expected: both counts equal (11 for this chapter) and non-zero.

- [ ] **Step 3: Verify the landing page has no sub-nav (guarded correctly)**

Run: `grep -c "chapter-subnav" _site/index.html`
Expected: `0`.

- [ ] **Step 4: Commit**

```bash
git add src/_includes/layouts/track.njk
git commit -m "feat: render active-chapter section TOC in the left nav"
```

---

### Task 4: Scroll-spy highlight + styling + e2e check

**Files:**
- Modify: `src/assets/main.js` (append a new guarded IIFE)
- Modify: `src/assets/style.css` (add `.chapter-subnav` rules; add `scroll-margin-top`; hide in the `@media (max-width: 768px)` block)
- Create: `test/subnav.e2e.mjs` (Playwright integration check)

**Interfaces:**
- Consumes: `.chapter-subnav` / `.chapter-subnav-item` markup (Task 3) and heading `id`s (Task 2).
- Produces: runtime `.active` class toggling on the current section's item; hash update + smooth scroll on click.

- [ ] **Step 1: Append the scroll-spy IIFE to `main.js`**

Add at the end of `src/assets/main.js`:

```js
// Chapter sub-nav scroll-spy: highlight the in-page section (h2) currently in
// view within the active chapter's TOC, and smooth-scroll on click. The list is
// rendered at build time (layouts/track.njk); this only adds the "you are here"
// highlight. No-ops on pages without a sub-nav.
(function () {
  const subnav = document.querySelector(".chapter-subnav");
  if (!subnav) return;

  const links = Array.from(subnav.querySelectorAll(".chapter-subnav-item"));
  const byEl = new Map();   // heading element -> link
  const targets = [];       // heading elements, in document order
  links.forEach((a) => {
    const id = decodeURIComponent((a.getAttribute("href") || "").replace(/^#/, ""));
    const el = id && document.getElementById(id);
    if (el) { byEl.set(el, a); targets.push(el); }
  });
  if (!targets.length) return;

  function setActive(link) {
    links.forEach((l) => l.classList.toggle("active", l === link));
  }

  links.forEach((a) => {
    a.addEventListener("click", function (e) {
      const id = decodeURIComponent((a.getAttribute("href") || "").replace(/^#/, ""));
      const el = document.getElementById(id);
      if (!el) return;
      e.preventDefault();
      el.scrollIntoView({ behavior: "smooth", block: "start" });
      history.replaceState(null, "", "#" + id);
      setActive(a);
    });
  });

  // Single observer: update the visible set, then pick the winner. Prefer the
  // topmost heading currently in the trigger band; if none are, fall back to the
  // last heading that has scrolled above the band.
  const visible = new Set();
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((en) =>
        en.isIntersecting ? visible.add(en.target) : visible.delete(en.target));
      let current = null;
      for (const el of targets) {
        if (visible.has(el)) { current = el; break; }
      }
      if (!current) {
        for (const el of targets) {
          if (el.getBoundingClientRect().top < 100) current = el;
        }
      }
      if (current && byEl.has(current)) setActive(byEl.get(current));
    },
    { rootMargin: "-80px 0px -70% 0px", threshold: 0 }
  );
  targets.forEach((el) => observer.observe(el));

  setActive(byEl.get(targets[0])); // initial state
})();
```

- [ ] **Step 2: Add the CSS**

Append to `src/assets/style.css` (near the other `.chapter-nav` rules):

```css
/* In-page section TOC under the active chapter (built in layouts/track.njk). */
.chapter-subnav {
  list-style: none;
  margin: 2px 0 8px 30px;
  padding-left: 12px;
  border-left: 1px solid var(--bg2);
}
.chapter-subnav-item {
  display: block;
  padding: 3px 10px;
  margin-left: -13px;
  font-size: 12px;
  line-height: 1.4;
  color: var(--muted);
  text-decoration: none;
  border-left: 2px solid transparent;
}
.chapter-subnav-item:hover { color: var(--text); }
.chapter-subnav-item.active {
  color: var(--persona-color, var(--teal));
  border-left-color: var(--persona-color, var(--teal));
  font-weight: 600;
}
/* Anchored headings must clear the sticky top bar. */
h2, h3, h4 { scroll-margin-top: 80px; }
```

- [ ] **Step 3: Hide the sub-nav on mobile**

Inside the existing `@media (max-width: 768px) {` block in `src/assets/style.css` (the one that restyles `.chapter-nav` into a horizontal strip), add:

```css
  .chapter-subnav { display: none; }
```

- [ ] **Step 4: Write the Playwright e2e check**

Create `test/subnav.e2e.mjs`:

```js
// Integration check for the chapter sub-nav. Requires the dev server running:
//   npm run serve      (serves at http://localhost:8080/tt-quietbox2-guide/)
// then: node test/subnav.e2e.mjs
import { chromium } from "playwright";

const BASE = process.env.BASE || "http://localhost:8080/tt-quietbox2-guide";
const url = `${BASE}/ml-practitioner/03-vllm-on-qb2/`;

const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  await page.goto(url, { waitUntil: "networkidle" });

  const items = await page.$$(".chapter-subnav .chapter-subnav-item");
  const h2s = await page.$$(".track-content h2");
  if (items.length === 0) throw new Error("no sub-nav items rendered");
  if (items.length !== h2s.length) throw new Error(`subnav ${items.length} != h2 ${h2s.length}`);
  console.log(`OK: ${items.length} sub-nav items match ${h2s.length} H2s`);

  await items[2].click();
  await page.waitForTimeout(700);
  const hash = await page.evaluate(() => location.hash);
  if (!hash) throw new Error("clicking an item did not set location.hash");
  console.log("OK: click set hash", hash);

  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  await page.waitForTimeout(700);
  const lastActive = await page.evaluate(() =>
    document.querySelector(".chapter-subnav .chapter-subnav-item:last-child")
      ?.classList.contains("active"));
  if (!lastActive) throw new Error("scroll-spy did not activate the last section at page bottom");
  console.log("OK: scroll-spy activates last section at bottom");

  await page.setViewportSize({ width: 375, height: 800 });
  const hidden = await page.evaluate(() => {
    const el = document.querySelector(".chapter-subnav");
    return !!el && getComputedStyle(el).display === "none";
  });
  if (!hidden) throw new Error("sub-nav not hidden on mobile viewport");
  console.log("OK: sub-nav hidden on mobile");

  console.log("ALL SUBNAV E2E CHECKS PASSED");
} finally {
  await browser.close();
}
```

- [ ] **Step 5: Run the e2e check**

In one terminal: `npm run serve`
In another (wait until the first prints its local URL):
```bash
npx playwright install chromium   # first run only, if the browser isn't present
node test/subnav.e2e.mjs
```
Expected: prints four `OK:` lines then `ALL SUBNAV E2E CHECKS PASSED`. Stop the server afterward.

- [ ] **Step 6: Commit**

```bash
git add src/assets/main.js src/assets/style.css test/subnav.e2e.mjs
git commit -m "feat: scroll-spy highlight + styling for chapter section TOC"
```

---

## Self-Review

- **Spec coverage:** heading ids (Task 2) · own markdown-it rule, no dep (Task 1/2) · `chapterHeadings` filter (Task 2) · active-only sub-nav in `track.njk` (Task 3) · H2-only (extractH2Headings + template) · scroll-spy + smooth scroll + hash (Task 4) · CSS incl. `scroll-margin-top` and mobile-hide (Task 4) · no landing/read sub-nav (Task 3 Step 3 guard) · dedupe for the read page (Task 1 plugin). All covered.
- **Placeholders:** none — every step has full code/commands.
- **Type consistency:** `slugify` / `headingAnchors` / `extractH2Headings` names match across Tasks 1–2; markup classes `chapter-subnav` / `chapter-subnav-item` match across Tasks 3–4; filter name `chapterHeadings` matches Tasks 2–3.
