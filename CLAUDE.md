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

### 2026-09-07 (continued) — Phase 2 finished: remaining tracks walked, PR #19/#20 merged, #18 closed

PR #19 merged to `main`. Josh Zheng's PR #18 (vLLM chapter fixes) predated #19 and was based
on the stale pre-correction file; reshaped it down to its non-overlapping findings as PR #20
(cherry-picked his commit, kept his authorship, dropped what #19 already had — two-chip mesh
warning, `enable_thinking`, port 8000 guidance, "When Startup Stalls" were all already
present). Two rounds of Copilot review on #20 addressed (each verified against reality, not
applied blindly) — a leftover `Llama-3.1-8B-Instruct` reference after Path 1 changed to
Qwen3-0.6B, and a Qwen3-only `enable_thinking` flag applied unconditionally to Llama examples.
#20 merged, #18 closed with a comment crediting the findings that landed.

Then resumed the Phase 2 walkthrough for every chapter not yet covered:
`ml-practitioner` 02/05/06, `builder-hacker` 03/05/06, `tinkerer` 02-05. Real bugs found, all
confirmed live before fixing (see PR #21):

* **model-zoo.md**: Qwen3-0.6B shown sharded 2 ways in the storage-layout example; a real
  download is single-file. Same flat `enable_thinking` key bug as the vLLM chapter, in the
  canonical "Qwen3 Reasoning Modes" section this guide cross-links from everywhere else.
* **tt-forge.md**: the ResNet-50 example needs `torchvision`, which nothing installs — and a
  naive `pip install torchvision` silently upgrades `torch` itself and breaks `torch_xla`
  (confirmed live: `undefined symbol` crash). Fixed with a `--no-deps` pinned install. Also:
  stale 4-chip fabric state from an unclean exit (same failure/fix as vLLM's note), a wrong
  `tt-forge-models` directory diagram (bert/dinov2/llama all nest a task-type directory it
  omitted — the worked import 404s), `ModelLoader.load_model()` called as if static when it's
  an instance method (confirmed: `TypeError: missing 1 required positional argument: 'self'`),
  and two wrong Compiletron CLI facts (`--auto-quit` is a post-summary countdown in seconds,
  not a model count; the real default backend is `auto` with a `mixed` mode, not `forge`).
* **tt-forge-compiler.md**: the same static-vs-instance bug in its own BEiT example, plus two
  more layered API bugs found going deeper — `variant` is a constructor argument, not a
  `load_model()` keyword, and `ModelVariant` is a separate top-level import
  (`from .loader import ModelLoader, ModelVariant`), not `ModelLoader.ModelVariant` (confirmed
  live: `AttributeError`). Verified the fully-corrected pattern end-to-end — loads a real
  ResNet-50, returns real tensors.
* **ttlang-intro.md / 05-going-deep.md — the big one**: the entire TT-Lang code example was a
  fictional API (`from ttlang import kernel, reader, compute, writer, Tile, Buffer`, four
  decorators, bare `push()`/`pop()`). None of it exists. The real, installed package is `ttl`
  (importable from `~/.tenstorrent-venv`), with `@ttl.operation`, only two function decorators
  (`@ttl.compute()`/`@ttl.datamovement()` — no separate reader/writer), `DataflowBuffer`s via
  `ttl.make_dataflow_buffer_like()`, transfers via `ttl.copy(...).wait()` — cross-checked
  against tt-vscode-toolkit's actively-maintained `tt-lang-intro` lesson, which already uses
  this real API. Replaced the guide's example with the lesson's real, working elementwise-add
  kernel; fixed every decorator reference in both files.
* **break-and-fix.md**: the driver-module existence check looked under
  `/lib/modules/$(uname -r)/extra/`; confirmed live the real path is `updates/dkms/`.

`tinkerer` 02/03/05 (tt-toplike/compiletron flags, package/extension names, standard Ubuntu
tooling) checked out against real source and this box's actual installs — no changes needed.
Every chapter across all four tracks has now been walked against real hardware or the actual
installed packages at least once. Build clean, tests pass throughout. Pushed as PR #21.

### 2026-09-17 — the pre-cached Qwen3-32B: teach the shortcut, on the branch `use_that_model`

**Prompt:** "The first inference lesson in here could also give you a short cut to serving
that qwen model with tt-inference-server the first time that already ships with the box.
it's locked away in a non-standard directory, but we could teach how to make any tool aware
of it right here and skip having to download any other model." Then: "really explain why
this is a good idea to people."

New shared chunk `shared/precached-model.md`, injected into `first-timer/05` (ahead of its
first serving section) and `ml-practitioner/03` (inside Path 2).

**What the directory actually is.** `~/data/tt-cache` is **tt-inference-server's
`persistent_volume_root`**, not a Hugging Face cache — `volume_id_<impl>-<model>-v<version>/`
containing `weights/`, `tt_metal_cache/`, `logs/`, `model_file_symlinks_map/`. So
`--host-hf-cache` (resolves `HOST_HF_HOME` → `HF_HOME` → `~/.cache/huggingface`) is the wrong
lever and silently re-downloads 62 GB. `--host-weights-dir` is the right one. Both places the
guide recommended `--host-hf-cache` for reusing shipped weights were wrong; both fixed.

**Verified against the pristine image, which overturned a wrong conclusion.** On the *host*
QB2 the weights are hardlinked (`links=2`, matching inode 115122987) into
`~/.cache/huggingface/hub/models--Qwen--Qwen3-32B`, which made it look as though the model
ships pre-registered in the HF cache and needs no setup at all. Mounting
`tt-qb2-one-accelerator-pristine.qcow2` read-only (`qemu-nbd --read-only`) showed
`links=1`, **no `~/.cache/huggingface` and no `~/models`** on the shipping image. The
hardlinks are an artifact of this host's own later `hf download` work. Had we written from
the host alone, the chapter would have told readers `Qwen/Qwen3-32B` resolves natively.
Textbook "trust the subject, verify the instrument."

**The version trap, verified live.** `run.py` computes the volume name it expects rather than
scanning; the version comes from the **model spec entry for model+device**
(`workflows/model_specs/prod/llm.yaml` — four `Qwen3-32B` entries; `tt_transformers`/`P300X2`
is `0.17.0`), while the box ships `-vqb2_launch`. Confirmed by running
`--print-docker-cmd --skip-system-sw-validation`, which printed
`src=.../volume_id_tt_transformers-Qwen3-32B-v0.17.0` and
`TT_CACHE_PATH=.../cache_Qwen3-32B/P300x2`. The host already carried an undocumented
`-v0.17.0 -> -vqb2_launch` symlink working around exactly this. Taught as a deep-dive, with
`--host-weights-dir` as the recommended default because it is version-independent. An earlier
draft invented a `workflows.utils.get_version()` helper — it does not exist; caught and
replaced with the verified `--print-docker-cmd` method before it shipped.

**Why-it-matters framing** (the explicit ask): the weights are ~62 GB and re-downloadable,
but the ~30 GB `tt_metal_cache` is **not** — it is compiled against your mesh and is what
makes a first deploy minutes instead of a compile. Downloading the model again pays twice and
still throws away the more valuable half.

**Deliberately not in the guide:** the pristine VM's copy of Qwen3-32B is 2.85 GB short
(`model.safetensors.index.json` declares 65,524,246,528; shards sum to 62,671,934,640 — shards
2/6/10 truncated; the host's copy passes the same check). Corroborated independently by the
guest's `du` reading 88G against the host's 91G, so it is not a `noload` mount artifact. Per
the user this is most likely `tt-qb2-image-maker`'s own construction process rather than the
shipping ISO, so it is reported there, not written up here as an image defect. The guide keeps
only a light `du -sh ~/data/tt-cache/` confirmation step — which is Tenstorrent's own ISO
acceptance check.

**Guest access, for next time:** the QB2 factory image has **no sshd and no serial getty**
(probed `/dev/pts/4`: zero bytes), the guest agent is disconnected, and networking is macvtap
so host↔guest doesn't work. The running VM is SPICE-only. The pristine qcow2 mounted
read-only is the practical non-interactive channel.

Verified: `npx eleventy` clean, `node --test` 14/14, no leaked `:::` in `_site/`, code blocks
intact through the chunk pipeline. `agents.md` and `llms.txt` updated with the path, the flag
choice, and a troubleshooting row for the re-download failure mode.

**Split after review** ("I think this may make things more confusing"). The single chunk was
174 lines dropped into a 138-line first-timer chapter — it more than doubled "Your First
Model" with the most technical material in that track, and `deep-dive` callouts don't
collapse. Now two chunks: `precached-model` (73 lines — why it matters, the `du` check, the
symlink, one `--host-weights-dir` command, and the `--host-hf-cache` warning) in both tracks,
and `precached-model-deep` (83 lines — the persistent-volume tree, `model_file_symlinks_map`,
and the version-trap deep-dive) in `ml-practitioner/03` only.

Also fixed an injection bug this surfaced: the chunk emits an `##`, so injecting it mid-Path-2
made Path 2's own "three more flags" tip fall under the new heading. Both chunks now go in at
the end of Path 2, immediately before `## Verifying the Server`. Rendered heading order
checked, not assumed.

**Copilot review on #23, all verified before acting.** Five accepted: (1) ch03's "full command
combining them" paired `--model Qwen3-32B` with `--host-hf-cache` directly under new prose
saying that pairing is wrong — switched the example to `Llama-3.1-8B-Instruct`, which is what
`--host-hf-cache` is actually for; (2) `llms.txt` bullet ended mid-sentence; (3) "Before you
download anything" was false in the first-timer slot, where `run-first-model` has already had
the reader pull Qwen3-0.6B — now "another model"; (4) the deep-dive showed a runnable
`--host-volume` *before* the alias workaround, i.e. the 62 GB failure the section exists to
prevent — resequenced into Step 1 dry-run → Step 2 alias → Step 3 launch, with only the safe
`--print-docker-cmd` appearing pre-alias; (5) the short chunk's command omitted `HF_TOKEN`.

(5) turned up a second bug in existing content. `run.py:858` sets
`huggingface_required = ... or runtime_config.docker_server`, and `setup_host.py:551` asserts
plus *validates* the token — so `--docker-server` requires `HF_TOKEN` regardless of
`--host-weights-dir`. But the guide's stated reason was wrong: `run-first-model` claimed
Qwen3-32B "is gated even though the weights are local". It is Apache-2.0 and ungated
(checked on its model card). Fixed the claim and documented the real reason — a `run.py`
workflow precondition, not a license gate.

One rejected: Copilot said the chunk needs a container→host transition because
`run-first-model` leaves the reader inside `tt-metalium`. It doesn't — line 78 of that chunk
already says "run this on the host, not inside `tt-metalium`" for the download step that
immediately precedes this one.

Separately added: a warn callout at the top of first-timer/05's "Serving a Model with vLLM",
since the new chunk put a runnable server path directly above an existing one that launches a
different model on the same chips and port.

**Second Copilot round — one comment, which cascaded.** It noted my new callout said to
substitute `Qwen3-32B` while the curl below used `meta-llama/Llama-3.1-8B-Instruct`, so a
name-only swap yields `meta-llama/Qwen3-32B` and a 404. Checking *which* id is right proved
the guide had this backwards. `run_docker_server.py:583` does
`docker_command.extend(["--model", model_spec.hf_model_repo])`, and the container entrypoint
(`/home/container_app_user/app/src/run_vllm_api_server.py`, read out of the 0.17.0 image) has
**zero** `served_model_name` references. So Path 2 serves under the **full HF repo id**, not
the short `--model` name: `meta-llama/Llama-3.1-8B-Instruct`, `Qwen/Qwen3-32B`.

That falsified ch03's 404 callout, which claimed "Path 2 reports the model as you named it in
`--model`". Corrected, along with its three examples (one curl, two SDK). The chunk now states
the served id too, since that is the practical payoff. Verified from source and the image
entrypoint, not from a live `/v1/models` response — that needs a real deploy.

**Then folded in**, on request, after checking each file's serving path rather than sweeping:

* `llama-70b.md` (4) — Path 2 throughout, and its own callout at line 188 already said the
  container "takes the fully-qualified HuggingFace ID" while its client examples used the short
  one. Now `meta-llama/Llama-3.3-70B-Instruct` ×3 and
  `deepseek-ai/DeepSeek-R1-Distill-Llama-70B` ×1.
* `tinkerer/02-fun-demos.md` (1) — Path 2 (`run.py --docker-server`), so its curl would 404.
* `model-zoo.md` (2) — the canonical Qwen3 reasoning-modes snippets ch03 cross-links to;
  now `Qwen/Qwen3-32B`.
* `tt-studio-coding-agents.md` (1) — **left alone, correctly.** That is the LiteLLM gateway on
  :4000, which has its own naming (`tt-studio/Qwen3-32B`, `Qwen3-32B-thinking`), not the vLLM
  OpenAI surface on :8000.

Repo ids taken from `prod/llm.yaml`'s `weights:` entries, not guessed. Replacement was scoped
by regex to client payloads (`"model": "…"`, `model="…"`) so that `run.py --model <short>`,
which correctly takes the short name, was never touched.

**Holistic pass (prompted: "do these truly serve the audience or are we still providing too
much information?").** Measured every chapter against the time budget declared in
`personas.json`. `ml-practitioner/03` was **31 min against a 10 min budget** — the worst page
in the guide by a wide margin, and ~25 min of that predated this PR. `first-timer/05` was 14
against 8. The three review comments in the last Copilot round (HF_TOKEN ordering, Step 3 as a
second launch, the chunk's launch following Path 2's) were all one structural defect: mutually
exclusive runnable paths stacked inside a linear walkthrough, which is what happens when
reference material is crammed into a tutorial.

Restructured rather than reworded:

* New `src/_includes/layouts/lesson.njk` — shared chrome for standalone lessons, driven by
  front matter, so a lesson no longer inlines its own `<style>` block the way
  `llama-70b.md` does. (That file was left on its inline copy; migrating it is a follow-up.)
* New **`/lessons/build-your-own-vllm/`** ← ch03's "Path 1: Direct vLLM" (4.4 min) plus
  "Running the latest vLLM plugin" (6.3 min). These were always one topic: Path 1 opened by
  telling you to go read the plugin section first. The `09-vllm-demo` GIF moved with them —
  it shows venv activation and `vllm serve`, which is now lesson content.
* New **`/lessons/weights-caches-volumes/`** ← the `precached-model-deep` chunk, which is
  deleted. The volume tree, `model_file_symlinks_map`, the version trap, `--host-volume`.
* ch03 now has one path, not two. "Path 2" became "Serving with tt-inference-server"; the
  two-chip fabric warning moved out of the departed Path 1 into Multi-Chip (it is referenced
  there); the `MESH_DEVICE` name reference went to the lesson. **31 min → 18 min.**
* Declared times corrected to measured reality: ch03 10→18, first-timer/05 8→14.

Review fixes folded in: `HF_TOKEN` now exported *before* the Step 1 dry run (it is validated
whenever `--docker-server` is passed — my earlier verification passed only because this host's
`.env` already had a token, a textbook contaminated instrument), and both the chunk's launch
and the lesson's Step 3 now carry explicit "this replaces the command near it, stop the other
server first" warnings.

**Still over budget and deliberately so:** ch03 at 18 min. Closing the last 8 would mean
cutting the API/verification material that is the chapter's actual job. Other chapters remain
optimistic too (`first-timer/04` 13 vs 10, `ml/01` 12 vs 8, `tinkerer/01` 12 vs 6,
`tinkerer/04` 14 vs 10) — a guide-wide estimate audit is a separate piece of work.

**Fifth review round — 11 comments, most of them my own extraction debt.** Moving Path 1 +
the plugin section into a lesson was done structurally without re-editing the transplanted
prose, so it arrived carrying chapter-relative references. The root defect: the lesson's intro
promised "build the environment first, then serve" while its sections ran serve-then-build,
which generated several of the comments on its own. Rewritten into real order —
1. see what's on the box, 2. get a Python `ttnn`, 3. install the plugin, 4. serve — and the
two near-duplicate serving blocks merged into one, which removes the same-chips/same-port
conflict the reviewer flagged.

Specific carry-over damage, all fixed: "mesh caveat from Path 1" (section no longer exists);
"the vLLM your QB2 shipped with" ×2 (false — the shipped vLLM is inside the managed container,
as the lesson's own intro says); "P300x2 is for the 70B example further down" (that example
stayed in ch03); "Before installing, it is worth knowing what is on the box" appearing *after*
installation; a **duplicated `09-vllm-demo.gif`** and a stale **"Next: Performance Tuning"**
chapter footer — both swept in because the last section's extraction ran to end-of-file. The
reviewer caught the duplicate GIF; the stale footer I found while fixing it.

The substantive gap it also exposed: the lesson is called "Build Your Own vLLM Environment"
and never said how to create the venv it activates on line one. Checked PyPI from the box —
`ttnn` **is** Tenstorrent-published (`info@tenstorrent.com`, 0.78.0, manylinux x86_64 wheels
for cp310/cp312, so it matches Ubuntu 24.04's `python3`). Added the `python3 -m venv` +
`pip install ttnn` route with an explicit `import ttnn` gate, and said plainly that provenance
and wheel compatibility are verified while end-to-end function on a QB2 is **not** — if the
import fails, take the derived-container route.

Also fixed: `run.py --docker-server` needs `HF_TOKEN` before ch03's *first* managed launch too,
not only the pre-cached one; the weights lesson's alias hardcoded `v0.17.0` while Step 1 says
the name varies (now copied from the `src=` path Step 1 prints); first-timer/05 conflated the
two substitutions (`--model` takes `Qwen3-32B`, the API `"model"` field takes
`Qwen/Qwen3-32B`); and `agents.md` now carries the token prerequisite and the id distinction
next to the flag guidance.
