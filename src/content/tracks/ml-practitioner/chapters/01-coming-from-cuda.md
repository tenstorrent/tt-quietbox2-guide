---
title: Coming From CUDA
currentChapter: 01-coming-from-cuda
permalink: /ml-practitioner/01-coming-from-cuda/
---
{% set persona = personas | findPersona(personaId) %}

# Coming From CUDA

You know `cudaMalloc`. You know grid-dim and block-dim. You've tuned shared memory usage, you've written custom CUDA kernels, and you've debugged timing issues with Nsight. You have a mental model of how GPU compute actually works, not just how PyTorch wraps it.

That mental model transfers here, but not intact. Some pieces map cleanly. Some don't exist. And some things you were papering over on the GPU are now explicit, visible, and tunable. The next ten minutes remaps the terrain.

## Pick Your Altitude

The first question a CUDA developer asks is "where's my `model.cuda()`?" The honest answer is that there isn't one entry point — there are three, and which one you reach for depends on how much control you want. CUDA has the same three tiers; you just rarely think about them as a stack because NVIDIA blurs the seams.

| You want to… | On CUDA you'd use… | On Tensix, write at… |
|---|---|---|
| Just run my PyTorch/JAX model | `model.to("cuda")` + `torch.compile` | **TT-Forge / TT-XLA** — `torch.compile(model, backend="tt")` |
| Call optimized library ops | cuBLAS / cuDNN / CUTLASS | **TTNN** — `ttnn.matmul`, `ttnn.conv2d`, fused attention |
| Write a custom kernel, but in Python | a hand-rolled CUDA C kernel | **TT-Lang** — a Python DSL; explicit reader/compute/writer |
| Drop all the way to the metal | raw CUDA C + PTX tuning | **TT-Metalium** — RISC-V kernels, hand-routed NoC moves |

The closest thing to `model.cuda()` is the top tier: **TT-Forge** traces your graph and lowers it to Tensix automatically. That's [Chapter 6](/ml-practitioner/06-tt-forge/) — reach for it when you want the model to *just run*. The two bottom tiers are for the cases TTNN doesn't cover: **TT-Lang** lets you write a custom kernel in Python with no C++, and **TT-Metalium** is the C++ floor where every abstraction disappears. Both live in the [Builder/Hacker track](/builder-hacker/01-tt-metal-architecture/) — and, as the last section of this chapter explains, the TT-Lang tier is far more reachable than "write your own kernel" sounds on CUDA.

**This track lives in the middle, at TTNN** — the tier where you have hand-optimized ops but still write Python, not kernels. It's the sweet spot for performance work that doesn't require descending to the metal, so that's where the rest of this chapter focuses.

## Thread Blocks vs. Tensix Tiles

On a GPU, a thread block is the unit of cooperative work: a group of threads that can share L1/shared memory and synchronize. The programmer launches a grid of blocks; the hardware schedules them onto SMs.

On Blackhole, the unit is a **Tensix core**. There are 120 enabled per chip (a 12×10 block of the 14×10 physical Tensix grid), sitting inside a larger 17×12 NoC grid that also carries DRAM, Ethernet, and PCIe nodes. Each core has its own L1 SRAM, its own set of RISC-V processing cores (five of them), and its own connection to the Network-on-Chip (NoC) fabric that threads through the entire grid. Tensix cores don't share memory with each other. There's no "block-scope" shared memory. There's only what one core holds, and what it explicitly sends over the NoC to another.

This is the fundamental shift. On CUDA, data sharing between threads in a block is cheap and implicit — shared memory just works. On Tensix, data movement is the thing you design around. Every byte a core receives came from somewhere specific, via a routed packet on the NoC. That movement is visible to you. It's also where the performance is.

There's a deeper reason it's visible: **there is no warp scheduler hiding memory latency.** On a GPU, when one warp stalls waiting on a global-memory read, the SM scheduler instantly swaps in another resident warp — latency disappears behind oversubscription, and you mostly don't think about it. Tensix has no such trick. Instead, each core runs an explicit **reader → compute → writer** pipeline: one RISC-V core streams tiles into L1, the matrix engine works on them, another core streams results out, and they overlap by design rather than by lucky scheduling. At the TTNN level you don't write that pipeline — the ops do — but it's why tensor *layout* matters so much here. A layout that lets the reader stage clean tiles keeps the pipeline full; one that forces a reshuffle stalls it, and there's no spare warp to paper over the gap.

## L1 SRAM vs. Shared Memory

Each Tensix core has 1.5 MB of L1 SRAM. On a GPU, your shared memory budget is typically 48–96 KB per SM, and you fight for it. On Tensix, you have a full 1.5 MB per core to work with.

The catch: that memory doesn't auto-populate. On a GPU, you launch a kernel and global memory reads happen via caches. On Tensix, you write the code that moves data from DRAM (the rows at the top and bottom of the chip grid) into the L1 of whichever cores need it. TTNN does this for you when you use its built-in ops — but if you drop to Metalium, you're writing those NoC reads yourself.

For someone writing at the TTNN Python level (which is where this track lives), the takeaway is simpler: tensor operations in TTNN are already written to stage data correctly. You don't write data movement code. But you do care about tensor layout, because layout determines whether the underlying kernels can move data efficiently or have to reshuffle it first.

## TTNN as the CUDA Runtime Equivalent

Think of TTNN the way you think of `libcudart` plus cuBLAS plus cuDNN — all fused into one Python API. It handles device open/close, tensor allocation in device memory, op dispatch, kernel compilation (via Metalium under the hood), and synchronization.

The critical difference from cuBLAS: TTNN compiles ops JIT on first invocation. When you run a matrix multiply for the first time on a new tensor shape, Metalium generates a Tensix kernel for that exact configuration. Subsequent calls with the same shape hit the op cache and run fast. This is why first-run latency can be a few seconds — and why subsequent runs are fast enough to serve production traffic.

```python
import ttnn
import torch

# Open a single chip (device_id=0)
device = ttnn.open_device(device_id=0)

# Move a PyTorch tensor to device
torch_a = torch.randn(1024, 1024)
a = ttnn.from_torch(torch_a, device=device, dtype=ttnn.bfloat16)

# This compiles on first run, then caches
result = ttnn.matmul(a, a)

# Pull back to CPU
out = ttnn.to_torch(result)
ttnn.close_device(device)
```

Compare this to CUDA: `cudaMemcpy`, `cublasSgemm`, `cudaMemcpy` back. The pattern is the same. The surface is different.

:::callout type="tip"
`ttnn.from_torch` copies the tensor to device DRAM (the DRAM banks at row 0 and row 11 of the Blackhole grid). The compute cores never touch DRAM directly — they pull tiles into L1 over the NoC when the kernel runs. You don't manage this. TTNN does. But knowing it's happening helps you reason about bandwidth.
:::

## What Transfers From CUDA Knowledge

Tensor shapes, batch dimensions, attention head patterns — all of this maps directly. The math doesn't change. The numerics don't change (bfloat16 is first-class here, same as modern GPUs). Batching strategies that work on GPU work on Tensix.

Knowledge of kernel fusion matters. The same principle applies: fewer round-trips through memory means faster execution. TTNN has fused ops (fused attention, fused feedforward) that follow the same logic as FlashAttention on CUDA.

Multi-device tensor parallelism maps directly too. The QB2 has four chips. When you run a 70B model, attention heads get split across chips the same way they'd split across GPUs in a tensor-parallel setup. The API is different — `ttnn.CreateDevices({0,1,2,3})` instead of `torch.distributed` — but the concept transfers.

## What Doesn't Transfer

**CUBLAS and cuDNN don't exist here.** There's no drop-in replacement. If your code calls `torch.nn.functional.conv2d` and you want it to run on Blackhole, you need to either use TTNN's conv2d op or compile via TT-Forge (which traces PyTorch graphs and lowers them to TTNN). You can't just `model.cuda()` and move on.

**Device memory pointers are gone.** CUDA lets you grab a raw `void*` to device memory and pass it around. TTNN tensors are opaque objects — no raw pointer access. If your code does custom CUDA pointer arithmetic, that approach doesn't port. You use TTNN ops, or you write Metalium kernels (a Tinker track topic).

**Unified memory has no equivalent.** There's no `cudaMallocManaged`. Data is either on CPU or on the device, and you move it explicitly via `ttnn.from_torch` and `ttnn.to_torch`.

**Grid launch syntax is gone.** There's no `<<<gridDim, blockDim>>>`. Kernel dispatch is handled by the TTNN op, which decides how to tile the work across the Tensix grid. You influence this via tensor layout and op selection, not by choosing block/thread dimensions.

## CUDA Concept Mapping Table

| CUDA Concept | Tensix / TTNN Equivalent |
|---|---|
| Streaming Multiprocessor (SM) | Tensix core |
| Thread block | Tile computation on one Tensix core |
| Shared memory | L1 SRAM per Tensix core (1.5 MB) |
| Global memory | DRAM banks (rows 0 and 11 of chip grid) |
| cudaMemcpy H2D | `ttnn.from_torch(tensor, device=device)` |
| cudaMemcpy D2H | `ttnn.to_torch(tt_tensor)` |
| cuBLAS sgemm | `ttnn.matmul(a, b)` |
| CUDA kernel launch `<<<g,b>>>` | TTNN op dispatch (automatic) |
| Warp | RISC-V core thread within one Tensix core |
| NCCL multi-GPU | `ttnn.CreateDevices({0,1,2,3})` mesh fabric |
| Nsight profiling | `ttnn.experimental.profiler`, tt-toplike |
| `torch.cuda.synchronize()` | `ttnn.synchronize_device(device)` |

## Blackhole's NoC Fabric

The four Blackhole chips in your QB2 sit on two p300c cards, linked by Warp cables and on-chip Ethernet — not PCIe (PCIe is only the host-to-card link). Intra-chip, the NoC connects every core to every other core and to the DRAM banks at roughly 1 TB/s aggregate bandwidth. This is not the same topology as NVLink or PCIe between discrete GPUs — it's a different architecture where the cost of moving data within a chip is much lower relative to compute throughput than on a GPU.

For multi-chip workloads, the four chips form a mesh using their Ethernet cores (the left and right columns of the chip grid). This is how tensor-parallel models distribute their KV-cache updates — not through the host CPU, but directly chip-to-chip.

:::callout type="tip"
If you've read benchmarks or write-ups based on a single Blackhole card (the P150b, for example), they transfer directly: every chip in your QB2 *is* that same Blackhole part. The per-chip mental model — Tensix grid, L1, NoC, the reader/compute/writer pipeline — is identical. What the QB2 adds on top is the four-chip mesh for scaling past a single card; nothing about the single-chip picture changes.
:::

{% tensixviz "blackhole", [
  {"action": "highlight", "coords": [[1,1],[2,1],[3,1],[4,1],[5,1],[6,1],[7,1],[9,1],[10,1],[11,1],[12,1],[13,1],[14,1],[15,1],[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[7,2],[9,2],[10,2],[11,2],[12,2],[13,2],[14,2],[15,2]], "color": "var(--muted)", "label": "DRAM row staging data into tiles"},
  {"action": "pause", "ms": 500},
  {"action": "transfer", "from": [[1,0],[2,0],[3,0],[4,0],[5,0],[6,0],[7,0]], "to": [[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3]], "color": "var(--teal)"},
  {"action": "pause", "ms": 300},
  {"action": "highlight", "coords": [[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3],[9,3],[10,3],[11,3],[12,3],[13,3],[14,3],[15,3],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4],[9,4],[10,4],[11,4],[12,4],[13,4],[14,4],[15,4],[1,5],[2,5],[3,5],[4,5],[5,5],[6,5],[7,5],[9,5],[10,5],[11,5],[12,5],[13,5],[14,5],[15,5],[1,6],[2,6],[3,6],[4,6],[5,6],[6,6],[7,6],[9,6],[10,6],[11,6],[12,6],[13,6],[14,6],[15,6],[1,7],[2,7],[3,7],[4,7],[5,7],[6,7],[7,7],[9,7],[10,7],[11,7],[12,7],[13,7],[14,7],[15,7],[1,8],[2,8],[3,8],[4,8],[5,8],[6,8],[7,8],[9,8],[10,8],[11,8],[12,8],[13,8],[14,8],[15,8]], "color": "var(--teal)", "label": "Compute cores working on tiles pulled from DRAM"},
  {"action": "pause", "ms": 1200},
  {"action": "clear"}
] %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">Matrix multiply: DRAM rows stage the operand tiles, compute cores pull them over the NoC and run.</p>

:::callout type="deep-dive"
The Blackhole NoC is a 2D torus mesh, not a crossbar or bus. Two independent NoC overlays (NOC0 and NOC1) carry traffic in opposite directions to avoid deadlock. When you write Metalium kernels, you choose which NoC to use for which transfers. At the TTNN level, the compiler makes these choices. Understanding the topology helps you reason about why certain tensor layouts perform better — the ones that minimize cross-NoC traffic in the hot inner loops.
:::

## Custom Kernels Without the Dread — and the Agentic Shortcut

On CUDA, "you'll need a custom kernel" is a sentence that ends a lot of afternoons. It means C++, it means reasoning about occupancy and warp divergence and memory coalescing, and it means racing against bugs that only show up at certain block sizes. It's also exactly the kind of code that AI coding agents are *bad* at: so much of a CUDA kernel's correctness lives in implicit, unstated assumptions — what's resident, what's coalesced, which warp got there first — that there's nothing concrete for an agent to verify against. The spec isn't in the source; it's in the programmer's head.

The middle-lower tier, **TT-Lang**, inverts that. It's a Python DSL (no C++) for writing the one custom op TTNN doesn't expose — a fused pattern, a non-standard attention variant, an activation with a specific numerical property. And it's built around the same **reader → compute → writer** structure from earlier in this chapter, except now you write the three sections explicitly: the reader declares exactly which tiles arrive and from where, compute is pure tile math on those arrivals, the writer declares exactly what leaves. Nothing is implicit.

That explicitness is the whole trick, and it's why agentic development gets you remarkably far here. Because the full spec lives *in the source* — arrivals in, math, departures out — an AI coding agent has something complete to generate against and something concrete to check its work against. You describe the kernel in those three terms, the agent fills in the TT-Lang syntax, and the structure itself eliminates most of the ambiguity that makes agent-written CUDA hallucinate. So the practical ladder for someone coming from CUDA looks like this:

1. **Let TT-Forge compile the whole model** — most of the time you stop here.
2. **Reach for TTNN ops** when you want to hand-tune a hot path in Python.
3. **Hand an agent a reader/compute/writer spec and let it write the TT-Lang** for the rare custom kernel — instead of booking an afternoon to hand-write CUDA C.

You can travel a long way down that ladder without ever becoming a full-time kernel author. When you do want to go deeper into TT-Lang yourself — the decorators, circular-buffer semantics, the browser-based simulator — that's the [TT-Lang chapter](/builder-hacker/03-ttlang-intro/) in the Builder/Hacker track.

## Setting Expectations

One more thing that won't transfer from a decade of CUDA: the assumption that the stack is finished. CUDA is twenty years mature; the TT software stack is young and moving fast. The top-tier compiler frontends in particular are still evolving — by the time you read Chapter 6 you'll see we already had to retire one PyTorch entry point in favor of TT-XLA. Expect occasional rough edges, expect the first run of a new op shape to JIT-compile for a few seconds before it caches, and expect to read the docs against the source now and then.

That's not a warning to stay away — it's the texture of working close to the edge of an open stack. The flip side is that the layers are genuinely open, the team is reachable, and unanswered questions tend to get answers. When something doesn't behave the way this guide describes, the [Tenstorrent Discord](https://discord.gg/tenstorrent) and the GitHub issue trackers are where practitioners (and TT engineers) actually work problems out.

---

**Next:** [The Model Zoo →](/ml-practitioner/02-model-zoo/)
