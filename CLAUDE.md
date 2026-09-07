# tt-quietbox2-guide

Interactive QB2 guide (Eleventy). Four tracks: `first-timer` (Explore), `ml-practitioner`
(Run & build), `builder-hacker` (Tinker), `tinkerer` (Customize).

## Repo shape

* `src/content/tracks/<track>/chapters/*.md` — chapter pages.
* `src/content/shared/*.md` — **shared chunks**, injected with `{% chunk "name" %}`.
  `lib/chunks.js` flattens blank lines out of rendered chunk HTML; a blank line inside a
  fenced block in a chunk otherwise terminates the HTML block and breaks the code block's
  copy-paste. `node --test` guards this — don't hand-edit around it.
* `scripts/vhs/*.tape` — VHS sources for the demo GIFs in `src/assets/video/`.
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
