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

test("headingAnchors keeps a pre-existing id", () => {
  const md = new MarkdownIt();
  md.core.ruler.push("preset_id", (state) => {
    for (const t of state.tokens) {
      if (t.type === "heading_open") t.attrSet("id", "manual-anchor");
    }
    return true;
  });
  md.use(headingAnchors);
  const html = md.render("## Some Title");
  assert.match(html, /<h2 id="manual-anchor">Some Title<\/h2>/);
});

test("headingAnchors adds ids to h4 too", () => {
  const md = new MarkdownIt().use(headingAnchors);
  assert.match(md.render("#### Deep Note"), /<h4 id="deep-note">Deep Note<\/h4>/);
});

test("extractH2Headings ignores a data-id attribute (matches the real id)", () => {
  assert.deepEqual(extractH2Headings('<h2 data-id="wrong" id="right">Title</h2>'), [
    { id: "right", text: "Title" },
  ]);
});
