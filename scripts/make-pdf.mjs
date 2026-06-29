// Render the complete guide (/read/) to a single downloadable PDF at
// _site/assets/qb2-guide.pdf. The PDF is a plain static file, so it works on
// GitHub Pages exactly like any other asset. Run after the Eleventy build
// (CI does this as a step; locally use `npm run build:all`).
//
// Why a separate prefix-less build: the deployed site lives under a subpath
// (/tt-quietbox2-guide/), but for rendering we serve a `--pathprefix=/` copy at
// the server root so every asset resolves cleanly regardless of deploy target.
// The resulting PDF is path-agnostic and is dropped into the real _site output.

import { chromium } from "playwright";
import { execSync } from "node:child_process";
import { createServer } from "node:http";
import { readFile, mkdir, stat } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join, extname, resolve } from "node:path";

const ROOT = resolve(process.cwd());
const PDF_BUILD = join(ROOT, "_pdf");
const OUT = join(ROOT, "_site", "assets", "qb2-guide.pdf");
const PORT = 8099;

const MIME = {
  ".html": "text/html", ".css": "text/css", ".js": "text/javascript", ".json": "application/json",
  ".svg": "image/svg+xml", ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg",
  ".gif": "image/gif", ".webp": "image/webp", ".woff": "font/woff", ".woff2": "font/woff2",
  ".ico": "image/x-icon", ".pdf": "application/pdf",
};

// 1. Build a prefix-less copy purely for rendering.
console.log("[pdf] building prefix-less site → _pdf");
execSync("npx @11ty/eleventy --pathprefix=/ --output=_pdf", { cwd: ROOT, stdio: "inherit" });

// 2. Minimal static server rooted at _pdf.
const server = createServer(async (req, res) => {
  try {
    let p = decodeURIComponent(req.url.split("?")[0]);
    if (p.endsWith("/")) p += "index.html";
    let file = join(PDF_BUILD, p);
    if (existsSync(file) && (await stat(file)).isDirectory()) file = join(file, "index.html");
    if (!existsSync(file)) { res.statusCode = 404; res.end("not found"); return; }
    res.setHeader("Content-Type", MIME[extname(file)] || "application/octet-stream");
    res.end(await readFile(file));
  } catch (e) { res.statusCode = 500; res.end(String(e)); }
});
await new Promise((r) => server.listen(PORT, r));
console.log(`[pdf] serving _pdf at http://localhost:${PORT}`);

// 3. Render /read/ to PDF.
const browser = await chromium.launch();
const page = await browser.newPage();
// Light theme + full (illustrated) content, set before first paint.
await page.addInitScript(() => {
  try {
    localStorage.setItem("qb2-guide-theme", "light");
    localStorage.setItem("qb2-guide-mode", "illustrated");
  } catch (e) {}
});
await page.goto(`http://localhost:${PORT}/read/`, { waitUntil: "networkidle" });
await page.waitForTimeout(800);

// Print tweaks: drop chrome + interactive canvas widgets, break pages per track,
// let the reading column use the page width, keep atomic blocks together.
await page.addStyleTag({ content: `
  .tt-top-nav, .readall-actions { display: none !important; }
  .tensix-viz-wrapper, [data-viz] { display: none !important; }
  .site-main { max-width: none !important; padding: 0 6px !important; }
  body { background: #fff !important; }
  .readall-track { page-break-before: always; }
  .readall-track:first-of-type { page-break-before: avoid; }
  pre, table, img, figure, .callout { page-break-inside: avoid; }
` });
await page.emulateMedia({ media: "screen" });

await mkdir(join(ROOT, "_site", "assets"), { recursive: true });
await page.pdf({
  path: OUT,
  format: "Letter",
  printBackground: true,
  margin: { top: "0.6in", bottom: "0.7in", left: "0.6in", right: "0.6in" },
  displayHeaderFooter: true,
  headerTemplate: "<span></span>",
  footerTemplate: `<div style="width:100%;font-size:8px;color:#678583;padding:0 0.6in;display:flex;justify-content:space-between;">
    <span>Tenstorrent QuietBox 2 — The Complete Guide · docs.tenstorrent.com/tt-quietbox2-guide</span>
    <span class="pageNumber"></span></div>`,
});

await browser.close();
await new Promise((r) => server.close(r));
const kb = Math.round((await stat(OUT)).size / 1024);
console.log(`[pdf] wrote ${OUT} (${kb} KB)`);
