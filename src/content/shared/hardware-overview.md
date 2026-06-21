## What's Inside

The Tenstorrent Quietbox 2 (QB2) is a workstation with four Blackhole P300c AI accelerators on PCIe. Each chip is independent — four separate devices from the software's point of view, connected to a standard CPU running Ubuntu 24.04 LTS.

| What | Detail |
|------|--------|
| AI chips | 4× Blackhole P300c |
| Tensix cores per chip | 140 (13×10 compute grid) |
| Connection | PCIe Gen4 (4 independent devices) |
| OS | Ubuntu 24.04 LTS |
| Pre-installed | TTNN, vLLM, tt-smi, drivers, Python venvs |
| Source tree | Not included — `~/tt-metal` has venvs, not source |

The chips don't share memory. When you open device 0, you're talking to one Blackhole chip. To use all four together, you use `ttnn.CreateDevices({0, 1, 2, 3})` — not four separate `open_device()` calls.

<div class="callout callout--deep-dive">
<span class="callout-icon illustrated-only">⬡</span>
Each Blackhole chip has a 17×12 Network on Chip (NoC) grid. Of those 204 positions: 140 are Tensix compute cores, 20 are DRAM controllers, 16 are Ethernet cores, 1 is the PCIe interface, and the rest are routing fabric. The grid is how work moves — not through a shared bus, but through a programmable mesh of message-passing nodes.
</div>
