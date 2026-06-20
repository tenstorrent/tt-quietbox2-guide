# QB2 Guide — Design Spec

**Date:** 2026-06-20  
**Author:** Taylor Singletary (voice), Claude Code (architecture)  
**Status:** Approved for implementation

---

## Overview

An interactive web guide to the Tenstorrent Quietbox 2 — part choose-your-own-adventure, part reference, part love letter to a genuinely interesting machine. Inspired by the Commodore 64 User's Guide, Why's Poignant Guide to Ruby, and the ARP 2600 manual. Built to live at the intersection of narrative warmth and technical precision.

Not just a getting-started doc. A guide to what this machine *is*, what you can do with it, and how far you can go.

---

## Voice & Tone

**Source:** Taylor Singletary's writing philosophy ([@episod](https://medium.com/@episod), "Writing Great Documentation", Slack platform writing).

**Principles:**
- The reader stars in the story. *You* move, discover, build. The Quietbox is the terrain.
- No personifying the machine or AI/ML. The QB2 is a co-conspirator, not a character.
- Short punchy sentences after longer flowing ones. Couplets over paragraphs for introductory beats.
- Alliteration as emphasis, not decoration. Invented words welcome when they earn it.
- No weak sentence-enders ("one", "it", "this").
- Radical transparency — admit when things are hard, uncertain, or in progress.
- Fun is non-negotiable. Breaking rules is allowed when you know you're doing it.

**Two modes, one content source:**

| Mode | Character |
|------|-----------|
| **Illustrated** (default) | Full Taylor voice. Callouts in first-person narrator. Spot illustrations. |
| **Just the Facts** | Same structure, compressed callouts, illustrations hidden, tighter typography. |

Toggle persists via `localStorage`. Driven by `data-mode="illustrated|facts"` on `<body>`.

**Persona couplets (landing hero text):**

- *First Timer:* "Your first walk with a Quietbox doesn't have to be long to go somewhere new. This guide keeps pace with you."
- *ML Practitioner:* "You've run models before. You haven't run them like this — not at this speed, not on silicon you can actually touch."
- *Builder/Hacker:* "The architecture goes all the way down, and you're the one going with it. Bring something to build."
- *Curious Tinkerer:* "There's more to configure, illuminate, and break here than most machines will ever admit to having. Start anywhere."

---

## Personas

Four tracks, color-coded, overlapping:

| Persona | Color | Audience |
|---------|-------|----------|
| First Timer | Teal `#4FD1C5` | New to Linux, new to dedicated AI hardware, new to the Tenstorrent stack |
| ML Practitioner | Pink `#EC96B8` | Comfortable with models and Python, new to Tenstorrent hardware specifically |
| Builder/Hacker | Gold `#F4C471` | Systems-level developer, wants to write kernels, explore TT-Metal, go deep |
| Curious Tinkerer | Green `#27AE60` | Hobbyist, wants LEDs, cool demos, customization, breaking and fixing things |

**v1 scope:** First Timer track fully written. Other three tracks: outlined with real chapter titles and stubs sufficient for a reader to understand what's coming.

---

## Site Architecture

```
/                           ← Landing: SVG Venn + path chooser + personality toggle
/first-timer/               ← Full track (v1)
  /first-timer/[chapter]/   ← Individual chapter pages
/ml-practitioner/           ← Outlined, stubbed
/builder-hacker/            ← Outlined, stubbed
/tinkerer/                  ← Outlined, stubbed
/read/first-timer/          ← Long-form "whole enchilada" page
/read/ml-practitioner/      ← (stub, same template)
/read/builder-hacker/       ← (stub, same template)
/read/tinkerer/             ← (stub, same template)
llms.txt                    ← Root-level, llmstxt.org spec
agents.md                   ← Root-level, agentic task guide for QB2
```

**Eleventy data model:**
```
src/
  content/
    tracks/
      first-timer/chapters/    01-unboxing.md, 02-first-boot.md, ...
      ml-practitioner/chapters/
      builder-hacker/chapters/
      tinkerer/chapters/
    shared/                    install-stack.md, tt-smi-basics.md, run-first-model.md, ...
  _data/
    personas.json              name, couplet, color, venn-position, chapters[]
  _includes/
    layouts/
      base.njk
      track.njk
      read.njk
    components/
      venn.njk
      persona-card.njk
      chapter-nav.njk
      callout.njk
  assets/
    style.css
    main.js
    illustrations/             SVG spot art, teal/pink palette
```

---

## Content Structure — First Timer Track

Fully written in v1. Chapters:

1. **What Just Arrived** — Unboxing, physical overview, what the QB2 actually is (not just "AI accelerator" — what that *means*)
2. **First Boot** — Ubuntu first-login, terminal basics, orientation
3. **Is This Thing On?** — Running `tt-smi -s`, understanding the output, confirming hardware is alive
4. **Installing the Stack** — tt-installer walkthrough, what each component does and why
5. **Your First Model** — tt-studio or CLI model run, seeing inference happen
6. **What's Possible From Here** — Bridge chapter pointing to other tracks; Venn overlap map

Shared chunks used: `install-stack.md`, `tt-smi-basics.md`, `run-first-model.md`

---

## Content Structure — Other Tracks (Outlined, v1 Stubs)

**ML Practitioner:**
1. Coming from CUDA / another platform
2. Model zoo overview (tt-awesome entries)
3. Running vLLM on QB2
4. Performance tuning basics
5. What the Builder track offers next

**Builder/Hacker:**
1. The TT-Metal architecture
2. Writing your first kernel
3. TT-Lang introduction
4. Profiling and optimization (tt-toplike, tensix-viz)
5. Where to go deep

**Curious Tinkerer:**
1. LED customization
2. Fun demos (tt-animatediff, games, visualizations)
3. Ubuntu customization (KDE, Sway, theming)
4. Breaking and fixing things (common issues, recovery)
5. Community and contribution

---

## Shared Content Chunks

Authored once in `src/content/shared/`, included by Nunjucks macro `{% chunk "name" %}`:

| Chunk | Used by |
|-------|---------|
| `install-stack` | First Timer, ML Practitioner, Builder/Hacker, Tinkerer |
| `tt-smi-basics` | First Timer, Builder/Hacker, Tinkerer |
| `run-first-model` | First Timer, ML Practitioner, Tinkerer |
| `tt-studio-intro` | First Timer, ML Practitioner, Tinkerer |
| `hardware-overview` | First Timer, Builder/Hacker |

The Venn diagram intersection labels map directly to these chunk names.

---

## Component Specifications

### VennDiagram (SVG)
- Four overlapping circles, each a `<path>` with `data-persona="[name]"`
- Intersection regions are separate `<path>` elements labeled with shared chunk names
- Hover: circle highlights, couplet updates in hero text above
- Click: navigates to that persona track
- Intersection hover: highlights all circles that share that content, shows tooltip

### PersonaCard
- Below the Venn on landing
- Left border in persona color
- Couplet text
- "Enter →" link
- Truncated chapter list ("6 chapters · 30 min read")

### ChapterNav
- Left sidebar within any track page
- Chapter list with current position indicator
- Thin teal progress bar along left edge
- Collapses to icon-only on narrow viewports

### Callout
Markdown syntax: `:::callout type="tip|warn|deep-dive"` (Eleventy markdown-it plugin)

- **Illustrated mode:** Icon + colored border + first-person narrator voice
- **Facts mode:** Plain `>` blockquote, no icon, teal left border only

### SharedChunk
- Nunjucks macro: `{% chunk "install-stack" %}`
- Renders the shared Markdown inline
- In illustrated mode: subtle teal top border to indicate shared provenance
- In facts mode: invisible seam

### ReadPage (`/read/[persona]/`)
- All chapters rendered sequentially, no sidebar
- `@media print`: hides nav, toggle, sidebar; sets serif body font; page-breaks between chapters
- "Download as PDF" button triggers `window.print()`
- Clearly marks chapter boundaries with horizontal rules and numbering

---

## llms.txt

Follows [llmstxt.org](https://llmstxt.org) spec. Lives at `/llms.txt`. Documents:
- What the QB2 is (hardware summary, chip architecture)
- What this guide covers and who it's for
- Links to each track with one-line summaries
- Links to shared content chunks
- Pointer to `agents.md` for task-oriented AI use

Updated as content is added.

---

## agents.md

Lives at `/agents.md`. Documents:
- What an AI assistant can helpfully do *with* a QB2 (interpret `tt-smi -s` JSON, suggest models, debug install errors)
- QB2 hardware specifics: chip count, architecture (Blackhole), PCIe config, firmware update flow
- Tenstorrent ecosystem: tt-metal, tt-smi, tt-studio, tt-installer, tt-awesome
- Content section map by task type ("user wants to run a model" → First Timer ch5 + ML Practitioner)

---

## Tech Stack

| Layer | Choice | Reason |
|-------|--------|--------|
| SSG | Eleventy (11ty) | Already used by tt-awesome and tenstorrent.github.io |
| Templates | Nunjucks | 11ty default, used in all existing TT projects |
| CSS | Vanilla, single file | Inherits tt-awesome design tokens |
| JS | Vanilla, single file | Venn interaction + personality toggle, no framework needed |
| Illustrations | Inline SVG | Teal/pink palette, hides cleanly in Facts mode |
| PDF | CSS @media print | No extra tooling, works from `/read/[persona]/` |

---

## Design Tokens (inherited from tt-awesome)

```css
--bg0: #0F2A35;   /* deepest background */
--bg1: #1A3C47;   /* content areas */
--bg2: #2D3142;   /* secondary elements */
--bg3: #0a1e28;   /* topbar / sidebar */
--teal: #4FD1C5;
--teal-lt: #81E6D9;
--pink: #EC96B8;
--gold: #F4C471;
--green: #27AE60;
--text: #E8F0F2;
--text2: #B0C4DE;
--muted: #607D8B;
```

---

## Error Handling & Edge Cases

- No JS: Venn falls back to static persona cards; personality toggle hidden; all content readable
- Narrow viewport: ChapterNav collapses; Venn scales down with `viewBox`; persona cards stack vertically
- Print: ReadPage handles this; track pages print without sidebar/nav via `@media print`
- Shared chunk missing: Eleventy build fails loudly — no silent gaps in content

---

## Success Criteria (v1)

- [ ] Landing page loads with working Venn diagram and persona cards
- [ ] First Timer track has 6 complete chapters with real content from existing docs
- [ ] Personality toggle works and persists across pages
- [ ] `/read/first-timer/` renders all chapters and prints cleanly
- [ ] Other three tracks have stubs with chapter outlines visible
- [ ] `llms.txt` and `agents.md` present at root with meaningful content
- [ ] No build dependencies beyond Eleventy and a markdown-it plugin
- [ ] Design tokens match tt-awesome exactly
