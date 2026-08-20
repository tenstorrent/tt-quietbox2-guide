"use strict";

// Shared-chunk injection helpers. Dependency-free and pure so they can be
// unit-tested with `node --test` and reused from .eleventy.js. Kept in lib/
// (outside src/content) so Eleventy never treats this as a template.

// Why this file exists
// -------------------
// The `chunk` shortcode renders a file from src/content/shared/ to HTML and
// inlines it into the including page — which is itself a Markdown template.
// markdown-it therefore sees that HTML and parses it a *second* time, as a raw
// HTML block. Per CommonMark, an HTML block of type 6/7 ends at the first blank
// line. So a single blank line inside a fenced code block in a shared chunk
// silently terminates the HTML block, and everything after it is re-parsed as
// Markdown: a `# comment` line becomes an <h1>, bare URLs get linkified, quotes
// get curled by the typographer, and the closing </code></pre> ends up wrapped
// in a <p>. The visible damage is that the code block stops being
// copy-pasteable — which is the whole point of a code block in an install guide.
//
// The fix is to hand the page HTML that contains no blank lines at all:
//   * Blank lines *between* block elements are insignificant → dropped.
//   * Blank lines *inside* <pre> are part of the code → kept, with an empty
//     <span> appended so the line is no longer blank to markdown-it. The span
//     contributes no text of its own, so the line still renders and copies as
//     exactly what the author wrote (an empty line, or whatever whitespace they
//     put there) — the surrounding newlines are what make it look empty.

const PRE_OPEN = /<pre\b/gi;
const PRE_CLOSE = /<\/pre\s*>/gi;

// Appended to a significant (in-<pre>) blank line. Produces no text of its own,
// so it changes neither the rendered nor the copied code; its only job is to
// stop markdown-it seeing the line as blank.
const BLANK_LINE_PLACEHOLDER = "<span></span>";

function countMatches(line, re) {
  re.lastIndex = 0;
  const m = line.match(re);
  return m ? m.length : 0;
}

/**
 * Remove every blank line from a fragment of rendered HTML. Blank lines inside
 * a <pre> are kept verbatim — whitespace included — with an empty <span>
 * appended so they no longer read as blank to markdown-it.
 *
 * @param {string} html rendered HTML fragment
 * @returns {string} the same fragment with no blank lines
 */
function flattenBlankLines(html) {
  const out = [];
  let preDepth = 0;

  for (const line of String(html).split("\n")) {
    if (line.trim() === "") {
      // A blank line carries no tags, so preDepth needs no update here.
      // Append rather than replace: a whitespace-only line is blank to
      // markdown-it but is real content inside a code block, and dropping its
      // spaces would change what the reader copies out.
      if (preDepth > 0) out.push(line + BLANK_LINE_PLACEHOLDER);
      continue;
    }
    out.push(line);
    preDepth += countMatches(line, PRE_OPEN);
    preDepth -= countMatches(line, PRE_CLOSE);
    if (preDepth < 0) preDepth = 0;
  }

  return out.join("\n");
}

module.exports = { flattenBlankLines, BLANK_LINE_PLACEHOLDER };
