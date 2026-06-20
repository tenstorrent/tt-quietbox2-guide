---
title: Is This Thing On?
currentChapter: 03-is-this-thing-on
permalink: /first-timer/03-is-this-thing-on/
---
{% set persona = personas | findPersona(personaId) %}

# Is This Thing On?

Before you run anything, confirm the hardware is alive and the software can see it. One command does this.

{% chunk "tt-smi-basics" %}

## Reading the Output

A healthy QB2 will show four devices in the `device_info` array. Look for:

- `"board_type": "BLACKHOLE"` — confirms chip family
- `"pcie_speed": "GEN4"` — confirms PCIe link is up at full speed
- Temperature values in the 35–55°C range at idle — that's normal

If you see fewer than four devices, run:

```bash
dmesg | grep -i tenstorrent | tail -20
```

Look for PCIe errors or firmware messages. The most common cause of a missing device is a loose PCIe connection or a firmware mismatch.

## Checking Firmware

`tt-smi` also reports firmware versions:

```bash
tt-smi -s | python3 -m json.tool | grep -i firmware
```

If the firmware version looks old or mismatched across devices, you may need to update. See the [tt-flash](https://github.com/tenstorrent/tt-flash) documentation for firmware update instructions.

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">✅</span>
Four devices in tt-smi output means the QB2 is healthy and ready. If you see four, move on.
</div>

<div class="video-placeholder illustrated-only">
  <strong>Coming soon: tt-smi live demo</strong>
  Running tt-smi -s on a live QB2, reading the JSON output, identifying all four chips.
  <!-- VIDEO: VHS recording — tt-smi -s on QB2, all four chips visible, JSON formatted. Script: scripts/vhs/03-tt-smi-demo.tape -->
</div>

---

**Next:** [Installing the Stack →](/first-timer/04-installing-the-stack/)
