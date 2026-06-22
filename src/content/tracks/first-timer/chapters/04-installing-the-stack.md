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

After a stock QB2 install (or after tt-installer finishes), this is your map:

| Component | Location | When to use it |
|-----------|----------|----------------|
| TTNN venv | `~/tt-metal/python_env/` | Direct API work, TTNN operations, cookbook examples |
| vLLM venv | `~/tt-metal/build/python_env_vllm/` | Serving models via HTTP, OpenAI-compatible API |
| Forge/XLA venv | `~/tt-forge-venv/` → `/opt/venv-forge` | JAX, TT-Forge, PyTorch/XLA (advanced) |
| `tt-smi` | `/usr/bin/tt-smi` | Hardware monitoring, always available |
| Model storage | `~/models/` (convention) | Where you put downloaded model weights |
| Scratch space | `~/tt-scratchpad/` | Working directory for scripts and experiments |

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

### vLLM (`~/tt-metal/build/python_env_vllm/`)

Use this to run a model as a server with an OpenAI-compatible HTTP API. This is how you'd point a chat application at your QB2.

```bash
source ~/tt-metal/build/python_env_vllm/bin/activate
# prompt changes to (python_env_vllm)
python3 -m vllm.entrypoints.openai.api_server --help
deactivate
```

### TT-Forge/XLA (`~/tt-forge-venv/`)

For JAX and TT-Forge (PyTorch model compiler). More advanced. Keep it separate — this venv conflicts with TTNN:

```bash
# Before activating forge, unset TT_METAL_HOME if you set it
unset TT_METAL_HOME
source ~/tt-forge-venv/bin/activate
```

If `~/tt-forge-venv` doesn't exist:
```bash
ls /opt/venv-forge    # check if it's there
ln -s /opt/venv-forge ~/tt-forge-venv    # create the symlink
```

## Confirming Each Environment Works

Run this check sequence:

```bash
# TTNN
source ~/tt-metal/python_env/bin/activate
python3 -c "import ttnn; print('✓ TTNN')" && deactivate

# vLLM
source ~/tt-metal/build/python_env_vllm/bin/activate
python3 -c "import vllm; print('✓ vLLM')" && deactivate

# Check for the tt-smi binary
which tt-smi && tt-smi --version
```

All three should respond without errors. If TTNN is missing, the install didn't complete — rerun tt-installer. If the vLLM import fails, same fix.

<div class="callout callout--deep-dive">
<span class="callout-icon illustrated-only">📁</span>
<strong>Why ~/tt-metal exists without source code:</strong> The tt-installer builds the Python environments and places them under <code>~/tt-metal/</code> as a conventional home. It also compiles shared libraries (the <code>.so</code> files in <code>~/tt-metal/build/lib/</code>) that TTNN needs at runtime. The source code — the C++ kernels, the build system — isn't needed to use the stack. It's only needed if you want to modify the stack itself. Most people never need it.
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

<div class="video-placeholder illustrated-only">
  <strong>Coming soon: tt-installer walkthrough</strong>
  Running tt-installer on a fresh Ubuntu system — selecting defaults, watching it run, confirming environments.
  <!-- VIDEO: VHS recording. Script: scripts/vhs/04-tt-installer-demo.tape -->
</div>

---

**Next:** [Your First Model →](/first-timer/05-your-first-model/)
