---
title: Going Deep
currentChapter: 05-going-deep
permalink: /builder-hacker/05-going-deep/
---
{% set persona = personas | findPersona(personaId) %}

# Going Deep

You've seen the architecture, dispatched a kernel, written a TT-Lang program, and read a profiler report. The surface area ahead is larger than any guide can cover in full. This chapter points you at the productive edges of that surface — the things worth building toward.

## Next Lessons

These four structured lessons continue from where this track ends. They are interactive, run inside VS Code with the TT-VSCode Toolkit, and include real code you run on your QB2:

| Lesson | Duration | What you'll do |
|--------|----------|----------------|
| [explore-metalium](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/explore-metalium/) | 30 min | Write a custom kernel in TT-Metalium C++ — the three-kernel model at the C++ API level, explicit circular buffer management, kernel dispatch |
| [tt-lang-intro](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-lang-intro/) | 25 min | Full TT-Lang walkthrough — decorators, circular buffers, vector add, elementwise multiply, running on hardware |
| [cookbook-overview](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/cookbook-overview/) | varies | TTNN op cookbook — attention, layernorm, convolution patterns; profiling included |
| [build-tt-metal](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/build-tt-metal/) | 60 min | Build TT-Metal from source on QB2 — unlocks perf tooling, kernel modification, the full source tree |

Build `tt-metal` from source if you're serious about optimization. The pre-built environment is a complete API surface; the source-built environment adds per-cycle profiling, kernel modification, and the ability to send patches upstream.

## Projects Worth Building

**Custom attention variant in TT-Lang.** Standard multi-head attention is in TTNN. But sliding window attention, linear attention, grouped-query attention with non-standard head dimensions, or a custom masking pattern — these require a TT-Lang kernel. Write the attention kernel using the `@reader/@compute/@writer` structure. The reader fetches Q, K, V tile blocks. The compute section runs the tile-level matmul and softmax. The writer ships results. The explicit tile arithmetic forces you to understand exactly what attention is doing at the register level.

**Profile a TTNN cookbook pattern end-to-end.** Pick any TTNN recipe from the cookbook-overview lesson — a transformer block, a convolution layer, an embedding lookup. Run it on QB2 with the profiler enabled. Find the bottleneck op. Try to shrink it: L1 memory configs, batch size changes, dtype changes. Document the before-and-after numbers. This produces a reusable reference for the specific pattern on Blackhole hardware.

**Explore tt-awesome.** The community kernel repository at [github.com/tenstorrent/tt-awesome](https://github.com/tenstorrent/tt-awesome) collects implementations, benchmarks, and examples contributed by the Tenstorrent community. It is the fastest way to see what other builders are doing on the same hardware. Read a kernel you didn't write, run it, profile it, try to improve it.

## tt-toplike as a Permanent Companion

Keep `tt-toplike` running in a tmux pane during all development. The modes give you different lenses on the same hardware:

```bash
# Split your tmux: kernel in the top pane, monitoring below
tmux split-window -v 'tt-toplike --mode flow'
```

When you dispatch a new kernel and the starfield or flow display changes noticeably, you know the chip responded. When you make an optimization change and the display looks the same, the optimization may not have landed the way you thought. The visual feedback is faster than reading profiler output for qualitative iteration.

## The Other Tracks

This track focused on kernel writing and architecture. Two other paths cover complementary territory:

<div style="display:flex;gap:16px;margin:1.5em 0;flex-wrap:wrap;">
  <a href="/ml-practitioner/" style="flex:1;min-width:220px;display:block;padding:16px;background:var(--bg1);border-radius:var(--radius);text-decoration:none;border-left:3px solid #81E6D9;">
    <div style="font-size:10px;letter-spacing:1.8px;text-transform:uppercase;color:var(--muted);margin-bottom:6px;">Track</div>
    <div style="font-weight:700;color:var(--text);margin-bottom:6px;">Run & build</div>
    <div style="font-size:12px;color:var(--text2);">Model deployment, multi-chip inference, production patterns. Start here if your goal is running large models efficiently rather than writing kernels.</div>
  </a>
  <a href="/tinkerer/" style="flex:1;min-width:220px;display:block;padding:16px;background:var(--bg1);border-radius:var(--radius);text-decoration:none;border-left:3px solid #EC96B8;">
    <div style="font-size:10px;letter-spacing:1.8px;text-transform:uppercase;color:var(--muted);margin-bottom:6px;">Track</div>
    <div style="font-weight:700;color:var(--text);margin-bottom:6px;">Customize</div>
    <div style="font-size:12px;color:var(--text2);">Hardware exploration, monitoring tools, system-level curiosity. If you want to understand the physical machine before you program it, that track comes first.</div>
  </a>
</div>

## The Abstraction Goes All the Way Down

The thing worth remembering is this: every layer of the TT-Metal stack is real and reachable. TTNN is not a black box above a black box. TT-Lang compiles to assembly you can disassemble. The three-kernel model maps to three RISC-V programs running on three processors embedded in each Tensix core. The NoC is a real two-dimensional mesh and you can observe individual links. The DRAM banks are physical rows on the chip grid and you can pin data to specific banks.

Most tools hide the machine. This one doesn't. The abstraction stack is a ladder, not a ceiling. Climb as far as the problem requires.

---

[← Profiling & Optimization](/builder-hacker/04-profiling/) | [TT-Forge: The Compiler Pipeline →](/builder-hacker/06-tt-forge-compiler/)
