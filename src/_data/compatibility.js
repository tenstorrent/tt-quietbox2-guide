/**
 * Fetches the Tenstorrent model compatibility matrix at build time and
 * returns the subset relevant to QB2 hardware (Quietbox 2, p150, p300).
 *
 * Internal link map overrides the default tt-inference-server GitHub link
 * for models that have a dedicated page in this guide.
 */

const COMPAT_URL = "https://d1oi7xemha0dsy.cloudfront.net/data/compatibility.json";

// QB2-relevant hardware keys in the compatibility data
const QB2_HARDWARE = new Set(["Quietbox 2", "p150", "p300"]);

// Map model id → internal guide URL (takes priority over external links)
const INTERNAL_LINKS = {
  "flux-1-dev":    "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/qb2-video-generation/",
  "flux-1-schnell":"https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/qb2-video-generation/",
};

// Map software tool → canonical docs URL (fallback when no model-specific page exists)
const SOFTWARE_URLS = {
  "tt-inference-server": "https://github.com/tenstorrent/tt-inference-server",
  "tt-metal":            "https://github.com/tenstorrent/tt-metal",
  "tt-forge":            "https://github.com/tenstorrent/tt-forge-onnx",
};

// Hardware priority — Quietbox 2 is the exact system, prefer it
const HARDWARE_PRIORITY = { "Quietbox 2": 0, p300: 1, p150: 2 };

// Status sort order (best first)
const STATUS_ORDER = { Supported: 0, Experimental: 1 };

// Tasks to exclude — internal CV benchmark models aren't useful to QB2 owners
// unless they have a known display name (i.e. not auto-generated slugs)
function isCVBenchmarkSlug(id) {
  return /^cv-(image-cls|img-to-img|object-det)-/.test(id);
}

// Human-readable task label cleanup
function cleanTask(task) {
  if (!task || task === "Unknown") return null;
  return task;
}

// Pick the best (highest-status) QB2 compatibility entry for a model
function bestQB2Entry(compatibilities) {
  const qb2 = compatibilities.filter(
    (c) => QB2_HARDWARE.has(c.hardware) && c.status !== "Not Supported"
  );
  if (!qb2.length) return null;
  return qb2.sort(
    (a, b) => (STATUS_ORDER[a.status] ?? 99) - (STATUS_ORDER[b.status] ?? 99)
  )[0];
}

// Build the link for a model entry
function buildLink(id, software) {
  if (INTERNAL_LINKS[id]) return INTERNAL_LINKS[id];
  const tool = (software || [])[0];
  return SOFTWARE_URLS[tool] || "https://github.com/tenstorrent/tt-inference-server";
}

// Format model size for display (e.g. "27000000000" → "27B")
function formatSize(size) {
  if (!size) return null;
  // Already a string like "27B" or "335M"
  if (typeof size === "string") return size;
  const n = Number(size);
  if (n >= 1e9) return `${Math.round(n / 1e9)}B`;
  if (n >= 1e6) return `${Math.round(n / 1e6)}M`;
  return String(n);
}

module.exports = async function () {
  try {
    const res = await fetch(COMPAT_URL);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();

    const models = (data.models || [])
      .filter((model) => !isCVBenchmarkSlug(model.id))
      .map((model) => {
        const entry = bestQB2Entry(model.compatibility || []);
        if (!entry) return null;

        const task = (model.tasks || []).map(cleanTask).filter(Boolean)[0] || null;
        const size = formatSize(model.model_size);

        return {
          id: model.id,
          name: model.display_name || model.id,
          family: model.family || null,
          task,
          size,
          status: entry.status,       // "Supported" | "Experimental"
          hardware: entry.hardware,   // "Quietbox 2" | "p150" | "p300"
          software: entry.software || [],
          link: buildLink(model.id, entry.software),
          description: model.model_description || null,
          metrics: (entry.metrics || []).slice(-1)[0] || null, // most recent metric
        };
      })
      .filter(Boolean)
      // Sort: Supported first, then Experimental;
      // within each status: Quietbox 2 entries before p150/p300; then alpha
      .sort((a, b) => {
        const sd = (STATUS_ORDER[a.status] ?? 99) - (STATUS_ORDER[b.status] ?? 99);
        if (sd !== 0) return sd;
        const hd = (HARDWARE_PRIORITY[a.hardware] ?? 99) - (HARDWARE_PRIORITY[b.hardware] ?? 99);
        return hd !== 0 ? hd : a.name.localeCompare(b.name);
      });

    return {
      models,
      generatedAt: data.metadata?.generated_at || null,
      fetchedOk: true,
    };
  } catch (err) {
    console.warn("[compatibility.js] Failed to fetch compatibility data:", err.message);
    return { models: [], generatedAt: null, fetchedOk: false };
  }
};
