---
title: What Just Arrived
currentChapter: 01-what-just-arrived
permalink: /first-timer/01-what-just-arrived/
---
{% set persona = personas | findPersona(personaId) %}

# What Just Arrived

You have a Quietbox 2. It's a workstation. It runs Ubuntu. It has four AI accelerators inside.

That last part is the part worth understanding before you turn it on.

{% chunk "hardware-overview" %}

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">🔌</span>
<span class="callout-narrator illustrated-only">Before you go further —</span>
Make sure the QB2 is plugged in, the power switch on the back is on, and the front power button has been pressed. The fan will spin up. That's normal. That's good. That's it working.
</div>

## What Ships Pre-Installed

When Tenstorrent ships a QB2, it's not a blank machine. The full Tenstorrent software stack is already installed:

- Drivers for all four Blackhole chips
- `tt-smi` (hardware monitoring)
- TTNN (the Python API for the chips)
- A vLLM environment (for serving language models)
- Pre-configured Python virtual environments

You don't need to install drivers. You don't need to compile anything. The machine is ready.

What it doesn't have: the `~/tt-metal` source tree. If you eventually want to write kernels at the lowest level, that's a future chapter. For now, everything you need is already there.

## Physical Tour

The QB2 looks like a standard tower workstation. What's inside:

- A standard CPU + motherboard (running Ubuntu)
- Four Blackhole P300c cards on PCIe
- Plenty of RAM and storage for model weights

The chips run hot under load — that's normal. The cooling system handles it. Don't block the vents.

<div class="video-placeholder illustrated-only">
  <strong>Coming soon: Unboxing walkthrough</strong>
  A short video touring the physical QB2 — ports, indicators, power button placement.
</div>

---

**Next:** [First Boot →](/first-timer/02-first-boot/)
