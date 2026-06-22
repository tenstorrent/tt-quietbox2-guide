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
| TTNN venv | `~/tt-metal/python_env/` | Direct API work, TTNN operations, cookbook examples |
| vLLM | `vllm` in `~/.tenstorrent-venv/` | Serving models via HTTP, OpenAI-compatible API |
| Forge/XLA | `tt-forge` wrapper in `~/.local/bin/` | Compile PyTorch/JAX models via container |
| `tt-smi` | `~/.local/bin/tt-smi` (on PATH) | Hardware monitoring, always available |
| Model storage | `~/models/` (convention) | Where you put downloaded model weights |
| Scratch space | `~/tt-scratchpad/` | Working directory for scripts and experiments |

:::callout type="tip"
**Installing on a fresh Ubuntu machine?** `tt-installer` today uses Docker containers for Metalium and Forge — it creates `~/.tenstorrent-venv` with Python tools and installs `tt-metalium` / `tt-forge` wrapper scripts in `~/.local/bin/`. The paths here reflect a configured QB2; a fresh install may differ slightly.
:::

Create the scratch directory if it doesn't exist yet:

```bash
mkdir -p ~/tt-scratchpad ~/models
```

## The Three Environments, Explained

### TTNN (`~/tt-metal/python_env/`)

This is the workhorse. Use it for direct Python API work — opening devices, running TTNN operations, the cookbook examples in this guide.

```bash
source ~/tt-metal/python_env/bin/activate
# prompt changes to (python_env)
python3 -c "import ttnn; print('TTNN ready')"
deactivate
```

### vLLM (in `~/.tenstorrent-venv`)

Use this to run a model as a server with an OpenAI-compatible HTTP API. vLLM is available in the main tenstorrent venv:

```bash
source ~/.tenstorrent-venv/bin/activate
vllm serve ~/models/Qwen3-0.6B --port 8000
```

Or use `tt-studio` for a no-code UI that handles vLLM startup automatically.

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
# TTNN
source ~/tt-metal/python_env/bin/activate
python3 -c "import ttnn; print('✓ TTNN')" && deactivate

# vLLM (in the main tenstorrent venv)
source ~/.tenstorrent-venv/bin/activate
python3 -c "import vllm; print('✓ vLLM')" && deactivate

# Check for the tt-smi binary
which tt-smi && tt-smi --version
```

All three should respond without errors. If TTNN import fails, the venv may not be set up — check [docs.tenstorrent.com](https://docs.tenstorrent.com) for the current setup guide. If `tt-smi` isn't found, add `~/.local/bin` to your PATH (see below).

<figure class="video-demo">
<img src="/assets/video/04b-venv-demo.gif" alt="Activating the TTNN venv and importing ttnn on a QB2" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">Navigating between system Python and the TTNN venv — checking what's active before and after</figcaption>
</figure>

<div class="callout callout--deep-dive">
<span class="callout-icon illustrated-only">📁</span>
<strong>Why ~/tt-metal exists without source code:</strong> On a QB2, <code>~/tt-metal/</code> contains the pre-built TTNN Python environment and compiled shared libraries. The source code — C++ kernels, the build system — isn't there by default, and most users never need it. If you want to build from source (for kernel modification or upstream contributions), the <a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/build-tt-metal/">build-tt-metal lesson</a> walks through it.
</div>

## Installing tt-smi if it's Missing

On a QB2 it shouldn't be missing, but on another Ubuntu system:

```bash
# Option A — public PyPI (any machine, no PPA needed):
pip install tt-smi

# Option B — via apt (requires Tenstorrent PPA, set up by tt-installer):
sudo apt install tt-smi
```

Both install the same tool. Option A works anywhere with Python; option B integrates with your system package manager. On a freshly installed Ubuntu machine without tt-installer, option A is the easier path.

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
<img src="/assets/video/04-tt-installer-demo.gif" alt="tt-installer post-install state showing venvs, tt-smi, and hf on PATH" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">After tt-installer and reboot — venvs, tt-smi, and hf are ready</figcaption>
</figure>

---

**Next:** [Your First Model →](/first-timer/05-your-first-model/)
