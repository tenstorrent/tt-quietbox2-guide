# tt-quietbox2-guide

Interactive QB2 guide (Eleventy). Four tracks: `first-timer` (Explore), `ml-practitioner`
(Run & build), `builder-hacker` (Tinker), `tinkerer` (Customize).

## Repo shape

* `src/content/tracks/<track>/chapters/*.md` — chapter pages.
* `src/content/shared/*.md` — **shared chunks**, injected with `{% chunk "name" %}`.
  `lib/chunks.js` flattens blank lines out of rendered chunk HTML; a blank line inside a
  fenced block in a chunk otherwise terminates the HTML block and breaks the code block's
  copy-paste. `node --test` guards this — don't hand-edit around it.
* `demo/demos.yaml` + `demo/raw/*.tape` — `tt-demo` manifest and VHS sources for the demo
  GIFs in `src/assets/video/`. Every scene is currently a `raw_tape:` hatch: record with
  `tt-demo record <id>`, then `tt-demo verify <id>` and
  `tt-demo publish <id> --dir src/assets/video`.
* `agents.md` — the AI-assistant-facing guide, served at `/agents.md`. Also carries
  **handoff sections** for work that needs a QB2 (asset recording, etc.).
* `llms.txt` — machine-readable summary.
* Verify with `npx eleventy` + `node --test`, and grep `_site/` for leaked `:::` markers.

## Session log

### 2026-09-07 — environment-model correction sweep

**Prompt:** "The most recent merged PR had some findings that might have implications to
other lessons. Let's be proactive and fix what we can." Then: add an "Upgrade your stack
first" step for newcomers.

PR #17 fixed the *first-model chapter* against a shipping factory QB2. The findings applied
across the whole guide, so this was a sweep of all four tracks plus the reference files.

**The corrected model** (verified against `tt-installer`'s `install.m4` on the default
branch, the `ppa.tenstorrent.com` `Packages` index, and `tt-inference-server`'s
`release_model_spec.json` — not just PR #17's machine):

| Surface | Reality |
|---|---|
| TTNN / Direct API | **Only** inside the `tt-metalium` container (`/opt/venv/bin/python3`). `~/tt-metal` and `~/tt-metal/python_env` do not exist and the installer never creates them. |
| `~/.tenstorrent-venv` | `tt-smi`, `tt-flash`, `tt-topology` (opt-in) and deps. **Nothing else, ever.** No vLLM, no `ttnn`, no `huggingface_hub`. |
| Serving | `~/.local/lib/tt-inference-server/run.py`, wrapped as `~/.local/bin/tt-inference-server`. vLLM lives in its container. |
| Forge | `--install-forge-container` is **off by default** and is a container. The pip-wheel path is the TT-Forge docs' path and belongs in its own venv. |
| `hf` CLI | Not installed by anything. |
| PATH | `~/.local/bin` isn't on PATH in every shell; `install.m4` warns about this itself. |
| Meshes | `MESH_DEVICE=P300x2` / `--tt-device p300x2` (note the case difference). The **two-chip** mesh (`P300`) fails fabric bring-up on our hardware — use `P150` to go narrower. |
| Qwen3-0.6B | Absent from `release_model_spec.json` (0 of 177 IDs). Fine for TTNN; cannot be served by `run.py`. |

**Key decisions**

* `~/tt-metal/python_env` is **legacy everywhere**, not merely different on a factory box —
  so every live instruction was replaced rather than conditionalised. The remaining
  mentions are deliberately corrective ("if another guide says X, substitute Y").
* PR #17 and the then-open PR #18 contradicted each other on whether `~/.tenstorrent-venv`
  holds vLLM. `install.m4` settles it: PR #17 is right, and PR #18's box had a hand-built
  venv. The vLLM chapter's "Path 1" was reframed as something you deliberately set up,
  which preserves PR #18's hardware-verified content without keeping its false premise.
* Two things PR #17 got wrong were fixed: `brew install hf` on an Ubuntu box with no
  Homebrew, and "that venv is auto-activated in every shell" (tt-installer tells you to
  source it yourself — it's the *factory image's* `profile.d` that pre-activates it).
* GIFs were left stale on purpose: the `.tape` sources are corrected, and `agents.md` has a
  re-record checklist. Helper scripts moved `/tmp` → `$HOME`, since the container mounts
  only the home directory.
* Both illustrations were redrawn — `python-env-map.svg` was *structured* around two
  co-equal venvs, so relabelling wasn't enough.

**Upgrade-first step** added to `shared/install-stack.md` (with a nudge in first-timer ch1,
a recipe in `agents.md`, and a fact in `llms.txt`). The two non-obvious parts:

1. `tt-studio` and `tt-inference-server` are **git clones**, and the installer *skips a
   directory that already exists* — so re-running it never updates them. `git pull` both.
   This is why a box reports tt-studio 2.8.0 against docs describing 2.10.0.
2. Container images: the `tt-metalium` wrapper is a plain `docker run`, which pulls only
   when the image is absent, so it never refreshes. `docker pull` it.
   Order matters — installer first, then apt: the installer pins a golden baseline
   (`--versions=release`) and passes `--allow-downgrades`, so apt-upgrading past it and
   *then* re-running walks packages back. `--versions=rolling` opts out.

**Upstream follow-ups identified** (not this repo)

* `tsingletaryTT/tt-developer-image`'s `docker/Dockerfile.qb2` — the image the guide's GIFs
  are recorded in — reproduces the *old* model (`~/tt-metal/python_env`, a vLLM venv, an
  `hf` symlink), and `docker/scripts/qb2_smoke.sh` **asserts** those paths exist. That
  image is where the wrong mental model came from; it should assert the factory negatives
  instead, ideally seeded from a real box via `--export-schema` → `--versions=<state>.ttis`.
* `tt-vscode-toolkit` lessons carry a three-path activation block whose middle path is
  `source ~/.tenstorrent-venv/bin/activate` for TTNN/vLLM. Same wrong claim, ~7 lessons.

### 2026-09-07 — VHS → tt-demo migration; validation against corrected Dockerfile.qb2 pending

**Prompt:** "We updated ~/code/tt-develeper-image for QB2 testing closer to hardware
shipping status... We should test the whole book against this environment, using HW passed
to the docker container as needed. We should also update our VHS instructions to use
tt-demo-maker instead of one-off approach. re-record videos as needed"

Sequenced as: tooling migration first (no hardware), then a hardware-backed validation +
re-record pass (separate session, since it needs a full TTNN build + user presence for
tt-studio/coding-agent demos).

**Tooling migration (done this pass):**
* `scripts/vhs/*.tape` → `demo/raw/*.tape` (`git mv`, history preserved), `scripts/vhs/prompts/`
  → `demo/raw/prompts/`. Each tape's `Output` line repointed from `src/assets/video/<id>.gif`
  to `demo/assets/<id>.gif`.
* `demo/demos.yaml` scaffolded via `tt-demo init`; all 14 tapes registered as `raw_tape:`
  scenes (ids match the old filename stems) with a title + caption per scene.
* **Gap found and fixed upstream, not just documented.** Reading `tt-demo-maker`'s source
  (`bin/src/record.rs`) showed `tt-demo record` didn't yet execute raw-hatch scenes — it
  printed "raw scenes not yet CLI-captured (v1.1)" and skipped, a limitation the tool's own
  README/AGENTS already listed as deferred. Fixed there instead of working around it here:
  `record.rs` now runs `vhs <tape>` (or `asciinema rec ... --command "bash <script>"` for
  `raw_script`) for real, checks the tool is on PATH first, and reports whether the
  conventional `demo/assets/<id>.{gif,mp4}` path appeared afterward. Covered by a new
  hardware-free case in `tests/e2e_golden.sh`; all 34 Rust unit tests + the golden script
  pass. Shipped as `tt-demo-maker` `0.2.1` → `0.2.2`, committed and pushed to its `main`.
  So `tt-demo record <id>` now actually records qb2-guide's tapes — no `vhs` fallback needed.
* `agents.md`'s two handoff sections and this file's repo-shape bullet updated to the new
  paths and the `tt-demo record` → `verify` → `publish` pipeline.
* Verified: `tt-demo record --dry-run all` (manifest validates, 15 steps), `node --test`
  (14/14 pass), `npx eleventy` build clean, no leaked `:::` in `_site/`.

### 2026-09-07 (same day, continued) — Phase 2: hardware validation, two real bugs found and fixed

`tenstorrent/qb2-env:latest` (2026-06-21) predated `tt-developer-image`'s factory-layout fix,
so first rebuilt it there — which surfaced four unrelated bugs in that image/its CI script,
fixed and documented in `tt-developer-image`'s own CLAUDE.md rather than here (venv-activation
order breaking TTNN's compiled extension; a floating `vllm-tt-plugin` ref; a tt-metal commit
too old for any current vllm; a `build/` dir pre-create colliding with a newer tt-metal's
symlink step; a legacy path in `ci-qb2.sh`'s own hardware check). All four fixed, verified live
on all 4 chips, pushed to that repo's `main`. Also fixed there: `tt-toplike`'s install step
still assumed no apt PPA existed — it does now, confirmed live.

**Walkthrough approach**: rather than only testing inside the rebuilt custom image, also
tested directly against the **real, official** `ghcr.io/tenstorrent/tt-metal/tt-metalium-*`
container (already pulled on this box) and the bare-metal `tt-smi`/apt/dmesg surface — more
authoritative than our own approximation for anything that container or the host actually
owns. This is how both bugs below were found.

**Two real bugs found in the guide's own content, both in `builder-hacker/02-first-kernel.md`
and (torch only) two other chapters — confirmed against the real Metalium container, not
assumed:**

1. **No `ttnn_add_tensors.py` tutorial ships in the container.** The chapter claimed one did,
   with a `find /` fallback "if that path doesn't resolve." `find /` on the real container
   returns nothing — there is no tutorials directory anywhere in this image at all (it's a
   compiled-wheel runtime image, not a source checkout). Fixed: the chapter now has the reader
   write the ~15-line script themselves into `~/tt-scratchpad/` — the file was already printed
   in full right below the broken claim, so this is a smaller diff than it sounds.
2. **`torch` isn't installed in the container, and there's no `pip` to install it with**
   (confirmed: `ModuleNotFoundError: No module named 'torch'`; only `uv` and `ensurepip` are
   present). Every code sample doing `ttnn.from_torch`/`to_torch` was broken as written. Fixed
   in `02-first-kernel.md` (added the bootstrap step, verified live:
   `uv pip install --python /opt/venv/bin/python3 torch --index-url
   https://download.pytorch.org/whl/cpu` — the CPU wheel specifically, since the default index
   pulls an unnecessary multi-GB CUDA build) and added a one-line pointer to the same fix in
   `01-tt-metal-architecture.md` and `ml-practitioner/01-coming-from-cuda.md`, whose code
   samples have the same gap but don't instruct the reader to actually run them right there.

**Verified accurate, no changes needed**: Chapter 3 (`is-this-thing-on`) — every `tt-smi -s`
JSON field path, type, and even the exact `dmesg` permission-error text matched real output.
Same for the LED chapter's `telemetry.*`/`firmwares.fw_bundle_version` field paths (one stale
version number de-pinned: `tt-smi --version` instead of a hardcoded "v6.1.0"). The core
device-open/close handshake and full `ttnn.add` round-trip in `run-first-model.md` both ran
clean on real hardware. `tt-toplike`'s apt-install path is genuinely correct now.

**Not done yet**: the remaining tracks (ml-practitioner beyond ch1, tinkerer 03-05,
builder-hacker 03-06) weren't walked with the same hardware-verification depth — time was
spent chasing the `tt-developer-image` bugs blocking a rebuilt image at all. Re-recording the
known-stale GIFs (`agents.md`'s list: 03, 04, 04b, 05, 09, 11, plus 12's port fix, plus
never-recorded 13/14) through the `tt-demo` pipeline is also still open — that needs you
present for the tt-studio/browser/coding-agent parts.

**Committed**: everything above pushed to PR #19 (`fixes/2026-09-07`) — the user asked to
commit and contribute to the existing PR rather than open a new one.

### 2026-09-07 (continued) — Phase 2 resumed, two more real bugs found

Kept walking chapters against real hardware after the commit above.

1. **`ml-practitioner/04-performance-tuning.md`'s `tt-smi` polling script would crash
   outright.** It read `d["device_id"]` (no such field anywhere in `tt-smi -s` output) and
   `d["asic_temperature"]`/`d["power"]`/`d["aiclk"]` as flat fields — chapter 3 already
   established these live under `telemetry`, and this script contradicted its own guide.
   The triple-nested quoting (`watch -n 2 '... python3 -c "..."'`) was also fragile enough
   that fixing it in place would've made a bad problem worse — replaced with a small script
   saved to `~/tt-scratchpad/`, tested against real `tt-smi -s` output.
2. **`builder-hacker/04-profiling.md`'s TTNN profiler example runs clean but never shows
   real data on a stock QB2.** `ttnn.profiler.get_all_programs_perf_data()` (the API name
   itself is correct — verified against the real container's `dir()`) returns an empty
   `{}` after a real dispatched matmul, and trying to force real collection with
   `TT_METAL_DEVICE_PROFILER=1` crashes outright: `TT_FATAL: TT_METAL_DEVICE_PROFILER
   requires a Tracy-enabled build of tt-metal` — confirmed live, twice. The stock
   `tt-metalium` release image isn't Tracy-enabled; that's a from-source-build topic.
   Added an accurate callout plus a working alternative (wall-clock timing via
   `ttnn.synchronize_device` before/after — also verified live, including that
   `synchronize_device` itself exists and a real matmul times cleanly through it).

Both fixes verified end-to-end against real hardware before writing them into the guide,
not just reasoned about. Build clean, tests pass. Committed and pushed to PR #19.

### Also this session: upstream contribution to `tt-vscode-toolkit`#52

That PR's own "Verification" section said every claim came from reading upstream source,
never a QB2 run. Validated the checkable ones for real on this same hardware (venv
contents via a fresh `tt-installer` run's own smoke assertions, `tt-metalium -c '...'`
argument-passing, Forge's off-by-default flag straight from `install.m4`, the
`tt-inference-server` wrapper's `cd` behavior, the 4-chip ring-mesh fabric adjacency) and
found two bugs its own review missed: the same "`TT_METAL_HOME` is pre-set" and
"bundled tutorial file" claims fixed here in `first-kernel.md`, plus three of four
`tt-metalium "..."` examples in `tt-installer.md` missing `-c` (so `bash` tries to run the
whole string as a filename and fails before Python ever runs) and every
`ttnn.__version__` reference there being liable to crash with `AttributeError` (that
attribute doesn't exist on the built package — confirmed on two separate images). Fixed
and pushed to that PR's branch directly (`fix/qb2-venv-activation-claims`); all four of
that repo's own pre-commit checks still pass.
