# Chapter sub-nav (in-page section TOC) — design

**Date:** 2026-07-02
**Branch:** `feat/chapter-subnav-toc`

## Problem

The left-hand chapter nav (`.chapter-nav` in `src/_includes/layouts/track.njk`) lists a
persona's chapters and highlights the active one, but gives no view into what's *inside*
the chapter you're reading. Readers can't see the breadth of a chapter's content at a
glance, and there's no in-page navigation.

## Goal

Under the **active** chapter in the left nav, show that chapter's top-level (`<h2>`)
sections as a clickable, scroll-spy table of contents — so readers see the chapter's
structure at a glance and can jump to / track their position within it.

## Decisions (locked)

- **Scope:** only the active chapter shows child headings.
- **Depth:** `<h2>` only (flat list). H3 is rare (16 site-wide) and intentionally omitted.
- **Behavior:** scroll-spy — the heading currently in view is highlighted as you scroll;
  clicking an item smooth-scrolls to it and sets the URL hash.
- **Generation:** build-time (Eleventy) for the ID assignment and the list markup. The
  only runtime code is the scroll-spy highlight (inherently runtime).
- **No new dependencies, no external/runtime services.** Heading IDs are added with our
  own small `markdown-it` rule (not `markdown-it-anchor`); the list is rendered from our
  own Eleventy filter; scroll-spy uses the browser-native `IntersectionObserver`.

## Design

### 1. Heading IDs — own `markdown-it` core rule (`.eleventy.js`)

Add a `core` ruler rule to the existing `markdownIt` instance (which already carries a
custom container plugin). For each `heading_open` token of level `h2` (and `h3`/`h4` too,
so all headings become deep-linkable), read the following `inline` token's text content,
slugify it, and set the `id` attribute via `token.attrSet("id", slug)`.

- **Slugify:** lowercase; strip anything not `[a-z0-9]+`; collapse runs to single `-`;
  trim leading/trailing `-`.
- **Dedupe:** keep a `Set` of used slugs in `state.env` (reset per render); on collision
  append `-2`, `-3`, … This is important for the `read/` "read it all" page, which
  concatenates every chapter and will repeat headings.
- Skips headings that produce an empty slug (falls back to `section-<n>`).
- Only sets `id` when the token doesn't already have one (never clobbers an explicit id).
- Note: dedupe is per-render. The `read/` "read it all" page concatenates chapters; if it
  renders as separate passes, identical headings across chapters could repeat ids there.
  That page has no sub-nav and this only affects deep-link precision, so it's acceptable.

### 2. `chapterHeadings` filter (`.eleventy.js`)

`eleventyConfig.addFilter("chapterHeadings", (content) => [...])` — regex the rendered
HTML for `<h2[^>]*id="([^"]+)"[^>]*>(.*?)</h2>`, strip inner tags from the captured text,
decode basic entities, and return `[{ id, text }]`. Returns `[]` when there are none.

### 3. `track.njk` — render the sub-nav under the active chapter

Inside the chapter loop, when `ch.slug == currentChapter`, render (only if
`chapterHeadings(content)` is non-empty):

```njk
{% set _headings = content | chapterHeadings %}
{% if ch.slug == currentChapter and _headings.length %}
<ul class="chapter-subnav">
  {% for h in _headings %}
  <li><a class="chapter-subnav-item" href="#{{ h.id }}">{{ h.text }}</a></li>
  {% endfor %}
</ul>
{% endif %}
```

`content` in the layout is the current page's rendered HTML = the active chapter, so scope
is automatically "active chapter only" — no cross-page heading extraction needed.

### 4. `main.js` — scroll-spy only (`initChapterSubnav`)

New IIFE, guarded on `.chapter-subnav` existing (inert elsewhere):

- Collect the `<h2 id>` targets referenced by `.chapter-subnav-item` links.
- `IntersectionObserver` (rootMargin tuned so a heading counts as "current" once it passes
  under the top bar, e.g. `-80px 0px -70% 0px`) toggles `.active` on the matching
  `.chapter-subnav-item`. When several qualify, the topmost wins; before the first heading,
  the first item is active.
- Click handler: `preventDefault`, smooth-scroll to the target, set `location.hash`.
- No `pathPrefix` concern — links are pure `#id`.

### 5. `style.css`

- `.chapter-subnav`: list-reset, indented under the active item, small text, subtle
  left border; `.chapter-subnav-item` muted, `:hover` and `.active` use
  `var(--persona-color, var(--teal))` to match `.chapter-nav-item.active`.
- Add `scroll-margin-top` (~80px) to `h2, h3, h4` so anchored headings clear the sticky
  top bar.
- Hide `.chapter-subnav` in the mobile nav media query (the nav is a horizontal scroll bar
  there; a nested vertical TOC doesn't fit).

## Out of scope / non-goals

- No sub-nav on the landing page or the `read/` page (no `.chapter-nav` active item / not
  wanted there).
- No H3+ in the TOC list (IDs are still added for deep-linking, just not listed).
- No collapsible tree across all chapters.
- No mobile sub-nav.

## Testing (manual)

Build the site, then:
1. Long chapter (`ml-practitioner/03-vllm-on-qb2`, 11 H2s): sub-nav lists all 11.
2. Every `<h2>` in the built chapter HTML has a unique `id`; `read/` page IDs don't collide.
3. Click a sub-nav item → smooth-scroll to that section, hash updates, heading not hidden
   under the top bar.
4. Scroll the chapter → the active sub-nav item tracks the section in view.
5. Landing page and `read/` page: no `.chapter-subnav` rendered / no errors.
6. Narrow viewport: `.chapter-subnav` hidden.
