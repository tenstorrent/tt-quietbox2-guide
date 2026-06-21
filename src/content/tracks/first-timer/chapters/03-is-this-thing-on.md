---
title: Is This Thing On?
currentChapter: 03-is-this-thing-on
permalink: /first-timer/03-is-this-thing-on/
---
{% set persona = personas | findPersona(personaId) %}

# Is This Thing On?

Before running a model, confirm the hardware is alive and the software can see it. One command, four chips, zero guessing.

{% chunk "tt-smi-basics" %}

## Reading the Output

A healthy QB2 shows four entries in `device_info`. Look at each one for:

- **`"board_type": "BLACKHOLE"`** — confirms chip family. If you see anything else, something's wrong.
- **`"pcie_speed": "GEN4"`** — PCIe link is up at full speed. GEN3 would mean a slot compatibility issue.
- **`"pcie_width": "x16"`** — full-width link. Narrower means lower bandwidth.
- **Temperature in the 35–55°C range** — normal at idle. Higher under load is fine.

Count the entries:

```bash
tt-smi -s | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d['device_info']), 'devices')"
```

If you see `4 devices`, move on. The QB2 is ready.

## If You See Fewer Than Four

A missing device usually means one of three things:

**PCIe link not established:**
```bash
dmesg | grep -i tenstorrent | tail -20
```
Look for errors about PCIe enumeration or firmware loading failure. A loose card is possible — the QB2 ships with cards seated, but transit happens.

**Firmware mismatch:**
```bash
tt-smi -s | python3 -m json.tool | grep -i fw_version
```
If firmware versions differ across devices, or show 0.0.0, you may need to reflash. See the [tt-flash documentation](https://github.com/tenstorrent/tt-flash) for instructions.

**Driver not loaded:**
```bash
lsmod | grep tenstorrent
```
If nothing prints, the kernel driver isn't loaded. This shouldn't happen on a stock QB2, but if it does:
```bash
sudo modprobe tenstorrent
```

<div class="callout callout--deep-dive">
<span class="callout-icon illustrated-only">🔬</span>
<strong>What tt-smi actually reads:</strong> The monitoring daemon talks to the chips via the kernel driver over PCIe. Temperatures come from on-chip thermal sensors. Power readings come from board-level current monitors. The data path: chip hwmon → kernel driver → tt-smi → your terminal. If a chip is missing from output, the driver never established a PCIe link to it.
</div>

## Watching in Real Time

For a live view of all four chips while running inference:

```bash
tt-smi
```

This opens the interactive TUI — press `q` to quit. You'll see per-chip utilization, temperature, and memory usage update live. Useful when a model is running and you want to see all four chips light up.

{% tensixviz "blackhole", [
  {"step": "highlight", "cores": [[1,1],[2,1],[3,1],[4,1],[5,1],[6,1],[7,1],[9,1],[10,1],[11,1],[12,1],[13,1],[14,1],[15,1]], "color": "teal", "label": "Prefill: first row of cores handling prompt tokens", "ms": 600},
  {"step": "pause", "ms": 500},
  {"step": "highlight", "cores": [[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[7,2],[9,2],[10,2],[11,2],[12,2],[13,2],[14,2],[15,2]], "color": "teal", "label": "", "ms": 400},
  {"step": "pause", "ms": 300},
  {"step": "highlight", "cores": [[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3],[9,3],[10,3],[11,3],[12,3],[13,3],[14,3],[15,3],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4],[9,4],[10,4],[11,4],[12,4],[13,4],[14,4],[15,4],[1,5],[2,5],[3,5],[4,5],[5,5],[6,5],[7,5],[9,5],[10,5],[11,5],[12,5],[13,5],[14,5],[15,5],[1,6],[2,6],[3,6],[4,6],[5,6],[6,6],[7,6],[9,6],[10,6],[11,6],[12,6],[13,6],[14,6],[15,6],[1,7],[2,7],[3,7],[4,7],[5,7],[6,7],[7,7],[9,7],[10,7],[11,7],[12,7],[13,7],[14,7],[15,7],[1,8],[2,8],[3,8],[4,8],[5,8],[6,8],[7,8],[9,8],[10,8],[11,8],[12,8],[13,8],[14,8],[15,8],[1,9],[2,9],[3,9],[4,9],[5,9],[6,9],[7,9],[9,9],[10,9],[11,9],[12,9],[13,9],[14,9],[15,9],[1,10],[2,10],[3,10],[4,10],[5,10],[6,10],[7,10],[9,10],[10,10],[11,10],[12,10],[13,10],[14,10],[15,10]], "color": "tensixActive", "label": "Decode: all 140 cores active — one token per step", "ms": 800},
  {"step": "pause", "ms": 1500},
  {"step": "clear"}
] %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">This is what active inference looks like inside one chip. Four of these run in parallel on a QB2.</p>

<div class="video-placeholder illustrated-only">
  <strong>Coming soon: tt-smi live demo</strong>
  Running tt-smi -s on a live QB2 — all four chips visible, JSON output formatted and annotated.
  <!-- VIDEO: VHS recording. Script: scripts/vhs/03-tt-smi-demo.tape -->
</div>

---

**Next:** [Installing the Stack →](/first-timer/04-installing-the-stack/)
