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
// render using a fresh local Set. Never clobbers an explicit id.
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
