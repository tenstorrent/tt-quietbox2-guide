# QB2 AI Assistant Guide

This file is for AI assistants helping users with a Tenstorrent Quietbox 2.

## What You Can Help With

### Start with `tt`
`tt` is the Tenstorrent CLI and the front door for almost everything. `tt device status`
(hardware), `tt update` (install/upgrade), `tt model list|info|pull|ps|logs|stop|curl`, `tt serve`,
`tt launch`. If `tt: command not found`, `~/.local/bin` is not on PATH
(`uv tool update-shell` or `export PATH="$HOME/.local/bin:$PATH"`). Always preview with
`--dry-run` (`tt update --dry-run`, `tt serve <model> --dry-run`, `tt launch <client> --dry-run`).
The PyPI package is `tenstorrent`; `tt-cli` on PyPI is an unrelated time tracker.

### Hardware Verification
Run `tt device status` (table, `--json` for scripts) and `tt device info` (firmware, board ids).
- Healthy: 4 rows, all `board_type` `p300c`, `DRAM True`. A clock near 1.3 GHz and tens of watts
  means the chip is in use; 800 MHz means idle.
- `tt-smi -s` is the lower-level JSON snapshot (`board_info`, `telemetry`, `firmwares` nested).
- Missing device: `sudo dmesg | grep -i tenstorrent` for PCIe errors, then reboot if `tt update`
  just installed the driver.
- Temperature normal range: 35–55°C idle, up to 85°C under load

### Model Running (the happy path)
1. `tt update --dry-run`, then `tt update` (sudo; asks before flashing firmware; reboot after a
   first install). `tt self update` upgrades `tt` itself.
2. `tt model login` (or `hf auth login`, or `HF_TOKEN`): serving needs a Hugging Face token.
3. `tt serve Qwen3-32B` — the model the QB2 ships with. Default port **20000** (`--port` to
   change). Returns only when the endpoint answers. The served model id is the full HF id
   (`Qwen/Qwen3-32B`).
4. `tt model curl "prompt" --max-tokens 2048`, `tt model ps`, `tt model logs`, `tt model stop`.
5. `tt launch list`, then `tt launch openwebui` or a coding agent (`opencode`, `pi`, `aider`,
   `qwencode`, `hermes`). TT-Studio is `tt serve <model> --studio`, not a launch client.

**Pre-seeded Qwen3-32B.** `~/data/tt-cache/volume_id_tt_transformers-Qwen3-32B-vqb2_launch/`
holds the shipped weights and compiled kernels (tt-inference-server's persistent-volume layout,
not a Hugging Face cache). `tt serve` reuses it only when a directory named exactly
`volume_id_<impl>-<model>-v<version>` exists, where the version comes from the model spec
(`0.17.0` for Qwen3-32B on p300x2 at golden v3.0.0). Check with
`tt serve Qwen3-32B --dry-run`: the `weights` row must say `pre-seeded volume`. If it says
`~/.cache/huggingface`, create the alias:
`ln -s ~/data/tt-cache/volume_id_tt_transformers-Qwen3-32B-vqb2_launch ~/data/tt-cache/volume_id_tt_transformers-Qwen3-32B-v0.17.0`
(tested: without the link `tt` falls back to the HF cache and would re-download 62 GB). Details
in the guide's Ch5 callout and `/lessons/weights-caches-volumes/`.

Models for a QB2 (`p300x2`) marked COMPLETE in the catalog: `Qwen3.8-27B`, `gemma-4-31B-it`,
`gemma-4-12B-it`, `FLUX.1-dev`, `FLUX.1-schnell`, `whisper-large-v3`, `distil-large-v3`,
`Wan2.2-T2V-A14B-Diffusers`. `Qwen3-32B`, `Llama-3.1-8B-Instruct`, `Llama-3.3-70B-Instruct` are
FUNCTIONAL. Always confirm with `tt model list` / `tt model info`. Community bundles
(`namespace/name`, served by tt-model-manager) come from `tt model search` and
`tt model list --community`. They are not reviewed or tested by Tenstorrent: tell users to
serve them at their own risk. Browse them at https://docs.tenstorrent.com/tt-awesome/models/.

Recommended first model **for the direct TTNN path**: `Qwen/Qwen3-0.6B` (~1.5GB, no license
gate, one chip). **Cannot be served via `tt-inference-server`** — it is absent from
`release_model_spec.json`.

Symlink rules that bite in containers (tested): `tt-metalium` mounts `$HOME` at `/home/user`.
Relative links inside home resolve; absolute links and links leaving home dangle. A Hugging Face
cache whose `snapshots/` files link to a shared blob store outside the model directory fails
inside the serving container with `FileNotFoundError` even though the host can read it.

Shared boxes: `tt serve` maps every `/dev/tenstorrent` node into the container, so it cannot be
pinned to two chips. `run.py --device-id 2,3` can (from the pinned checkout under
`~/.local/share/tenstorrent/tools/tt-inference-server-<ver>/src`, with `MODEL_SOURCE=huggingface`
and `JWT_SECRET=unused` set so it does not prompt). Take a `gozer` lease first.

TTNN environment: run `tt-metalium` (container wrapper in `~/.local/bin`). There is no
`~/tt-metal` checkout on a factory QB2; inside the container TTNN is already on the
default `python3` (`/opt/venv/bin/python3`) — nothing to activate.

vLLM: not installed on the host. `~/.tenstorrent-venv` holds only `tt-smi` / `tt-flash`.
`tt` keeps its own pinned tt-inference-server under `~/.local/share/tenstorrent/tools/`; the
`~/.local/lib/tt-inference-server` checkout from an older tt-installer run is not used by `tt` and
may be far older (v0.10.0 vs v0.25.0 on the test box).

### Coding Agents — Claude Code / OpenCode (tt-studio v2.8.0+)
tt-studio can serve a deployed model to a coding agent via a built-in LiteLLM
gateway on **port 4000** — no cloud, runs on the QB2's own chips.
- Anthropic surface: `http://localhost:4000` (Claude Code)
- OpenAI surface: `http://localhost:4000/v1` (OpenCode / any OpenAI client)
- Eligible models (need native tool-calling): `Qwen3-32B`, `Llama-3.1-8B-Instruct`,
  `Llama-3.3-70B-Instruct`. For speed, the community coder bundles
  `raahemnabeel/qwen3-coder-30b-a3b` (80 tok/s on one P300 board, measured 2026-10-30)
  and `raahemnabeel/qwen3-coder-next` (107 tok/s), both `qwen3_coder` parser, no thinking
  mode; `tt serve <bundle> --profile p300x2 --port 8000`. `tt launch` warns
  `not in the model catalog` for any bundle; that is expected, the parser is in the bundle. Reasoning models also expose a `-thinking` variant; the
  plain name deploys with `enable_thinking=false` (the gateway injects
  `chat_template_kwargs`), so agents get clean, reliable tool calls (verified 10/10).
- **Agentic tool calling + thinking don't mix yet.** With thinking ON, Qwen3-32B on the
  current tt-inference-server intermittently drops tool calls and leaks `</think>` into
  streamed content (tt-inference-server [#4386](https://github.com/tenstorrent/tt-inference-server/issues/4386);
  fix pending tt-metal [#48458](https://github.com/tenstorrent/tt-metal/issues/48458) landing in a
  prod image). The plain `Qwen3-32B` avoids this because thinking is off — so point
  Claude Code / OpenCode at the **plain** name, not `-thinking`. Only `tool_choice:"auto"`
  works; `none`/`required` are unsupported in the TT vLLM fork.
- Gateway key = `LITELLM_MASTER_KEY` (auto-generated by `run.py`; shown live on
  the Coding Agents page). Claude Code: set `ANTHROPIC_BASE_URL`,
  `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_MODEL`, `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1`,
  then run `claude`. OpenCode: add a `tt-studio` provider to
  `~/.config/opencode/opencode.json`, then `opencode --model tt-studio/<model>`.
- Beyond tt-studio's gateway: [`tt-warp`](https://github.com/tenstorrent/tt-warp) is a
  Warp/Claude-Code plugin for pointing local-first agent forks straight at TT hardware, and
  [`tsingletaryTT/tt-agents`](https://github.com/tsingletaryTT/tt-agents) is a public demo repo
  with six local-agent demos running on a QB2.

### Media Generation (tt-studio v2.8.0+)
tt-studio now also serves **WAN** (text-to-video) and **Flux** (image generation),
deployed from the same Deploy Model dropdown as the language models.

### Upgrading a QB2 (suggest this early — users rarely think of it)
A box that has been sitting is behind on driver, firmware, tooling and container images, and
"behind" presents as broken hardware or a broken tutorial.
1. `tt update --dry-run` shows what would change against the golden set (driver, firmware,
   HugePages, tt-smi, tt-flash, tt-inference-server, tt-studio). `optional` rows are fetched on
   first use (`--include-lazy` to fetch now).
2. `tt update` — sudo, runs tt-installer at the matching release, asks before flashing firmware.
   Plain `tt update` (no `--force`, no version argument) flashes a device only when its firmware is
   older than the golden bundle, so it will not downgrade. Run it on the machine itself, not
   inside a `docker run` shell (it reloads the kernel driver and may install Docker via systemd).
   Stop served models first. Reboot after a first install.
3. `tt self update --check`, then `tt self update` — upgrades `tt` itself (separate from step 2).

`tt update` ignores and warns about older `~/.local/lib/tt-inference-server` and
`~/.local/lib/tt-studio` checkouts left by a plain tt-installer run. The manual route (installer,
then apt, then git pulls, then `docker pull` of the `tt-metalium` image, in that order, because the
installer pins a golden baseline and passes `--allow-downgrades`) is documented in the guide's
`/lessons/tt-installer-by-hand/`.

### Install Troubleshooting
- apt says the Tenstorrent repository "is not signed" / `NO_PUBKEY`: the signing key is
  missing from `/etc/apt/keyrings/tt-pkg-key.asc`. Fix:
  `sudo mkdir -p /etc/apt/keyrings && sudo curl -fsSL -o /etc/apt/keyrings/tt-pkg-key.asc https://ppa.tenstorrent.com/tt-pkg-key.asc && sudo apt-get update`.
  The repository line in `/etc/apt/sources.list.d/tenstorrent.list` must reference that exact
  path via `signed-by=`. Nothing from Tenstorrent installs via apt until the key is present.
- Driver not loaded: `sudo modprobe tenstorrent` or check `lsmod | grep tenstorrent`
- PCIe AER errors: BIOS must have PCIe AER set to "OS First" (pre-set on QB2, check if BIOS was reset)
- Firmware mismatch: use `tt-flash` from https://github.com/tenstorrent/tt-flash

### Common Issues
| Symptom | Check | Fix |
|---------|-------|-----|
| `tt device status` shows <4 devices | `dmesg | grep tenstorrent` | Reseat PCIe card or reflash firmware |
| `DispatchCoreAxis.ROW` error | Code uses wrong dispatch config | Use `ttnn.DispatchCoreConfig(ttnn.DispatchCoreType.WORKER)` |
| `~/tt-metal` not found | Expected — nothing creates it | Not a fault. TT-Metalium is a container; run `tt-metalium`. Only clone https://github.com/tenstorrent/tt-metal for a from-source build |
| `import ttnn` fails on the host | Wrong interpreter — TTNN only exists inside the container | Run `tt-metalium` first, then `python3` (`/opt/venv/bin/python3`) |
| `import vllm` fails in `~/.tenstorrent-venv` | Expected — it was never installed there | That venv holds tt-smi/tt-flash only. Serve via `tt-inference-server`'s `run.py` |
| `tt serve <bundle>` says `no serve profile named 'p300'` though the card lists it | The installed bundle is an older revision | `tt serve <bundle> --profile p300 -- --refresh` fetches the current one; `--device-id 2,3` also passes through `--` to tt-model |
| `run.py` re-downloads a model the box already has | `--host-hf-cache` used for the shipped weights, or `--host-volume` hitting the volume-name mismatch | Use `--host-weights-dir ~/models/Qwen3-32B`. For `--host-volume`, `run.py` computes `volume_id_<impl>-<model>-v<model_spec version>` (`v0.17.0` for Qwen3-32B/p300x2) but the box ships `-vqb2_launch`; confirm with `--print-docker-cmd --skip-system-sw-validation` and symlink the expected name to the shipped one |
| `hf: command not found` | `huggingface_hub` is not part of the stack | Install it outside `~/.tenstorrent-venv` (e.g. `uv tool install huggingface_hub`) |
| `tt-studio` / `tt-metalium` / `tt-forge`: command not found | `~/.local/bin` not on PATH (zsh never reads `~/.profile`) | `export PATH="$HOME/.local/bin:$PATH"`, and add it to `~/.zshrc`. tt-installer warns about this at install time |
| `apt` refuses Tenstorrent packages | `cat /etc/apt/keyrings/tt-pkg-key.asc` | Re-download the key to `/etc/apt/keyrings/tt-pkg-key.asc` from `https://ppa.tenstorrent.com/tt-pkg-key.asc`, then `sudo apt-get update` |
| `tt --help` doesn't show `device`/`model`/`serve`/`update` | `which -a tt` | Something else on `PATH` answers to `tt` first — `tt` is a short name and more than one tool has claimed it. Non-login shells skip `~/.profile`, so `~/.local/bin` (where `uv tool install tenstorrent` puts `tt-cli`'s shim) never gets ahead of whatever else is on `PATH`. Use a login shell (`bash -l`) or `export PATH="$HOME/.local/bin:$PATH"`; don't uninstall the other tool, that doesn't fix PATH order |

## Content Map by Task

| User wants to... | Send them to |
|-----------------|-------------|
| Verify hardware works | Explore Ch3: Is This Thing On? (`tt device status`) |
| Install or upgrade the stack | Explore Ch4: Install and Upgrade with tt |
| Fix an apt/repository signing error | Customize: Breaking & Fixing Things (pattern 9) |
| Serve first model | Explore Ch5: Serve a Model |
| Connect a chat UI or coding agent | Explore Ch6: Launch Software |
| Reuse the shipped Qwen3-32B / symlinks | Ch5: Serve a Model ("Magic of symlinks" callout) |
| Community models / tt-model-manager | Run & build: The Model Zoo (Community Models) |
| Serve models via API | Run & build: Serving Models on QB2 |
| Run Claude Code / OpenCode on local models | Run & build: Serving Models on QB2 (coding-agents section) |
| Generate video / images | Run & build: The Model Zoo (media-gen section) |
| Write kernels | Tinker: Your First Kernel |
| Customize LEDs | Customize: LED Customization |

## Architecture Facts

- Chip family: Blackhole (not Wormhole — different APIs apply)
- 4 chips = 4 independent PCIe devices, not a mesh
- No NVLink between chips on QB2 — but chips DO talk to each other, over on-die Ethernet cores
  (used for AllReduce during tensor-parallel), the same fabric described in
  `src/content/shared/hardware-overview.md` and `src/content/tracks/ml-practitioner/chapters/02-model-zoo.md`
- Use `ttnn.CreateDevices({0,1,2,3})` for multi-device work
- `TT_METAL_ARCH_NAME=blackhole` required for environment variable checks
- Host OS: Ubuntu 24.04 LTS

## Handoff: recording the tt-studio v2.8.0 demo assets

Context for whoever is on the QB2 capturing media for the guide's v2.8.0
coverage (branch `docs/tt-studio`). The prose is written and cross-linked; only
the demo assets are outstanding.

**Shared prereqs (do once, in the shell you record from):**
1. Launch `tt-studio`; deploy **Qwen3-32B** (pre-cached, no download) from the
   Deploy Model dropdown. Confirm the Coding Agents page shows the gateway online.
2. Export the gateway key WITHOUT echoing it, so it never lands in a GIF:
   `export LITELLM_MASTER_KEY=$(grep -E '^LITELLM_MASTER_KEY=' ~/.local/lib/tt-studio/.env | cut -d= -f2-)`
3. Ensure `claude` and `opencode` are installed and on PATH.

**VHS tapes (terminal — already written, record on the QB2):**
Recording is driven by `tt-demo` now (`demo/demos.yaml`), not one-off `vhs`
invocations. Every tape is a `raw_tape:` scene in that manifest —
`tt-demo record <id>` shells out to `vhs demo/raw/<id>.tape` for you (each
tape's `Output` line writes to `demo/assets/<id>.gif`), then use
`tt-demo list` to see all scenes, `tt-demo verify <id>` for a contact-sheet
check before trusting a take, and `tt-demo publish <ids> --dir src/assets/video`
to copy accepted artifacts into the committed path.
- `demo/raw/13-tt-studio-coding-agents.tape` (scene `13-tt-studio-coding-agents`)
  (Claude Code: env setup + a real curl proof against Qwen3-32B + `claude` launch)
- `demo/raw/14-tt-studio-opencode.tape` (scene `14-tt-studio-opencode`)
  (OpenCode: writes the `tt-studio` provider config + `opencode --model tt-studio/Qwen3-32B`)
- `demo/raw/12-tt-studio-demo.tape` (scene `12-tt-studio-demo`) — **re-record**:
  port corrected 7860→3000 and the wrapper is now explained; the committed GIF
  still shows the old port.
- Record with `tt-demo record <id>`, then `tt-demo verify <id>` and
  `tt-demo publish <id> --dir src/assets/video`. Tune the `Sleep` values to
  real model latency (Qwen3-32B first token after idle can take a few
  seconds). The interactive "type a prompt" money shots are commented out in
  each tape — uncomment if the TUI captures cleanly on the box.

**Browser screenshots (no tape — plain grabs, ~2000px wide, current teal branding):**
- The **Coding Agents page** with its copy-paste snippet panel (the headline shot).
- The **Deploy Model dropdown → Run** on Qwen3-32B (reinforces "fastest first token").
- A **WAN or Flux** generation result (for the media-gen section).
- Save under `src/assets/img/` (create it) or `src/assets/video/` if animated.

**Wiring assets in after capture:** the terminal GIFs have no `<figure>` yet.
Once `13-...gif` exists, paste this at the end of
`src/content/shared/tt-studio-coding-agents.md`:

```html
<figure class="video-demo">
<img src="/assets/video/13-tt-studio-coding-agents.gif" alt="Claude Code configured against tt-studio's local gateway, a curl proof from Qwen3-32B, and the claude session launching on QB2" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">Claude Code running against Qwen3-32B on the QB2 — no cloud API, via tt-studio's gateway on :4000</figcaption>
</figure>
```

(Add the matching `14-tt-studio-opencode.gif` figure the same way if you record
it.) The `video-demo` / inline-style pattern matches every other GIF in the
guide — copy an existing one from `tt-studio-intro.md` if in doubt.

## Handoff: GIFs stale after the environment-model correction

The guide no longer tells anyone to `source ~/tt-metal/python_env/bin/activate` —
that path does not exist on any current install (tt-installer's `install.m4` never
creates it; TT-Metalium is the container `ghcr.io/tenstorrent/tt-metal/tt-metalium-ubuntu-22.04-release-amd64`).
The `.tape` sources under `demo/raw/` have all been corrected, but the
**committed GIFs were recorded before the correction and still show the old
commands**. They need re-recording on a QB2:

| Tape | Scene id | GIF | Why it's stale |
|------|----------|-----|----------------|
| `03-tt-smi-demo.tape` | `03-tt-smi-demo` | `03-tt-smi-demo.gif` | PATH comment reworded |
| `04-tt-installer-demo.tape` | `04-tt-installer-demo` | `04-tt-installer-demo.gif` | claimed `hf` is on PATH; listed `python_env` |
| `04b-venv-demo.tape` | `04b-venv-demo` | `04b-venv-demo.gif` | built entirely around activating `python_env` |
| `05-first-model-demo.tape` | `05-first-model-demo` | `05-first-model-demo.gif` | activates `python_env` |
| `09-vllm-demo.tape` | `09-vllm-demo` | `09-vllm-demo.gif` | both venv paths wrong; `vllm serve` from the host |
| `11-first-kernel-demo.tape` | `11-first-kernel-demo` | `11-first-kernel-demo.gif` | activates `python_env`, uses `TT_METAL_HOME` |

Record with `tt-demo record <id>` on the box, `tt-demo verify <id>` to check
the take, then `tt-demo publish <id> --dir src/assets/video` and commit the
regenerated GIF. Until then the prose is right and the moving pictures are not.
