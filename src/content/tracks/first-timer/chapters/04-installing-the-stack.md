---
title: Installing the Stack
currentChapter: 04-installing-the-stack
permalink: /first-timer/04-installing-the-stack/
---
{% set persona = personas | findPersona(personaId) %}

# Installing the Stack

On a QB2 from Tenstorrent, this is already done. The venvs are there, the driver is loaded, the firmware is flashed. This chapter is for understanding what exists and where — so you know which environment to activate when, and what to do if something's missing.

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">✅</span>
If your QB2 came pre-configured: jump to <strong>What You Have</strong> below. The install already ran.
</div>

{% chunk "install-stack" %}

## What You Have

On a QB2 from Tenstorrent, the stack is pre-installed. Here's your map:

| Component | Location | When to use it |
|-----------|----------|----------------|
| TTNN / Metalium | `tt-metalium` wrapper in `~/.local/bin/` | Direct API work, TTNN operations, cookbook examples |
| Hardware tooling | `~/.tenstorrent-venv/` — `tt-smi`, `tt-flash` | Monitoring and firmware. Nothing else belongs in here |
| Serving | `~/.local/lib/tt-inference-server` | Serving models via HTTP, OpenAI-compatible API — runs vLLM in a container |
| Forge/XLA | `tt-forge` wrapper in `~/.local/bin/` | Compile PyTorch/JAX models via container — *opt-in, may not be present* |
| `tt-smi` | in `~/.tenstorrent-venv/bin/` — on PATH once that venv is active | Hardware monitoring, always available |
| Model storage | `~/models/` (convention) | Where you put downloaded model weights |
| Scratch space | `~/tt-scratchpad/` | Working directory for scripts and experiments |

:::callout type="warn"
**There is no `~/tt-metal` and no `~/tt-metal/python_env`.** Older QB2 notes — and earlier
versions of this page — told you to activate a TTNN venv at that path. Nothing on a current
machine creates it: `tt-installer` ships TT-Metalium as a container image and gives you the
`tt-metalium` wrapper instead. If a command in some other guide starts with
`source ~/tt-metal/python_env/bin/activate`, substitute `tt-metalium`.
:::

:::callout type="tip"
**Installing on a fresh Ubuntu machine?** `tt-installer` uses Docker containers for Metalium and
(optionally) Forge. It creates `~/.tenstorrent-venv` for the Python *hardware tools* and installs
the `tt-metalium` / `tt-forge` wrapper scripts in `~/.local/bin/`. The paths here reflect a
configured QB2; a fresh install may differ slightly.
:::

Create the scratch directory if it doesn't exist yet:

```bash
mkdir -p ~/tt-scratchpad ~/models
```

## The Three Environments, Explained

Two of them are containers and one is a venv. That's the thing worth internalising: only the
hardware tooling lives in a virtual environment on the host.

### TTNN — the `tt-metalium` container

This is the workhorse. Use it for direct Python API work — opening devices, running TTNN operations, the cookbook examples in this guide.

```bash
tt-metalium
# you're now in a shell inside the container, home directory mounted
python3 -c "import ttnn; print('TTNN ready')"
exit
```

TTNN is already on the container's default interpreter (`/opt/venv/bin/python3`), so there's
nothing to activate. The first run pulls a multi-GB image; later runs start immediately.

### Serving — `tt-inference-server`

Use this to run a model as a server with an OpenAI-compatible HTTP API. You don't invoke `vllm`
yourself and it isn't installed on the host — it ships inside a container that
`tt-inference-server` launches:

```bash
export HF_TOKEN=hf_...   # gated repos need it even when the weights are already local

python3 ~/.local/lib/tt-inference-server/run.py \
  --model Llama-3.1-8B-Instruct \
  --workflow server \
  --tt-device p300x2 \
  --docker-server
```

`run.py` picks the container image, sets `TT_METAL_ARCH_NAME`, `MESH_DEVICE` and the vLLM
timeouts per model, and publishes the API on port 8000. `--tt-device p300x2` is the whole QB2 —
two P300 boards, four chips. Add `--print-docker-cmd` to see the `docker run` it would issue.

Or use `tt-studio` for a no-code UI that handles all of this for you.

:::callout type="tip"
Watch the startup log for a line saying the `tt` platform has been selected. Without it, vLLM is
running but cannot see your hardware — see the
[vLLM on QB2 chapter](/ml-practitioner/03-vllm-on-qb2/), which also covers running `vllm serve`
by hand if you want the lower-level control surface.
:::

### TT-Forge (`tt-forge` wrapper)

`tt-forge` is a Docker container wrapper installed to `~/.local/bin/` by tt-installer. It runs the TT-XLA/Forge compiler stack without requiring a local Python venv:

```bash
# Use the tt-forge wrapper directly
tt-forge --help
```

For scripting with `import forge` in Python, use the `tt-forge-fe` source tree or check [docs.tenstorrent.com/tt-forge](https://docs.tenstorrent.com/tt-forge-onnx/) for current installation instructions.

## Confirming Each Environment Works

Run this check sequence:

```bash
# TTNN — inside the container
tt-metalium -c 'python3 -c "import ttnn; print(\"OK TTNN\")"'""

# The serving stack — the launcher is a file on disk, so just check it's there
python3 ~/.local/lib/tt-inference-server/run.py --help > /dev/null && echo '✓ tt-inference-server'

# The hardware tooling
which tt-smi && tt-smi --version
```

All three should respond without errors.

Note what is *not* in that list: there's no `import vllm` check, because vLLM isn't installed on
the host — it lives in the container `run.py` starts. If you run `python3 -c "import vllm"` in
`~/.tenstorrent-venv` and get a `ModuleNotFoundError`, nothing is broken; that venv only ever
contained `tt-smi` and `tt-flash`.

If any Tenstorrent command comes back `command not found`, the wrapper is almost certainly
installed and merely unreachable — add `~/.local/bin` to your PATH (see below).

<figure class="video-demo">
<img src="/assets/video/04b-venv-demo.gif" alt="Checking which python3 is active on the QB2 host and inside the tt-metalium container" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">Checking what <code>which python3</code> reports on the host versus inside <code>tt-metalium</code></figcaption>
</figure>

<div class="callout callout--deep-dive">
<span class="callout-icon illustrated-only">📁</span>
<strong>Why there's no <code>~/tt-metal</code> at all:</strong> TT-Metalium reaches your QB2 as a container image — <code>ghcr.io/tenstorrent/tt-metal/tt-metalium-ubuntu-22.04-release-amd64</code> — with the Python environment and compiled shared libraries inside it. Nothing is unpacked into your home directory, which is why <code>ls ~/tt-metal</code> comes back empty-handed and why the TTNN import only works after <code>tt-metalium</code>. Most users never need more than that. If you do want a real checkout to build from source (for kernel modification or upstream contributions), the <a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/build-tt-metal/">build-tt-metal lesson</a> walks through it.
</div>

## Installing tt-smi if it's Missing

On a QB2 it shouldn't be missing, but on another Ubuntu system:

```bash
# Option A — public PyPI (any machine, no PPA needed):
pip install tt-smi

# Option B — via apt (requires the Tenstorrent repository, set up by tt-installer):
sudo apt install tt-smi
```

Both install the same tool. Option A works anywhere with Python; option B integrates with your system package manager. On a freshly installed Ubuntu machine without tt-installer, option A is the easier path.

Option B needs the Tenstorrent repository *and* its signing key at `/etc/apt/keyrings/tt-pkg-key.asc` — see [The Tenstorrent apt repository](#the-tenstorrent-apt-repository-and-its-signing-key) above. If `apt` complains the repository isn't signed, that key is what's missing.

## Disk Space and Model Storage

Models consume significant disk space. Plan accordingly:

| Model | Size on disk |
|-------|-------------|
| Qwen3-0.6B | ~1.5 GB |
| Qwen3-8B | ~16 GB |
| Llama-3.1-8B-Instruct | ~16 GB |
| Llama-3.1-70B | ~140 GB |

The convention across all Tenstorrent documentation is `~/models/<model-name>/`. Nothing enforces this — you can store models anywhere and point `--model` at any path — but using the convention means every tutorial command works without substitution.

Check space before any download:

```bash
df -h ~/models
```

<figure class="video-demo">
<img src="/assets/video/04-tt-installer-demo.gif" alt="tt-installer post-install state on a QB2 — the hardware-tooling venv and tt-smi on PATH" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">After tt-installer and reboot — the tooling venv and <code>tt-smi</code> are ready</figcaption>
</figure>

---

**Next:** [Your First Model →](/first-timer/05-your-first-model/)
