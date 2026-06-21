---
title: Your First Kernel
currentChapter: 02-first-kernel
permalink: /builder-hacker/02-first-kernel/
---
{% set persona = personas | findPersona(personaId) %}

# Your First Kernel

Reading about architecture is preparation. Writing code is proof. This chapter takes you from zero to a dispatched, JIT-compiled, hardware-executed kernel — using the tutorials that ship pre-installed on your QB2. You don't need to clone anything, build anything, or download anything.

## Setting Up the Environment

Everything runs inside the TTNN virtual environment. Activate it and set the required variables:

```bash
source ~/tt-metal/python_env/bin/activate
export TT_METAL_HOME=~/tt-metal
export PYTHONPATH=$TT_METAL_HOME:$PYTHONPATH
export TT_METAL_ARCH_NAME=blackhole
```

The `TT_METAL_ARCH_NAME=blackhole` variable is mandatory. Without it, the runtime defaults to Wormhole and dispatches incorrect kernel variants. The QB2 has Blackhole chips. The variable makes this explicit.

Add these exports to your `~/.bashrc` if you want them set automatically on every login:

```bash
echo 'export TT_METAL_HOME=~/tt-metal' >> ~/.bashrc
echo 'export PYTHONPATH=$TT_METAL_HOME:$PYTHONPATH' >> ~/.bashrc
echo 'export TT_METAL_ARCH_NAME=blackhole' >> ~/.bashrc
```

## Your First Run: Tensor Addition

The `ttnn_add_tensors.py` tutorial is the canonical starting point. It is short, complete, and exercises the full round-trip: host to chip to host.

```bash
python3 ~/tt-metal/ttnn/tutorials/basic_python/ttnn_add_tensors.py
```

**First run:** expect 30 to 60 seconds of compile time before any output. This is the JIT compiler building the addition kernel from LLVM IR down to Tensix assembly, then writing the binary to the kernel cache.

**Second run:** fast. The cache is warm. Recompilation only happens when kernel parameters change.

What the file does, step by step:

```python
import ttnn, torch

# 1. Open the chip — handshake through PCIe column 8
device = ttnn.open_device(device_id=0)

# 2. Create two tensors on the host
a = torch.randn(32, 32)
b = torch.randn(32, 32)

# 3. Move both to the chip (DMA transfer to DRAM)
a_tt = ttnn.from_torch(a, dtype=ttnn.bfloat16, layout=ttnn.TILE_LAYOUT, device=device)
b_tt = ttnn.from_torch(b, dtype=ttnn.bfloat16, layout=ttnn.TILE_LAYOUT, device=device)

# 4. Run the elementwise add kernel
c_tt = ttnn.add(a_tt, b_tt)

# 5. Pull the result back to host RAM
c = ttnn.to_torch(c_tt)

# 6. Close the device — flushes all pending work and releases the chip
ttnn.close_device(device)

print("Result shape:", c.shape)
```

## Tensors Become Tiles

A key conceptual shift: TTNN does not operate on individual elements. It operates on 32×32 tiles. When you pass a `(32, 32)` tensor, that's one tile. When you pass a `(64, 64)` tensor, that becomes four tiles.

The tile transformation happens automatically during `from_torch` with `layout=ttnn.TILE_LAYOUT`. You can inspect the layout:

```python
print(a_tt.layout)   # TILE_LAYOUT
print(a_tt.dtype)    # DataType.BFLOAT16
print(a_tt.shape)    # Shape([32, 32])
```

Larger tensors spread across more tiles, and those tiles get dispatched to more cores concurrently. A `(512, 512)` tensor becomes 256 tiles; the dispatch system assigns each tile to a Tensix core. The parallelism is automatic at the tile level.

{% tensixviz "blackhole", [
  {"step": "highlight", "cores": [[1,0],[2,0],[3,0],[4,0],[5,0],[6,0],[7,0],[9,0],[10,0],[11,0],[12,0],[13,0],[14,0],[15,0]], "color": "dram", "label": "DRAM row 0 — tiles for tensor A and B", "ms": 700},
  {"step": "pause", "ms": 500},
  {"step": "transfer", "from": [3,0], "to": [3,3], "ms": 500},
  {"step": "transfer", "from": [5,0], "to": [5,3], "ms": 500},
  {"step": "transfer", "from": [7,0], "to": [7,3], "ms": 500},
  {"step": "transfer", "from": [10,0], "to": [10,3], "ms": 500},
  {"step": "pause", "ms": 400},
  {"step": "highlight", "cores": [[3,3],[5,3],[7,3],[10,3]], "color": "tensixActive", "label": "Tiles dispatched to Tensix cores — reader loading L1", "ms": 700},
  {"step": "pause", "ms": 600},
  {"step": "highlight", "cores": [[3,3],[5,3],[7,3],[10,3]], "color": "teal", "label": "Compute running — FPU adding tile pairs", "ms": 700},
  {"step": "pause", "ms": 600},
  {"step": "transfer", "from": [3,3], "to": [3,11], "ms": 500},
  {"step": "transfer", "from": [5,3], "to": [5,11], "ms": 500},
  {"step": "transfer", "from": [7,3], "to": [7,11], "ms": 500},
  {"step": "transfer", "from": [10,3], "to": [10,11], "ms": 500},
  {"step": "pause", "ms": 400},
  {"step": "highlight", "cores": [[3,11],[5,11],[7,11],[10,11]], "color": "dram", "label": "Result tiles written back to DRAM row 11", "ms": 700},
  {"step": "pause", "ms": 1000},
  {"step": "clear"}
] %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">Reader → L1 → FPU → L1 → writer. The three-kernel pipeline at work.</p>

## Understanding JIT Compilation

The first run is slow for a specific reason: Metalium compiles kernels just-in-time. Here's what happens during that 60-second wait:

1. TTNN resolves the op's dtype, shape, and memory layout to a kernel variant
2. The kernel variant (C++ source) is templated with those parameters
3. LLVM compiles C++ to RISC-V assembly for the Tensix host processor
4. The Tensix-specific FPU operations are lowered to assembly for the matrix engine
5. Both binaries are written to the kernel cache at `~/.cache/ttnn/`

Subsequent calls with the same parameters skip all of this. The compiled binary is reused. If you change tensor shapes or dtypes, partial recompilation fires for the changed variants only.

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">💡</span>
<strong>Warm the cache before benchmarking.</strong> Run your kernel at least twice before measuring performance. The first run's 60-second compile overhead has nothing to do with chip throughput — it is a host-side software cost that disappears completely after the first execution.
</div>

## Matmul: Putting the FPU to Real Work

Elementwise addition barely exercises the matrix engine. Matrix multiplication does. The call is minimal:

```python
device = ttnn.open_device(device_id=0)

a = ttnn.from_torch(torch.randn(256, 256), dtype=ttnn.bfloat16,
                    layout=ttnn.TILE_LAYOUT, device=device)
b = ttnn.from_torch(torch.randn(256, 256), dtype=ttnn.bfloat16,
                    layout=ttnn.TILE_LAYOUT, device=device)

c = ttnn.matmul(a, b)
result = ttnn.to_torch(c)
print(result.shape)   # torch.Size([256, 256])

ttnn.close_device(device)
```

A `(256, 256)` matmul is 64 output tiles. The dispatch system maps those 64 output tiles to 64 compute cores, running in parallel. The reader for each core fetches the relevant row tiles from A and column tiles from B. The FPU accumulates. The writer ships results to DRAM. All of this runs concurrently across 64 Tensix cores.

## Keeping Tensors in L1

By default, tensors live in DRAM. Every op reads from DRAM and writes results to DRAM. For chained operations, this incurs unnecessary round-trips. You can pin a tensor to L1 memory instead:

```python
# Keep the tensor in L1 between ops — avoid the DRAM round-trip
a_l1 = ttnn.to_memory_config(a, ttnn.L1_MEMORY_CONFIG)
b_l1 = ttnn.to_memory_config(b, ttnn.L1_MEMORY_CONFIG)

c = ttnn.matmul(a_l1, b_l1)
```

This works when the tensor fits in L1. For large tensors it won't — DRAM is 96 GB (8 banks × 12 GB), L1 is small per-core scratchpad. Use L1 pinning for intermediate results in tight compute loops.

## Kernel Fusion: Chaining Ops

TTNN supports kernel fusion when you chain ops. The compiler detects the dependency and merges compute kernels:

```python
# These three ops may fuse into a single kernel dispatch
c = ttnn.relu(ttnn.matmul(a, b))
```

Whether fusion fires depends on shape compatibility and the current kernel fusion rules. When it fires, the reader runs once, the fused compute kernel does matmul + relu on each tile, and the writer runs once. When it doesn't fire, each op dispatches separately. The profiler tells you which happened (see [Chapter 4](/builder-hacker/04-profiling/)).

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">📚</span>
<strong>Go deeper with explore-metalium.</strong> The TT-VSCode Toolkit's <a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/explore-metalium/" style="color:var(--teal)">explore-metalium lesson</a> (30 min) walks through writing a custom kernel in TT-Metalium C++. It covers the reader/compute/writer split at the C++ level — the same model abstracted by TTNN. Run it after this chapter to see what's underneath the Python API.
</div>

<div class="video-placeholder illustrated-only">
  <strong>Coming soon: First kernel walkthrough</strong>
  Running ttnn_add_tensors.py on a live QB2 — environment activation, JIT compile, warm cache run, inspecting tile shapes.
  <!-- VIDEO: VHS recording. -->
</div>

---

**Next:** [TT-Lang Introduction →](/builder-hacker/03-ttlang-intro/)
