/**
 * Stamp of the last time this guide's content was hands-on verified against
 * a live TT-QuietBox 2 (not just built/linted). Update by hand after a real
 * verification pass — this is a claim about hardware, so it should only move
 * when someone actually re-checked things against a QB2.
 *
 * date: use an unambiguous, absolute format so it survives being read out of
 * context (e.g. "Aug 26, 2026").
 */
module.exports = {
  date: "Aug 26, 2026",
  components: [
    { label: "Firmware", value: "19.13.1.0" },
    { label: "tt-kmd", value: "2.10.0" },
    { label: "tt-smi", value: "6.1.0" },
    { label: "tt-metal", value: "v0.77.0" },
    { label: "tt-studio", value: "v2.9.1" },
    { label: "tt-inference-server", value: "main@2aa7f72" },
  ],
};
