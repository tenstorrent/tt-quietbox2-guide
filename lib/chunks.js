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
//   * Blank lines *inside* <pre> are part of the code → replaced with an empty
//     <span>, which renders as an empty line, copies as an empty line, and is
//     not a blank line as far as markdown-it is concerned.

const PRE_OPEN = /<pre\b/gi;
const PRE_CLOSE = /<\/pre\s*>/gi;

// Placeholder for a significant (in-<pre>) blank line. Produces no text, so it
// neither renders nor copies as anything — it only keeps the line non-blank.
const BLANK_LINE_PLACEHOLDER = "<span></span>";

function countMatches(line, re) {
  re.lastIndex = 0;
  const m = line.match(re);
  return m ? m.length : 0;
}

/**
 * Remove every blank line from a fragment of rendered HTML, preserving blank
 * lines that fall inside a <pre> element as empty spans.
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
      if (preDepth > 0) out.push(BLANK_LINE_PLACEHOLDER);
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
