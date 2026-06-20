## What's Inside

The Tenstorrent Quietbox 2 (QB2) contains four Blackhole P300c AI accelerators — each one a Blackhole chip, independent, connected via PCIe. They appear as four separate devices to the software stack. The QB2 ships pre-loaded with Ubuntu 24.04 and the Tenstorrent software environment already installed.

Architecture at a glance:

| What | Detail |
|------|--------|
| Chips | 4× Blackhole P300c |
| Connection | PCIe (4 independent devices) |
| OS | Ubuntu 24.04 LTS |
| Pre-installed | TTNN, vLLM, tt-smi, drivers |
| Source tree | Not included — `~/tt-metal` does not exist by default |

The QB2 does not ship with `~/tt-metal` source code. If you want to build kernels from scratch, you'll get there — but first boot is ready to serve models out of the box.
