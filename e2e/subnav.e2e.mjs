// Integration check for the chapter sub-nav. Requires the dev server running:
//   npm run serve      (serves at http://localhost:8080/tt-quietbox2-guide/)
// then: node test/subnav.e2e.mjs
import { chromium } from "playwright";

const BASE = process.env.BASE || "http://localhost:8080/tt-quietbox2-guide";
const url = `${BASE}/ml-practitioner/03-vllm-on-qb2/`;

const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  await page.goto(url, { waitUntil: "networkidle" });

  const items = await page.$$(".chapter-subnav .chapter-subnav-item");
  const h2s = await page.$$(".track-content h2");
  if (items.length === 0) throw new Error("no sub-nav items rendered");
  if (items.length !== h2s.length) throw new Error(`subnav ${items.length} != h2 ${h2s.length}`);
  console.log(`OK: ${items.length} sub-nav items match ${h2s.length} H2s`);

  await items[2].click();
  await page.waitForTimeout(700);
  const hash = await page.evaluate(() => location.hash);
  if (!hash) throw new Error("clicking an item did not set location.hash");
  console.log("OK: click set hash", hash);

  await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
  // style.css sets `html { scroll-behavior: smooth }` site-wide, so this
  // programmatic scrollTo animates instead of jumping instantly, and the
  // animation's real-world duration varies run-to-run under headless
  // Chromium. Poll for the actual settled state instead of guessing a fixed
  // delay. (Real wheel/touch scrolling is unaffected by scroll-behavior and
  // updates the spy continuously, frame by frame — this is a test-harness
  // accommodation, not a product behavior change.)
  await page
    .waitForFunction(
      () =>
        document
          // Each item is the sole child of its own <li>, so plain
          // `.chapter-subnav-item:last-child` matches every item (each is
          // trivially the last/only child of its own <li>) and would grab
          // the *first* DOM match instead of the true last section. Select
          // the last <li> explicitly, then its item.
          .querySelector(".chapter-subnav li:last-child .chapter-subnav-item")
          ?.classList.contains("active"),
      null,
      { timeout: 5000 }
    )
    .catch(() => {});
  const lastActive = await page.evaluate(() =>
    document.querySelector(".chapter-subnav li:last-child .chapter-subnav-item")
      ?.classList.contains("active"));
  if (!lastActive) throw new Error("scroll-spy did not activate the last section at page bottom");
  console.log("OK: scroll-spy activates last section at bottom");

  await page.setViewportSize({ width: 375, height: 800 });
  const hidden = await page.evaluate(() => {
    const el = document.querySelector(".chapter-subnav");
    return !!el && getComputedStyle(el).display === "none";
  });
  if (!hidden) throw new Error("sub-nav not hidden on mobile viewport");
  console.log("OK: sub-nav hidden on mobile");

  console.log("ALL SUBNAV E2E CHECKS PASSED");
} finally {
  await browser.close();
}
