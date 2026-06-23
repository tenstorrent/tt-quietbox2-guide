const syntaxHighlight = require("@11ty/eleventy-plugin-syntaxhighlight");
const markdownIt = require("markdown-it");
const markdownItContainer = require("markdown-it-container");

module.exports = function (eleventyConfig) {
  // ---------------------------------------------------------------------------
  // Passthrough copies
  // ---------------------------------------------------------------------------
  eleventyConfig.addPassthroughCopy({ "src/assets": "assets" });
  eleventyConfig.addPassthroughCopy({ "llms.txt": "llms.txt" });
  eleventyConfig.addPassthroughCopy({ "agents.md": "agents.md" });

  // ---------------------------------------------------------------------------
  // Plugins
  // ---------------------------------------------------------------------------
  eleventyConfig.addPlugin(syntaxHighlight);

  // ---------------------------------------------------------------------------
  // Markdown-it with callout containers
  // Syntax: :::callout type="tip|warn|deep-dive"
  //         content
  //         :::
  // ---------------------------------------------------------------------------
  const md = markdownIt({ html: true, linkify: true, typographer: true });
  md.use(markdownItContainer, "callout", {
    validate(params) {
      // Accept lines like: callout type="tip"
      return params.trim().match(/^callout\s+type="(tip|warn|deep-dive)"$/);
    },
    render(tokens, idx) {
      const m = tokens[idx].info.trim().match(/^callout\s+type="([\w-]+)"$/);
      if (tokens[idx].nesting === 1) {
        // opening tag
        return `<div class="callout callout--${m[1]}">\n`;
      }
      // closing tag
      return `</div>\n`;
    },
  });
  eleventyConfig.setLibrary("md", md);

  // ---------------------------------------------------------------------------
  // Shortcodes
  // ---------------------------------------------------------------------------

  /**
   * chunk shortcode — inlines a shared Markdown snippet from src/content/shared/
   * Usage in templates: {% chunk "install-stack" %}
   * The file src/content/shared/install-stack.md will be rendered as HTML and
   * inserted inline — no extra HTTP round-trip, no iframe.
   */
  eleventyConfig.addNunjucksAsyncShortcode("chunk", async function (name) {
    const fs = require("fs");
    const path = require("path");
    const filePath = path.join(__dirname, "src/content/shared", `${name}.md`);
    if (!fs.existsSync(filePath)) {
      throw new Error(`Shared chunk not found: ${name}`);
    }
    const raw = fs.readFileSync(filePath, "utf8");
    return md.render(raw);
  });

  /**
   * tensixviz shortcode — embeds a Tensix Grid Visualizer widget.
   * Usage: {% tensixviz "blackhole", [{"step":"highlight",...}] %}
   * arch: "wormhole" | "blackhole"
   * script: JSON array of animation steps
   */
  eleventyConfig.addShortcode("tensixviz", function (arch, script) {
    const ARCH_LABELS = { wormhole: "Wormhole (N150/N300)", blackhole: "Blackhole (P100/P150/P300c / QB2)" };
    const archLabel = ARCH_LABELS[arch] || arch;
    const scriptJson = JSON.stringify(script || []);
    const escaped = scriptJson.replace(/&/g,"&amp;").replace(/"/g,"&quot;").replace(/'/g,"&#39;");
    return `<div class="tensix-viz-wrapper illustrated-only">
  <div class="tensix-viz-header">
    <span class="tensix-viz-title">⬡ Tensix Grid — ${archLabel}</span>
  </div>
  <div class="tensix-viz-body">
    <div class="tensix-viz-container" data-arch="${arch}" data-script="${escaped}">
      <canvas class="tensix-viz-canvas" width="520" height="320"></canvas>
      <div class="tensix-viz-controls">
        <button class="tv-play">▶</button>
        <button class="tv-step">⏭</button>
      </div>
      <div class="tv-legend"></div>
    </div>
  </div>
</div>`;
  });

  /**
   * tensixsystem shortcode — multi-chip system view using the real topology.
   * Usage: {% tensixsystem "qb2", "Your four Blackhole chips" %}
   * Renders genuine chips (qb2 = 2× p300c cards = 4 chips), not one chip
   * split into quadrants. `config` is a registered topology name from the
   * tensix-viz bundle (qb2, t3000, …); the widget auto-activates on load.
   */
  eleventyConfig.addShortcode("tensixsystem", function (config, title) {
    const cfg = config || "qb2";
    const heading = title || "QB2 — four Blackhole chips";
    const esc = (s) =>
      String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    return `<div class="tensix-viz-wrapper illustrated-only">
  <div class="tensix-viz-header">
    <span class="tensix-viz-title">⬡ ${esc(heading)}</span>
  </div>
  <div class="tensix-viz-body">
    <div data-viz="system" data-config="${esc(cfg)}" data-mode="active"></div>
  </div>
</div>`;
  });

  /**
   * card shortcode — a rich resource card (lesson / repo / tool / model / site).
   * Usage: {% card "repo", "https://github.com/tenstorrent/tt-toplike", "tt-toplike", "Real-time ASCII hardware monitor.", "Rust · .deb / cargo" %}
   * kind: lesson | repo | tool | model | site (sets the accent + label)
   * Internal URLs (starting "/") open in-place with a → arrow; external get ↗.
   * Wrap several in <div class="rcard-grid">…</div> for a responsive grid.
   */
  eleventyConfig.addShortcode("card", function (kind, url, title, desc, meta) {
    const esc = (s) =>
      String(s == null ? "" : s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    const LABELS = { lesson: "Lesson", repo: "GitHub", tool: "Tool", model: "Model", site: "Site" };
    const label = LABELS[kind] || "Link";
    const external = /^https?:\/\//.test(url);
    const attrs = external ? ' target="_blank" rel="noopener"' : "";
    const arrow = external ? "↗" : "→";
    const metaHtml = meta ? `\n  <span class="rcard-meta">${esc(meta)}</span>` : "";
    return `<a class="rcard rcard--${esc(kind)}" href="${esc(url)}"${attrs}>
  <span class="rcard-kind">${label} ${arrow}</span>
  <span class="rcard-title">${esc(title)}</span>
  <span class="rcard-desc">${esc(desc)}</span>${metaHtml}
</a>`;
  });

  // ---------------------------------------------------------------------------
  // Collections
  // ---------------------------------------------------------------------------

  /**
   * firstTimerChapters — returns all pages tagged "first-timer-chapter" sorted
   * by inputPath (alphabetically) so chapters appear in the correct 01→06 order
   * on the /read/first-timer/ long-form page.
   */
  eleventyConfig.addCollection("firstTimerChapters", function (collectionApi) {
    return collectionApi
      .getFilteredByTag("first-timer-chapter")
      .sort((a, b) => a.inputPath.localeCompare(b.inputPath));
  });

  eleventyConfig.addCollection("mlPractitionerChapters", function (collectionApi) {
    return collectionApi
      .getFilteredByTag("ml-practitioner-chapter")
      .sort((a, b) => a.inputPath.localeCompare(b.inputPath));
  });

  eleventyConfig.addCollection("builderHackerChapters", function (collectionApi) {
    return collectionApi
      .getFilteredByTag("builder-hacker-chapter")
      .sort((a, b) => a.inputPath.localeCompare(b.inputPath));
  });

  eleventyConfig.addCollection("tinkererChapters", function (collectionApi) {
    return collectionApi
      .getFilteredByTag("tinkerer-chapter")
      .sort((a, b) => a.inputPath.localeCompare(b.inputPath));
  });

  // ---------------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------------

  /**
   * readTime — converts a persona's chapters array into a human-readable
   * total reading time string.
   * Usage: {{ persona.chapters | readTime }}
   * Returns e.g. "41 min"
   */
  eleventyConfig.addFilter("readTime", (chapters) => {
    const total = (chapters || []).reduce((sum, c) => sum + (c.time || 5), 0);
    return `${total} min`;
  });

  /**
   * findPersona — looks up a persona by id from the personas global data array.
   * Usage: {{ personas | findPersona("first-timer") }}
   * Returns the full persona object, or undefined if not found.
   * Used by chapter templates to get persona color/name from front-matter id.
   */
  eleventyConfig.addFilter("findPersona", (personas, id) => {
    return (personas || []).find((p) => p.id === id);
  });

  // ---------------------------------------------------------------------------
  // Eleventy directory configuration
  // ---------------------------------------------------------------------------
  return {
    dir: {
      // Content lives in src/content/; _includes and _data are siblings of src/content/
      input: "src/content",
      includes: "../_includes",
      data: "../_data",
      output: "_site",
    },
    markdownTemplateEngine: "njk",
    htmlTemplateEngine: "njk",
  };
};
