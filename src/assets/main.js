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

// Resolve the site's base path (pathPrefix) from a link Eleventy already
// rewrote — the topbar logo points at the site root ("/" or "/tt-quietbox2-guide/").
// JS navigation strings are NOT rewritten by EleventyHtmlBasePlugin, so we must
// prepend this ourselves or links break when served under a subpath.
function qb2Base() {
  const logo = document.querySelector(".topbar-logo");
  const href = logo && logo.getAttribute("href");
  return href && href !== "#" ? href.replace(/\/$/, "") : "";
}

// Venn diagram interactivity
(function () {
  const coupletEl = document.querySelector(".hero-couplet");
  if (!coupletEl) return;

  const defaultHTML = coupletEl.innerHTML;

  // Couplets injected from personas.json via data-* on each circle
  document.querySelectorAll(".venn-circle").forEach(function (circle) {
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
