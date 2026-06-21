---
title: TT-Lang Introduction
currentChapter: 03-ttlang-intro
permalink: /builder-hacker/03-ttlang-intro/
---
{% set persona = personas | findPersona(personaId) %}

# TT-Lang Introduction

TTNN covers a large territory of standard ops — matmul, attention, layernorm, convolution. But ML research moves faster than op libraries. The moment you want a fusion pattern that TTNN doesn't expose, a non-standard attention variant, a custom activation function with a specific numerical property, you need to go lower. TT-Lang is that lower level, without requiring C++.

## What TT-Lang Is

TT-Lang is a Python DSL that compiles to Tensix assembly. You write Python-like syntax with decorators that declare data-movement intent. The compiler translates that intent into reader kernels, compute kernels, and writer kernels. The three-kernel model you read about in Chapter 1 becomes the explicit structure of every TT-Lang program.

The key design principle: explicit data movement. Where TTNN hides the read/compute/write split, TT-Lang exposes it as the primary vocabulary. You declare what the reader fetches from where, what compute does to tiles in registers, what the writer sends where. No implicit sharing. No hidden transfers.

This explicitness is intentional and strategic. It makes TT-Lang programs easy for AI coding agents to generate, verify, and debug — because the spec is complete in the source code. The reader section tells you exactly what arrives. The compute section is pure math on those arrivals. The writer section is exactly what leaves. No ambiguity remains.

## The Kernel Decorators

TT-Lang programs are organized around four decorators:

- `@kernel` — the outer program, declares the kernel name and grid dimensions
- `@reader` — runs on BRISC, the read NoC endpoint; fetches tiles from DRAM or another core's L1
- `@compute` — runs on the FPU; pops tiles from L1, runs the matrix engine, pushes results back to L1
- `@writer` — runs on NCRISC, the write NoC endpoint; sends tiles from L1 to a destination address

A minimal vector addition kernel in TT-Lang looks like this:

```python
from ttlang import kernel, reader, compute, writer, Tile, Buffer

@kernel(grid=(1, 1))
def vector_add(a_addr: int, b_addr: int, out_addr: int, n_tiles: int):

    @reader
    def read_inputs():
        a_buf = Buffer(src=a_addr, n_tiles=n_tiles)
        b_buf = Buffer(src=b_addr, n_tiles=n_tiles)
        for tile in range(n_tiles):
            push(a_buf[tile])   # fetch tile from DRAM into L1 circular buffer
            push(b_buf[tile])

    @compute
    def add_tiles():
        for tile in range(n_tiles):
            a_tile: Tile = pop()   # pop from L1 circular buffer into SRCA
            b_tile: Tile = pop()   # pop into SRCB
            result = a_tile + b_tile   # FPU elementwise add
            push(result)             # push result tile to L1 output buffer

    @writer
    def write_output():
        out_buf = Buffer(dst=out_addr, n_tiles=n_tiles)
        for tile in range(n_tiles):
            out_buf[tile] = pop()   # send tile from L1 to DRAM destination
```

Three functions, three processors, one core. They run concurrently. The circular buffers between them are the synchronization mechanism — `push` blocks if the buffer is full, `pop` blocks if it's empty. This backpressure propagation means the pipeline self-regulates.

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">🤖</span>
<strong>The three-kernel model maps cleanly to LLM prompting.</strong> Describe what the reader fetches (tensor shapes, dtypes, source addresses). Describe what compute does (the mathematical operation, tile count). Describe what the writer sends (destination, same tile count). An AI coding agent can fill in the exact TT-Lang syntax from that spec with high reliability. The explicit structure eliminates the ambiguity that causes hallucination in implicit GPU kernel code.
</div>

## Single-Core Data Flow

Here is what happens at the hardware level when `vector_add` runs on one Tensix core:

{% tensixviz "blackhole", [
  {"step": "highlight", "cores": [[3,0],[3,11]], "color": "dram", "label": "DRAM — tensor A and B at source addresses", "ms": 700},
  {"step": "pause", "ms": 500},
  {"step": "transfer", "from": [3,0], "to": [3,5], "ms": 600},
  {"step": "pause", "ms": 200},
  {"step": "transfer", "from": [3,11], "to": [3,5], "ms": 600},
  {"step": "pause", "ms": 400},
  {"step": "highlight", "cores": [[3,5]], "color": "pink", "label": "Reader (BRISC) loading L1 — tiles arriving from DRAM", "ms": 700},
  {"step": "pause", "ms": 500},
  {"step": "highlight", "cores": [[3,5]], "color": "tensixActive", "label": "Compute (FPU) running — popping tiles, adding, pushing results", "ms": 700},
  {"step": "pause", "ms": 600},
  {"step": "highlight", "cores": [[3,5]], "color": "teal", "label": "Writer (NCRISC) sending result tiles to DRAM", "ms": 700},
  {"step": "pause", "ms": 400},
  {"step": "transfer", "from": [3,5], "to": [3,11], "ms": 600},
  {"step": "pause", "ms": 600},
  {"step": "highlight", "cores": [[3,11]], "color": "dram", "label": "Result in DRAM at output address", "ms": 700},
  {"step": "pause", "ms": 1000},
  {"step": "clear"}
] %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">One Tensix core running all three TT-Lang sections concurrently.</p>

## TT-Lang vs TTNN: When to Use Which

They are not competing tools. They are different entry points into the same hardware, appropriate for different problems:

| Situation | Use |
|-----------|-----|
| Standard ops: matmul, attention, layernorm, conv | TTNN — highly optimized, already there |
| Custom op that TTNN doesn't expose | TT-Lang — write it in Python, no C++ required |
| Performance-critical custom fusion | TT-Metalium C++ — maximum control, no Python overhead |
| AI-agent-generated kernels | TT-Lang — explicit structure, agent-verifiable output |
| Production inference serving | TTNN via vLLM — already integrated |

The usual path: start with TTNN. When you hit a wall — a pattern that TTNN can't express, a fusion the compiler misses, a numerical property you need to enforce — drop to TT-Lang. Write the custom section in TT-Lang, combine it with TTNN for the standard sections.

## The TT-Lang Playground

You don't need a QB2 to experiment with TT-Lang. The `ttlang-sim` browser-based simulator lets you write kernels, inspect the circular buffer state, and verify correctness without hardware.

For the structured lesson with exercises and a graded environment:

**TT-Lang Introduction lesson:** [docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-lang-intro/](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-lang-intro/) — 25 minutes, covers all four decorators, circular buffer semantics, and a complete vector add + elementwise multiply walkthrough.

The lesson runs inside VS Code with the TT-VSCode Toolkit extension. It uses a local simulator so compilation is instant. After the lesson, running the same kernel on QB2 hardware is a one-line change.

<div class="callout callout--deep-dive">
<span class="callout-icon illustrated-only">🔬</span>
<strong>Circular buffers as the memory model.</strong> The L1 SRAM between reader and compute, and between compute and writer, is organized as circular buffers — fixed-size ring structures. When the reader fills the ring, it stalls until compute consumes. When compute fills the output ring, it stalls until the writer drains. This backpressure propagation is how three concurrent programs stay synchronized without explicit locks. The hardware implements the buffer arbitration; you just see push and pop. Understanding this explains why tile count and L1 size set the performance envelope: a kernel that fully pipelines needs at least two tiles in each buffer simultaneously.
</div>

---

**Next:** [Profiling & Optimization →](/builder-hacker/04-profiling/)
