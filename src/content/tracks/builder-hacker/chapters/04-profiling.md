---
title: Profiling & Optimization
currentChapter: 04-profiling
permalink: /builder-hacker/04-profiling/
---
{% set persona = personas | findPersona(personaId) %}

# Profiling & Optimization

A kernel that runs is not necessarily a kernel that runs well. The Blackhole chip has 120 enabled Tensix cores per chip and 480 across your four-chip QB2. If your kernel is using 12 of them, the other 468 are idle and the machine is waiting. Profiling tells you which case you're in.

## tt-toplike: Your Primary Monitoring Tool

While your kernel runs, run `tt-toplike` in a second terminal. It is the most direct window into what the chip is doing right now.

```bash
# Open a second terminal, then:
tt-toplike --mode starfield
```

In starfield mode, each star represents a chip. Brightness is proportional to power draw, which correlates with active compute. A bright, dense star field means cores are working. A dim star means most cores are idle.

Switch modes for different views:

```bash
tt-toplike --mode flow        # NOC traffic visualization — data movement patterns
tt-toplike --mode arcade      # per-core utilization as a game-style display
tt-toplike --mode castle      # stacked bar view, useful for multi-chip comparisons
```

Leave `flow` mode running while you tune a kernel for DRAM bandwidth. The NOC traffic pattern tells you whether data is moving in a spread-out mesh pattern (good: parallel fetch from multiple DRAM banks) or a narrow column (bad: serial bottleneck).

## tt-smi Snapshots

For point-in-time metrics in JSON format, use `tt-smi -s`. This is safe to pipe, parse, and log:

```bash
tt-smi -s
```

The output includes per-chip:
- `aiclk` — current clock frequency in MHz (Blackhole target: ~1000-1200 MHz under load)
- `power` — board power in watts
- `asic_temperature` — ASIC die temperature in °C
- `voltage` — core voltage

Temperature bands to know:

| Range | State |
|-------|-------|
| 40–60°C | Idle / light load — normal |
| 60–80°C | Sustained load — normal, expected during inference |
| 80–90°C | High load — fans at full speed, performance still normal |
| >90°C | Throttle zone — aiclk drops automatically to protect the chip |

If `tt-smi -s` shows `aiclk` significantly below spec during a compute-heavy run, thermal throttling is occurring. Check airflow around the QB2, confirm the fans are unobstructed, and check ambient temperature.

## TTNN Op Profiling

For per-operation timing at the Python level, TTNN exposes a profiler API:

```python
import ttnn

device = ttnn.open_device(device_id=0)

# Enable profiling
ttnn.experimental.profiler.start(device)

# ... your ops here ...
a = ttnn.from_torch(...)
b = ttnn.from_torch(...)
c = ttnn.matmul(a, b)

# Capture the trace
ttnn.experimental.profiler.stop(device)
report = ttnn.experimental.profiler.get_report(device)

for op in report:
    print(f"{op['name']:40s}  {op['duration_us']:8.1f} µs")

ttnn.close_device(device)
```

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">📖</span>
The profiler API surface is evolving. Check the current function signatures in the TTNN docs at <a href="https://docs.tenstorrent.com" style="color:var(--teal)">docs.tenstorrent.com</a> and the cookbook-overview lesson at <a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/cookbook-overview/" style="color:var(--teal)">docs.tenstorrent.com/tt-vscode-toolkit/lessons/cookbook-overview/</a> — the lesson includes runnable profiling examples updated for the current API.
</div>

## What the Numbers Mean

The profiler report gives you op-level durations. Here's how to interpret the patterns:

**DRAM bandwidth bottleneck:** Your matmul shows kernel dispatch time far below theoretical, but actual throughput is slow. The FPU is fast; the bottleneck is feeding it. Solution: increase L1 reuse with `ttnn.to_memory_config(t, ttnn.L1_MEMORY_CONFIG)` for intermediate tensors, or increase tile size so each DRAM fetch covers more compute.

**Core underutilization:** A large fraction of dispatch time is kernel launch overhead rather than compute. This means you have many small tiles dispatched serially. Solution: increase tensor dimensions (more tiles, more parallel cores) or batch multiple inputs together.

**aiclk drops during profiling:** Thermal throttling. The profiler timestamps are wall-clock accurate, but the kernel is running slower than its rated frequency. Fix the thermal situation before optimizing the kernel.

**Kernel fusion mismatch:** You expected `relu(matmul(a, b))` to fuse but the profiler shows two separate dispatches. Check that both tensors have compatible memory configs and dtypes — fusion won't fire across memory config mismatches.

## Utilization: Sparse vs Dense

The visual version of the profiling story is utilization — how many cores are active at once:

{% tensixviz "blackhole", [
  {"step": "highlight", "cores": [[2,2],[2,3],[5,7],[9,4],[14,8]], "color": "teal", "label": "Sparse utilization — 5 active cores out of 120. Most of the chip is idle.", "ms": 900},
  {"step": "pause", "ms": 1200},
  {"step": "unhighlight"},
  {"step": "highlight", "cores": [[1,1],[2,1],[3,1],[4,1],[5,1],[6,1],[7,1],[9,1],[10,1],[11,1],[12,1],[13,1],[14,1],[15,1],[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[7,2],[9,2],[10,2],[11,2],[12,2],[13,2],[14,2],[15,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3],[9,3],[10,3],[11,3],[12,3],[13,3],[14,3],[15,3],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4],[9,4],[10,4],[11,4],[12,4],[13,4],[14,4],[15,4],[1,5],[2,5],[3,5],[4,5],[5,5],[6,5],[7,5],[9,5],[10,5],[11,5],[12,5],[13,5],[14,5],[15,5],[1,6],[2,6],[3,6],[4,6],[5,6],[6,6],[7,6],[9,6],[10,6],[11,6],[12,6],[13,6],[14,6],[15,6],[1,7],[2,7],[3,7],[4,7],[5,7],[6,7],[7,7],[9,7],[10,7],[11,7],[12,7],[13,7],[14,7],[15,7],[1,8],[2,8],[3,8],[4,8],[5,8],[6,8],[7,8],[9,8],[10,8],[11,8],[12,8],[13,8],[14,8],[15,8],[1,9],[2,9],[3,9],[4,9],[5,9],[6,9],[7,9],[9,9],[10,9],[11,9],[12,9],[13,9],[14,9],[15,9],[1,10],[2,10],[3,10],[4,10],[5,10],[6,10],[7,10],[9,10],[10,10],[11,10],[12,10],[13,10],[14,10],[15,10]], "color": "tensixActive", "label": "Dense utilization — all 120 cores active. This is what you want.", "ms": 900},
  {"step": "pause", "ms": 1500},
  {"step": "clear"}
] %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">Sparse = parallelism opportunity. Dense = machine at work.</p>

## Tiling Strategy

The 32×32 tile size is fixed by hardware. But the number of tiles in flight, and how they map to cores, is under your control through tensor dimensions and batch size.

**Larger input tensors** mean more tiles, more core parallelism, better amortization of kernel launch overhead. A single `(32, 32)` matmul uses one output core. A `(1024, 1024)` matmul uses 1024 output cores.

**Larger batch sizes** mean more independent inputs processed simultaneously. Each input in a batch can be dispatched to a different set of cores. Throughput increases linearly until you run out of cores or L1 capacity.

The tradeoff: larger batches increase first-token latency. The chip has to buffer the full batch before returning any result. For interactive latency, keep batches small. For throughput benchmarks, fill the chip.

## The Optimization Loop

A practical profiling workflow for a new kernel:

1. Run the kernel once to warm the JIT cache
2. Run `tt-smi -s` to check thermal baseline
3. Start `tt-toplike --mode flow` in a second terminal
4. Run the kernel with the profiler enabled
5. Find the longest op in the profiler report
6. Check its utilization in `tt-toplike` — sparse means increase batch or tensor size; dense with slow throughput means DRAM bandwidth is the limit
7. Adjust one variable, re-run, compare durations

Do not optimize what you haven't measured. The chip's actual bottleneck is rarely the one you'd guess from first principles.

<div class="callout callout--deep-dive">
<span class="callout-icon illustrated-only">🔬</span>
<strong>Full performance analysis requires building from source.</strong> The deepest profiling — per-kernel cycle counts, NOC link utilization per hop, RISC-V instruction traces — requires the TT-Metal source tree and the perf tooling that builds with it. The <a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/build-tt-metal/" style="color:var(--teal)">build-tt-metal lesson</a> (60 min) covers building from source on the QB2. The source-built tools expose profiling capabilities that the pre-built environment doesn't include.
</div>

<div class="rcard-grid">

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/build-tt-metal/", "build-tt-metal", "Build TT-Metal from source on the QB2 — source-built perf tooling exposes per-kernel cycle counts, NOC link utilization, and RISC-V instruction traces.", "60 min" %}

</div>

---

**Next:** [Going Deep →](/builder-hacker/05-going-deep/)
