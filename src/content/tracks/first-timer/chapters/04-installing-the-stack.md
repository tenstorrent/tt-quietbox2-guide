---
title: Installing the Stack
currentChapter: 04-installing-the-stack
permalink: /first-timer/04-installing-the-stack/
---
{% set persona = personas | findPersona(personaId) %}

# Installing the Stack

On a QB2, this is already done. But understanding what was installed — and why — is worth a few minutes.

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">ℹ️</span>
If you're reading this on a QB2 that came from Tenstorrent, skip to <strong>What You Have</strong> below. The installer already ran.
</div>

{% chunk "install-stack" %}

## What You Have

After installation (or on a stock QB2), your system has:

| Component | Location | What it does |
|-----------|----------|--------------|
| Kernel driver | Loaded automatically | Enables PCIe communication with chips |
| `tt-smi` | `/usr/bin/tt-smi` | Hardware monitoring CLI |
| TTNN Python env | `~/tt-metal/python_env/` | Python API for the chips |
| vLLM env | `~/tt-metal/build/python_env_vllm/` | Inference server environment |
| tt-firmware | Flashed to chips | Chip operating firmware |

## Activating a Python Environment

Before running any Python code that uses the chips, activate the right environment:

```bash
# For TTNN, direct API work
source ~/tt-metal/python_env/bin/activate

# For vLLM serving
source ~/tt-metal/build/python_env_vllm/bin/activate
```

Your prompt will change to show `(python_env)` or similar — that confirms the environment is active.

To deactivate when you're done:

```bash
deactivate
```

<div class="video-placeholder illustrated-only">
  <strong>Coming soon: tt-installer demo</strong>
  Running tt-installer from scratch on a fresh Ubuntu system. Selecting defaults. Watching it complete.
  <!-- VIDEO: VHS recording of tt-installer. Script: scripts/vhs/04-tt-installer-demo.tape -->
</div>

---

**Next:** [Your First Model →](/first-timer/05-your-first-model/)
