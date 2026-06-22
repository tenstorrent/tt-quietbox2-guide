## What's Inside

The Tenstorrent Quietbox 2 (QB2) is a workstation with two Blackhole p300c cards — four Blackhole chips in total — on PCIe. Each p300c is a dual-chip card, and each chip is independent — four separate devices from the software's point of view, connected to a standard CPU running Ubuntu 24.04 LTS.

| What | Detail |
|------|--------|
| AI chips | 2× Blackhole p300c cards (4 Blackhole chips) |
| Tensix cores per chip | 120 (12×10 compute grid) |
| Connection | PCIe Gen4 (4 independent devices) |
| OS | Ubuntu 24.04 LTS |
| Pre-installed | TTNN, vLLM, tt-smi, drivers, Python venvs |
| Source tree | Not included — `~/tt-metal` has venvs, not source |

The chips don't share memory. When you open device 0, you're talking to one Blackhole chip. To use all four together, you use `ttnn.CreateDevices({0, 1, 2, 3})` — not four separate `open_device()` calls.

<div class="callout callout--deep-dive">
<span class="callout-icon illustrated-only">⬡</span>
Each Blackhole chip is a 17×12 Network on Chip (NoC) grid — 204 positions in total. Of those, 140 are Tensix compute tiles (120 are enabled on QB2's chips; the rest are harvested); the remainder are DRAM controllers, Ethernet cores for chip-to-chip links, the PCIe interface, and the routing fabric between them. The grid is how work moves — not through a shared bus, but through a programmable mesh of message-passing nodes.
</div>
