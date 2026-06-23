---
title: What to Know About Your Workstation
currentChapter: 01-what-just-arrived
permalink: /first-timer/01-what-just-arrived/
---
{% set persona = personas | findPersona(personaId) %}

# What to Know About Your Workstation

Your workstation is a Tenstorrent Quietbox 2: four AI accelerators inside, an operating system you may not have used before, and the software stack already configured and waiting. The machine is ready to go — what's left is knowing what you've got.

This guide doesn't assume you know Linux, or Python, or what a PCIe slot is. It assumes you're curious, and that curiosity is enough.

{% chunk "hardware-overview" %}

<img src="/assets/illustrations/chip-signal-path.svg" alt="Four Blackhole chips connected via PCIe to the CPU, with software stack and Python environments" class="spot-illustration" style="max-width:100%;"/>

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">🔌</span>
Before anything else: power switch on the back panel to the ON position, then press the front power button. The fans spin up. That's the QB2 waking up. That sound is correct and expected.
</div>

## What Ships Pre-Installed

Tenstorrent ships the QB2 ready to serve models. You don't install drivers. You don't compile anything. The full stack is already there:

- **Kernel driver** — loaded automatically at boot, makes the chips visible to software
- **`tt-smi`** — hardware monitoring tool, lives at `/usr/bin/tt-smi`
- **TTNN Python environment** — pre-built venv at `~/tt-metal/python_env/`
- **vLLM** — in the main tenstorrent venv at `~/.tenstorrent-venv/`
- **TT-Forge/XLA** — container wrapper at `~/.local/bin/tt-forge`
- **tt-studio** — the no-code web UI for serving models, pre-installed (launch with `tt-studio`)
- **A ready-to-run model** — Qwen3-32B, weights pre-cached on disk, deployable from tt-studio with no download
- **Firmware** — already flashed to all four chips

What's intentionally absent: the `~/tt-metal` source code. The environments are there; the source isn't. You can build models, run inference, and work with the full API stack without it. Building from source is a later chapter — a much later chapter.

## Physical Tour

The QB2 looks like a standard tower workstation. On the inside:

- CPU and motherboard running Ubuntu 24.04 LTS
- Two Blackhole p300c cards (four Blackhole chips total)
- RAM sized for production inference workloads
- Storage for model weights — but watch it carefully (more on that in [Chapter 2](/first-timer/02-first-boot/))

The chips run warm under load. Fans will get louder when you run inference. This is correct. The cooling is designed for sustained operation at full chip temperature.

{% tensixviz "blackhole", [
  {"step": "highlight", "cores": [[0,1],[0,2],[0,3],[0,4],[0,5],[0,6],[0,7],[0,8],[0,9],[0,10],[16,1],[16,2],[16,3],[16,4],[16,5],[16,6],[16,7],[16,8],[16,9],[16,10]], "color": "eth", "label": "Ethernet cores — 16 total, ring the chip edge", "ms": 700},
  {"step": "pause", "ms": 600},
  {"step": "unhighlight"},
  {"step": "highlight", "cores": [[1,0],[2,0],[3,0],[4,0],[5,0],[6,0],[7,0],[9,0],[10,0],[11,0],[12,0],[13,0],[14,0],[15,0],[1,11],[2,11],[3,11],[4,11],[5,11],[6,11],[7,11],[9,11],[10,11],[11,11],[12,11],[13,11],[14,11],[15,11]], "color": "dram", "label": "DRAM controllers — top and bottom rows", "ms": 700},
  {"step": "pause", "ms": 600},
  {"step": "unhighlight"},
  {"step": "highlight", "cores": [[8,1],[8,2],[8,3],[8,4],[8,5],[8,6],[8,7],[8,8],[8,9],[8,10]], "color": "pcie", "label": "PCIe interface column — your connection to the CPU", "ms": 700},
  {"step": "pause", "ms": 600},
  {"step": "unhighlight"},
  {"step": "highlight", "cores": [[1,1],[2,1],[3,1],[4,1],[5,1],[6,1],[7,1],[9,1],[10,1],[11,1],[12,1],[13,1],[14,1],[15,1],[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[7,2],[9,2],[10,2],[11,2],[12,2],[13,2],[14,2],[15,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3],[9,3],[10,3],[11,3],[12,3],[13,3],[14,3],[15,3],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4],[9,4],[10,4],[11,4],[12,4],[13,4],[14,4],[15,4],[1,5],[2,5],[3,5],[4,5],[5,5],[6,5],[7,5],[9,5],[10,5],[11,5],[12,5],[13,5],[14,5],[15,5],[1,6],[2,6],[3,6],[4,6],[5,6],[6,6],[7,6],[9,6],[10,6],[11,6],[12,6],[13,6],[14,6],[15,6],[1,7],[2,7],[3,7],[4,7],[5,7],[6,7],[7,7],[9,7],[10,7],[11,7],[12,7],[13,7],[14,7],[15,7],[1,8],[2,8],[3,8],[4,8],[5,8],[6,8],[7,8],[9,8],[10,8],[11,8],[12,8],[13,8],[14,8],[15,8],[1,9],[2,9],[3,9],[4,9],[5,9],[6,9],[7,9],[9,9],[10,9],[11,9],[12,9],[13,9],[14,9],[15,9],[1,10],[2,10],[3,10],[4,10],[5,10],[6,10],[7,10],[9,10],[10,10],[11,10],[12,10],[13,10],[14,10],[15,10]], "color": "tensixActive", "label": "Tensix compute cores (120 enabled per chip) — this is where your models run", "ms": 900},
  {"step": "pause", "ms": 1500},
  {"step": "clear"}
] %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">One Blackhole chip. You have four, on two p300c cards.</p>


---

**Next:** [First Boot →](/first-timer/02-first-boot/)
