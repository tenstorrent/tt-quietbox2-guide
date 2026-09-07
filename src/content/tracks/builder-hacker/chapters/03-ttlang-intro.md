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

TT-Lang programs are organized around the `ttl` module's decorators — verified against the
real, installed package (`import ttl; dir(ttl)` on a QB2's `~/.tenstorrent-venv`) rather than
assumed:

- `@ttl.operation(grid=...)` — the outer program; `grid="auto"` lets the compiler size it
- `@ttl.compute()` — runs on the FPU; consumes filled dataflow buffers, does the math, fills the output buffer
- `@ttl.datamovement()` — runs on a data-movement RISC core; there's one decorator for both directions, not separate reader/writer ones — a function's *role* (producer vs. consumer) comes from whether it calls `.reserve()` (fill a slot) or `.wait()` (drain a slot) on a given buffer, not from its decorator

A minimal vector addition kernel in TT-Lang looks like this:

```python
import ttl
import ttnn

TILE_SIZE = 32

@ttl.operation(grid="auto")
def eltwise_add(a_in: ttnn.Tensor, b_in: ttnn.Tensor, out: ttnn.Tensor) -> None:
    row_tiles = a_in.shape[0] // TILE_SIZE
    col_tiles = a_in.shape[1] // TILE_SIZE

    # Typed ring buffers — one slot per tile, depth 2 (double-buffer)
    a_dfb = ttl.make_dataflow_buffer_like(a_in, shape=(1, 1), block_count=2)
    b_dfb = ttl.make_dataflow_buffer_like(b_in, shape=(1, 1), block_count=2)
    out_dfb = ttl.make_dataflow_buffer_like(out, shape=(1, 1), block_count=2)

    @ttl.compute()
    def compute():
        for row in range(row_tiles):
            for col in range(col_tiles):
                with a_dfb.wait() as a_blk, b_dfb.wait() as b_blk, out_dfb.reserve() as o_blk:
                    o_blk.store(a_blk + b_blk)   # element-wise add in L1

    @ttl.datamovement()
    def read():
        for row in range(row_tiles):
            for col in range(col_tiles):
                with a_dfb.reserve() as a_blk, b_dfb.reserve() as b_blk:
                    ttl.copy(a_in[row:row+1, col:col+1], a_blk).wait()
                    ttl.copy(b_in[row:row+1, col:col+1], b_blk).wait()

    @ttl.datamovement()
    def write():
        for row in range(row_tiles):
            for col in range(col_tiles):
                with out_dfb.wait() as o_blk:
                    ttl.copy(o_blk, out[row:row+1, col:col+1]).wait()
```

Three functions, three processors, one core. They run concurrently. The dataflow buffers
between them are the synchronization mechanism — `reserve()` blocks until a slot is free to
fill, `wait()` blocks until a slot is filled and ready to drain. This backpressure propagation
means the pipeline self-regulates. Every tile makes one DRAM read (`read`) and one DRAM write
(`write`); the `+` happens entirely in L1, inside `compute`.

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

<div class="rcard-grid">

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-lang-intro/", "TT-Lang Introduction", "Covers ttl.operation/compute/datamovement, dataflow-buffer semantics, and a complete vector add + elementwise multiply walkthrough.", "25 min" %}

</div>

The lesson runs inside VS Code with the TT-VSCode Toolkit extension. It uses a local simulator so compilation is instant. After the lesson, running the same kernel on QB2 hardware is a one-line change.

<div class="callout callout--deep-dive">
<span class="callout-icon illustrated-only">🔬</span>
<strong>Dataflow buffers as the memory model.</strong> The L1 SRAM between the <code>read</code> data-movement function and <code>compute</code>, and between <code>compute</code> and <code>write</code>, is organized as dataflow buffers (DFBs) — fixed-size ring structures, made with <code>ttl.make_dataflow_buffer_like()</code>. When a producer fills a slot (<code>.reserve()</code>), it stalls until a consumer drains one (<code>.wait()</code>) if the ring is full. This backpressure propagation is how three concurrent functions stay synchronized without explicit locks. The hardware implements the buffer arbitration; you just see <code>reserve()</code> and <code>wait()</code>. Understanding this explains why tile count and L1 size set the performance envelope: a kernel that fully pipelines needs at least two blocks in each buffer simultaneously — hence <code>block_count=2</code> above.
</div>

---

**Next:** [Profiling & Optimization →](/builder-hacker/04-profiling/)
