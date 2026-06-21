---
title: The TT-Metal Architecture
currentChapter: 01-tt-metal-architecture
permalink: /builder-hacker/01-tt-metal-architecture/
---
{% set persona = personas | findPersona(personaId) %}

# The TT-Metal Architecture

Before you write a single line of kernel code, you should understand what you're writing it for. The Blackhole chip is not a GPU wearing a different nametag. The memory model is different. The execution model is different. The abstraction layers are deliberately transparent. Once you see the architecture clearly, the API choices stop being arbitrary and start being obvious.

## The Stack From Top to Bottom

Four layers sit between your Python and the chip. Each layer is real and each layer compiles:

```
TT-Lang        →  Python DSL, looks like Python, compiles to assembly
TTNN           →  Python ops, tensor API, calls into Metalium
TT-Metalium    →  C++ kernel API, explicit data movement, JIT compile
Kernel Driver  →  firmware, PCIe dispatch, ring buffers
```

You can enter this stack at any level. TTNN is the right entry point for standard ops. TT-Lang is the right entry point when you need a custom pattern and want AI-assisted development. Metalium is where you go when the abstraction has to disappear.

## Blackhole Grid Anatomy

The Blackhole chip is a 17-column by 12-row network-on-chip (NoC) grid. Every cell in that grid is a node. Not every node is a compute core. The grid has four distinct zones:

**Tensix cores** — columns 1-7 and 9-15, rows 1-10. One hundred and forty of them. These are the compute nodes. Each Tensix core is itself a small computer.

**DRAM controllers** — rows 0 and 11, running the full width of the chip. Eight banks of 12 GB each. The chip's main memory lives here, physically along the chip edges, close to the NoC's routing paths.

**ETH ports** — column 0 and column 16. These connect chips together. On a QB2 with four Blackhole cards, the ETH ports form the chip-to-chip fabric used by `CreateDevices` when you open a multi-chip mesh.

**PCIe interface** — column 8, the center column. Every command from your Python application crosses here. `ttnn.open_device(0)` sends a dispatch message through this column.

{% tensixviz "blackhole", [
  {"step": "highlight", "cores": [[1,0],[2,0],[3,0],[4,0],[5,0],[6,0],[7,0],[9,0],[10,0],[11,0],[12,0],[13,0],[14,0],[15,0],[1,11],[2,11],[3,11],[4,11],[5,11],[6,11],[7,11],[9,11],[10,11],[11,11],[12,11],[13,11],[14,11],[15,11]], "color": "dram", "label": "DRAM banks — rows 0 and 11, 8×12GB", "ms": 800},
  {"step": "pause", "ms": 700},
  {"step": "unhighlight"},
  {"step": "highlight", "cores": [[0,1],[0,2],[0,3],[0,4],[0,5],[0,6],[0,7],[0,8],[0,9],[0,10],[16,1],[16,2],[16,3],[16,4],[16,5],[16,6],[16,7],[16,8],[16,9],[16,10]], "color": "eth", "label": "ETH ports — cols 0 and 16, chip-to-chip links", "ms": 800},
  {"step": "pause", "ms": 700},
  {"step": "unhighlight"},
  {"step": "highlight", "cores": [[8,1],[8,2],[8,3],[8,4],[8,5],[8,6],[8,7],[8,8],[8,9],[8,10]], "color": "pcie", "label": "PCIe column 8 — CPU-to-chip dispatch path", "ms": 800},
  {"step": "pause", "ms": 700},
  {"step": "unhighlight"},
  {"step": "highlight", "cores": [[1,1],[2,1],[3,1],[4,1],[5,1],[6,1],[7,1],[9,1],[10,1],[11,1],[12,1],[13,1],[14,1],[15,1],[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[7,2],[9,2],[10,2],[11,2],[12,2],[13,2],[14,2],[15,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3],[9,3],[10,3],[11,3],[12,3],[13,3],[14,3],[15,3],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4],[9,4],[10,4],[11,4],[12,4],[13,4],[14,4],[15,4],[1,5],[2,5],[3,5],[4,5],[5,5],[6,5],[7,5],[9,5],[10,5],[11,5],[12,5],[13,5],[14,5],[15,5],[1,6],[2,6],[3,6],[4,6],[5,6],[6,6],[7,6],[9,6],[10,6],[11,6],[12,6],[13,6],[14,6],[15,6],[1,7],[2,7],[3,7],[4,7],[5,7],[6,7],[7,7],[9,7],[10,7],[11,7],[12,7],[13,7],[14,7],[15,7],[1,8],[2,8],[3,8],[4,8],[5,8],[6,8],[7,8],[9,8],[10,8],[11,8],[12,8],[13,8],[14,8],[15,8],[1,9],[2,9],[3,9],[4,9],[5,9],[6,9],[7,9],[9,9],[10,9],[11,9],[12,9],[13,9],[14,9],[15,9],[1,10],[2,10],[3,10],[4,10],[5,10],[6,10],[7,10],[9,10],[10,10],[11,10],[12,10],[13,10],[14,10],[15,10]], "color": "tensixActive", "label": "140 Tensix compute cores — cols 1-7 and 9-15, rows 1-10", "ms": 900},
  {"step": "pause", "ms": 1500},
  {"step": "clear"}
] %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">One Blackhole P300c chip. Four of these live in your QB2.</p>

## Inside a Tensix Core

Zoom in on any one of those 140 yellow nodes. Each Tensix core contains:

- **RISC-V control processor** — a small general-purpose CPU that executes your kernel logic
- **Matrix engine (FPU)** — hardware-accelerated matrix multiply and elementwise ops; this is what makes it fast
- **Register tile files** — SRCA, SRCB, and DST registers that hold 32×32 element tiles during computation
- **L1 SRAM** — fast on-core scratchpad memory; your kernel reads data here before the FPU touches it
- **Two NoC endpoints** — one for reads (inbound), one for writes (outbound); both can operate independently and concurrently

The L1 SRAM is crucial. Moving data from DRAM to a Tensix core's L1 is an explicit operation you control. Nothing is cached automatically. This sounds like a burden and becomes a superpower: you know exactly where every byte is.

## The Three-Kernel Model

Every Metalium operation on a Tensix core involves three co-running kernels. All three run on the same core, concurrently:

- **Data-movement-reader** (BRISC) — reads tiles from DRAM or another core's L1 into this core's L1 via the read NoC endpoint
- **Compute** — pops tiles from L1 into the SRCA/SRCB registers, runs the matrix engine, writes results to DST, pushes results back to L1
- **Data-movement-writer** (NCRISC) — takes finished tiles from L1 and sends them to DRAM or another core's L1 via the write NoC endpoint

<div class="callout callout--deep-dive">
<span class="callout-icon illustrated-only">🔬</span>
<strong>Why three kernels?</strong> The answer is overlap. On a conventional GPU, compute waits for data to arrive, then data waits for compute to finish. On a Tensix core, the reader can be pulling the next tile from DRAM while the FPU is processing the current tile, while the writer is sending the previous tile downstream. Three pipelines, one core, no idle cycles in the steady state. This is what makes utilization numbers look so different from GPU profiles.
</div>

## Tiles: The Native Unit

TTNN doesn't think in terms of individual floats or rows. It thinks in 32×32 tiles. A tensor of shape `(64, 64)` becomes 4 tiles of shape `(32, 32)`. The tile format — BFP8, BFP16, or FP32 — is set when you create a tensor:

```python
import ttnn, torch

device = ttnn.open_device(device_id=0)

# Create a tensor — TTNN tiles it automatically on device transfer
t = torch.randn(64, 64)
t_tt = ttnn.from_torch(t, dtype=ttnn.bfloat16, layout=ttnn.TILE_LAYOUT, device=device)

# t_tt is now four 32x32 BF16 tiles distributed in the chip's DRAM
print(t_tt.shape)   # torch.Size([64, 64])
print(t_tt.dtype)   # bfloat16

ttnn.close_device(device)
```

The 32×32 tile size is not adjustable — it is the hardware's register file size. Every operation on the matrix engine processes one tile at a time. Kernels are written to process tiles, readers fetch tiles, writers send tiles.

## The NoC Fabric

The two-dimensional mesh NoC lets any core read from or write to any other core's L1, or any DRAM bank, by address. There is no coherence protocol, no cache hierarchy. You own the data movement. The routing is deterministic and the bandwidth is high — but contention is possible, which is why the profiler shows per-link NoC traffic.

For a single-chip operation, you're moving tiles from DRAM row-0 or row-11 nodes, across the mesh, to your compute cores' L1. For a multi-chip operation via `CreateDevices`, tiles cross the ETH columns at the chip edges and appear at another chip's ETH columns before continuing across that chip's mesh.

## A Minimal TTNN Example

This is the entire open-device-matmul-close pattern, which you'll recognize from every tutorial:

```python
import ttnn, torch

# Open chip 0
device = ttnn.open_device(device_id=0)

# Move data onto the chip
a = ttnn.from_torch(torch.randn(64, 64), dtype=ttnn.bfloat16,
                    layout=ttnn.TILE_LAYOUT, device=device)
b = ttnn.from_torch(torch.randn(64, 64), dtype=ttnn.bfloat16,
                    layout=ttnn.TILE_LAYOUT, device=device)

# Dispatch the matmul kernel — compiles JIT on first run
c = ttnn.matmul(a, b)

# Pull result back to CPU
result = ttnn.to_torch(c)
print(result.shape)

ttnn.close_device(device)
```

Nothing in this example is magic. Each step maps to a real chip operation: the `from_torch` calls dispatch DMA transfers through the PCIe column to DRAM; `matmul` dispatches reader/compute/writer kernels to a set of Tensix cores; `to_torch` moves the result tiles back through PCIe to host RAM.

---

**Next:** [Your First Kernel →](/builder-hacker/02-first-kernel/)
