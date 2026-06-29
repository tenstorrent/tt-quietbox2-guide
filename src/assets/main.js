// Personality toggle
(function () {
  const KEY = "qb2-guide-mode";
  const html = document.documentElement;
  const btn = document.getElementById("mode-toggle");

  function applyMode(mode) {
    html.setAttribute("data-mode", mode);
    localStorage.setItem(KEY, mode);
  }

  // Restore saved mode
  const saved = localStorage.getItem(KEY) || "illustrated";
  applyMode(saved);

  if (btn) {
    btn.addEventListener("click", function () {
      const current = html.getAttribute("data-mode");
      applyMode(current === "illustrated" ? "facts" : "illustrated");
    });
  }
})();

// Light / dark theme toggle. The initial value is applied by an inline <head>
// script (to avoid a flash); here we just wire the button and persist changes.
(function () {
  const KEY = "qb2-guide-theme";
  const html = document.documentElement;
  const btn = document.getElementById("theme-toggle");
  if (!btn) return;
  btn.addEventListener("click", function () {
    const next = html.getAttribute("data-theme") === "light" ? "dark" : "light";
    html.setAttribute("data-theme", next);
    try { localStorage.setItem(KEY, next); } catch (e) {}
  });
})();

// Resolve the site's base path (pathPrefix) from a link Eleventy already
// rewrote — the topbar logo points at the site root ("/" or "/tt-quietbox2-guide/").
// JS navigation strings are NOT rewritten by EleventyHtmlBasePlugin, so we must
// prepend this ourselves or links break when served under a subpath.
function qb2Base() {
  const logo = document.querySelector(".tt-nav-logo");
  const href = logo && logo.getAttribute("href");
  return href && href !== "#" ? href.replace(/\/$/, "") : "";
}

// Venn diagram interactivity
(function () {
  const coupletEl = document.querySelector(".hero-couplet");
  if (!coupletEl) return;

  const defaultHTML = coupletEl.innerHTML;
  const circles = document.querySelectorAll(".venn-circle");

  // Reserve vertical space for the couplet so swapping between the default
  // (one line) and the hover states (two paragraphs, which may wrap on narrow
  // viewports) never reflows the page below it. We measure every possible
  // state in an OFF-SCREEN CLONE — never touching the live element's text — so
  // a resize that fires mid-hover can't reset what the reader is currently
  // looking at. The tallest result becomes the live element's min-height.
  // Content stays vertically centred within the reserved box (see
  // .hero-couplet in style.css).
  function reserveCoupletSpace() {
    // Shallow clone keeps the class (so font/width/CSS match) but no children;
    // we drive its content via innerHTML below.
    const probe = coupletEl.cloneNode(false);
    probe.removeAttribute("id"); // never duplicate the live element's id
    probe.style.minHeight = ""; // measure natural height, not a prior reservation
    probe.style.position = "absolute";
    probe.style.visibility = "hidden";
    probe.style.left = "-9999px";
    probe.style.top = "0";
    probe.style.width = coupletEl.clientWidth + "px"; // match wrapping width
    coupletEl.parentNode.appendChild(probe);

    // Default (one line) plus every persona's two-paragraph hover state.
    const states = [defaultHTML];
    circles.forEach(function (circle) {
      const line1 = circle.getAttribute("data-couplet-1");
      if (!line1) return;
      const line2 = circle.getAttribute("data-couplet-2");
      states.push(`<p>${line1}</p><p>${line2 || ""}</p>`);
    });

    let tallest = 0;
    states.forEach(function (html) {
      probe.innerHTML = html;
      tallest = Math.max(tallest, probe.offsetHeight);
    });

    coupletEl.parentNode.removeChild(probe);
    coupletEl.style.minHeight = tallest + "px";
  }
  reserveCoupletSpace();
  // Debounce resize so a drag-resize doesn't force a reflow on every pixel.
  let resizeTimer;
  window.addEventListener("resize", function () {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(reserveCoupletSpace, 150);
  });

  // Couplets injected from personas.json via data-* on each circle
  circles.forEach(function (circle) {
    circle.addEventListener("mouseenter", function () {
      const line1 = circle.getAttribute("data-couplet-1");
      const line2 = circle.getAttribute("data-couplet-2");
      if (line1) {
        coupletEl.innerHTML = `<p>${line1}</p><p>${line2 || ""}</p>`;
      }
    });
    circle.addEventListener("mouseleave", function () {
      coupletEl.innerHTML = defaultHTML;
    });
    circle.addEventListener("click", function () {
      const persona = circle.getAttribute("data-persona");
      if (persona) window.location.href = qb2Base() + "/" + persona + "/";
    });
    circle.addEventListener("keydown", function (e) {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        const persona = circle.getAttribute("data-persona");
        if (persona) window.location.href = qb2Base() + "/" + persona + "/";
      }
    });
  });
})();

// Mobile chapter strip — centre the active chapter so readers can see where they
// are in the track. Only runs when the nav has collapsed to the horizontal strip
// (scrollWidth exceeds clientWidth); the desktop vertical sidebar is left alone.
(function () {
  const nav = document.querySelector(".chapter-nav");
  if (!nav) return;
  const active = nav.querySelector(".chapter-nav-item.active");
  if (!active || nav.scrollWidth <= nav.clientWidth) return;
  active.scrollIntoView({ inline: "center", block: "nearest" });
})();
