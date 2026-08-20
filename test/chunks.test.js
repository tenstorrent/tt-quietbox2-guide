const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const MarkdownIt = require("markdown-it");
const { flattenBlankLines, BLANK_LINE_PLACEHOLDER } = require("../lib/chunks.js");

// The chunk shortcode inlines rendered HTML into a page that is itself Markdown,
// so markdown-it parses that HTML again. These are the options that decide how
// the second pass treats it: html (parse it at all), linkify + typographer (the
// two transforms that visibly corrupt code when it leaks out of a <pre>).
// Callouts and heading anchors don't affect HTML-block termination, so a bare
// markdown-it is the right instrument here.
const makeMd = () => new MarkdownIt({ html: true, linkify: true, typographer: true });

// A chunk whose fenced block contains a blank line — the shape that broke.
const CHUNK_WITH_BLANK_LINE_IN_FENCE = [
  "## Install",
  "",
  "Run this:",
  "",
  "```bash",
  "# 1. keyring",
  "sudo mkdir -p /etc/apt/keyrings",
  "",
  "# 2. key",
  "sudo curl -fsSL -o /etc/apt/keyrings/tt-pkg-key.asc https://ppa.tenstorrent.com/tt-pkg-key.asc",
  "```",
  "",
  "Then reboot.",
].join("\n");

// Mimic the real pipeline: chunk HTML injected into a Markdown page, whole page
// rendered. `inject` lets a test opt out of the fix to prove it is load-bearing.
// Text of each <pre>...</pre> region, so assertions about code blocks can't
// accidentally match markup from elsewhere on the page.
function preRegions(html) {
  return [...html.matchAll(/<pre[\s\S]*?<\/pre>/g)].map((m) => m[0]);
}

function renderPageWithChunk(chunkMarkdown, inject = flattenBlankLines) {
  const md = makeMd();
  const chunkHtml = inject(md.render(chunkMarkdown));
  return { chunkHtml, pageHtml: md.render(`# Chapter\n\nIntro.\n\n${chunkHtml}\n\nOutro.\n`) };
}

test("flattenBlankLines drops insignificant blank lines between block elements", () => {
  const out = flattenBlankLines("<h2>H</h2>\n\n<p>a</p>\n\n\n<p>b</p>\n");
  assert.equal(out, "<h2>H</h2>\n<p>a</p>\n<p>b</p>");
  assert.ok(!/\n[ \t]*\n/.test(out), "no blank lines should survive");
});

test("flattenBlankLines keeps blank lines inside <pre> as empty spans", () => {
  const out = flattenBlankLines("<pre><code>one\n\ntwo</code></pre>\n");
  assert.equal(out, `<pre><code>one\n${BLANK_LINE_PLACEHOLDER}\ntwo</code></pre>`);
  // The placeholder contributes no text: the code still reads as before.
  assert.equal(out.replace(/<[^>]*>/g, ""), "one\n\ntwo");
});

test("flattenBlankLines tracks <pre> with attributes and same-line close", () => {
  const out = flattenBlankLines('<pre class="language-bash"><code>a\n\nb</code></pre>\n\n<p>after</p>');
  assert.match(out, new RegExp(`a\\n${BLANK_LINE_PLACEHOLDER}\\nb`));
  assert.match(out, /<\/pre>\n<p>after<\/p>$/);
});

test("a blank line inside a chunk's fenced block does NOT survive injection unflattened", () => {
  // Guard on the failure, not on the helper: without the fix the injected HTML
  // block ends at the blank line and the rest is re-parsed as Markdown.
  const { pageHtml } = renderPageWithChunk(CHUNK_WITH_BLANK_LINE_IN_FENCE, (html) => html);
  assert.match(pageHtml, /<h1>1\. keyring<\/h1>|<h1>2\. key<\/h1>/, "a # comment should have become a heading");
  assert.match(pageHtml, /<a href="https:\/\/ppa\.tenstorrent\.com/, "the URL should have been linkified");
});

test("flattened chunk HTML survives injection into a Markdown page intact", () => {
  const { chunkHtml, pageHtml } = renderPageWithChunk(CHUNK_WITH_BLANK_LINE_IN_FENCE);
  // Losslessness is the real contract: the page must contain the chunk verbatim.
  assert.ok(pageHtml.includes(chunkHtml), "chunk HTML should appear unmodified in the page");
  assert.ok(!/<h1>\d\. /.test(pageHtml), "no code comment should have become a heading");
  assert.ok(!/<a href="https:\/\/ppa\.tenstorrent\.com/.test(pageHtml), "no URL inside the code block should be linkified");
  for (const region of preRegions(pageHtml)) {
    assert.ok(!/<\/?p>/.test(region), "no paragraph should leak into a code block");
    assert.ok(!/<h[1-6]>/.test(region), "no heading should leak into a code block");
  }
});

test("every shared chunk on disk survives injection intact", () => {
  const dir = path.join(__dirname, "..", "src", "content", "shared");
  const files = fs.readdirSync(dir).filter((f) => f.endsWith(".md"));
  assert.ok(files.length > 0, "expected shared chunks to exist");

  for (const file of files) {
    const raw = fs.readFileSync(path.join(dir, file), "utf8");
    const { chunkHtml, pageHtml } = renderPageWithChunk(raw);
    assert.ok(
      pageHtml.includes(chunkHtml),
      `${file}: chunk HTML was altered when injected into a Markdown page — ` +
        "something in it terminates the raw HTML block (usually a blank line)"
    );
  }
});
