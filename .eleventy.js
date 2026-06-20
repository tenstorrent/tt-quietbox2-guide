const syntaxHighlight = require("@11ty/eleventy-plugin-syntaxhighlight");
const markdownIt = require("markdown-it");
const markdownItContainer = require("markdown-it-container");

module.exports = function (eleventyConfig) {
  // ---------------------------------------------------------------------------
  // Passthrough copies
  // ---------------------------------------------------------------------------
  eleventyConfig.addPassthroughCopy("src/assets");
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
