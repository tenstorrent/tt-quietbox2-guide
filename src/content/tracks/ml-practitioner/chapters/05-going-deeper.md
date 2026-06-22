---
title: Going Deeper
currentChapter: 05-going-deeper
permalink: /ml-practitioner/05-going-deeper/
---
{% set persona = personas | findPersona(personaId) %}

# Going Deeper

You've rerouted the mental model, picked a model that fits the hardware, stood up a production inference server, and watched the hardware breathe through prefill and decode. That's the ML Practitioner track done. What it opens up is considerably larger.

## Interactive Lessons in tt-vscode-toolkit

The VS Code extension ships lessons that run against your QB2 directly — not simulated, not mocked. Real inference, real hardware feedback, real timing numbers. Each lesson is a structured walkthrough with code cells you execute against the machine.

<div style="display:grid; gap:12px; margin: 1.5em 0;">

<a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/vllm-production/" style="display:block; background:var(--bg1); border-left:3px solid var(--pink); padding:16px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="display:flex; align-items:baseline; gap:12px;">
    <span style="color:var(--pink); font-weight:700;">Production Inference with vLLM</span>
    <span style="font-size:11px; color:var(--muted); margin-left:auto;">30 min</span>
  </div>
  <div style="font-size:13px; color:var(--text2); margin-top:4px;">Multi-user load testing, request queuing, continuous batching mechanics, latency vs. throughput tradeoff measurement on live hardware.</div>
</a>

<a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-inference-server/" style="display:block; background:var(--bg1); border-left:3px solid var(--pink); padding:16px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="display:flex; align-items:baseline; gap:12px;">
    <span style="color:var(--pink); font-weight:700;">TT-Inference-Server</span>
    <span style="font-size:11px; color:var(--muted); margin-left:auto;">20 min</span>
  </div>
  <div style="font-size:13px; color:var(--text2); margin-top:4px;">Docker-based one-command deploy. Model switching. Container lifecycle management. The path from development to something you'd actually run in production.</div>
</a>

<a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/explore-metalium/" style="display:block; background:var(--bg1); border-left:3px solid var(--pink); padding:16px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="display:flex; align-items:baseline; gap:12px;">
    <span style="color:var(--pink); font-weight:700;">Explore TT-Metalium</span>
    <span style="font-size:11px; color:var(--muted); margin-left:auto;">open-ended</span>
  </div>
  <div style="font-size:13px; color:var(--text2); margin-top:4px;">The layer below TTNN. How Metalium kernels are written, compiled, and dispatched. How NoC routing works in practice. How the tensor parallel AllReduce crosses chip boundaries without touching the host CPU.</div>
</a>

<a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/cookbook-overview/" style="display:block; background:var(--bg1); border-left:3px solid var(--pink); padding:16px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="display:flex; align-items:baseline; gap:12px;">
    <span style="color:var(--pink); font-weight:700;">Cookbook Overview</span>
    <span style="font-size:11px; color:var(--muted); margin-left:auto;">varies</span>
  </div>
  <div style="font-size:13px; color:var(--text2); margin-top:4px;">Parallel algorithm patterns for Tensix. Matrix multiply, convolution, attention, and more — written at the TTNN level with performance notes for Blackhole.</div>
</a>

</div>

## Three Things to Try Next

**Run a 70B model with 4-chip tensor parallel.** You have four chips. Llama-3.1-70B-Instruct fits. Download the weights (140 GB — plan ahead), start vLLM with `--tensor-parallel-size 4`, and run a request that would be genuinely difficult to answer. Watch the aiclk and power numbers on all four chips via `tt-smi -s` as the response generates. The hardware doing real work looks different from the hardware doing toy work.

**Build a Python application against the OpenAI-compatible API.** The server is running on localhost:8000. The OpenAI SDK works unchanged. Take something you've built against `api.openai.com` — a chatbot, a summarizer, a classification pipeline — and point it at your QB2. Measure the latency. Compare the cost per token. This is where the practical value of local inference becomes tangible rather than theoretical.

**Take the Builder/Hacker track.** The ML Practitioner track ends at the TTNN surface. The Builder/Hacker track goes below it: Metalium kernels, NoC data movement, dispatch programming, the full architecture exposure. If you've ever wanted to understand how a matmul actually runs on silicon — not the math, the execution — that track is the path.

## Community and Further Reading

<div style="display:grid; gap:12px; margin: 1.5em 0;">

<a href="https://docs.tenstorrent.com/tt-toplike" style="display:block; background:var(--bg1); border-left:3px solid var(--teal); padding:14px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="color:var(--teal); font-weight:700; margin-bottom:3px;">tt-toplike docs</div>
  <div style="font-size:13px; color:var(--text2);">Full reference for every mode and metric. Understand what the numbers mean and what actions they suggest.</div>
</a>

<a href="https://tenstorrent.github.io/tt-awesome/" style="display:block; background:var(--bg1); border-left:3px solid var(--teal); padding:14px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="color:var(--teal); font-weight:700; margin-bottom:3px;">tt-awesome</div>
  <div style="font-size:13px; color:var(--text2);">Community catalog of everything built on Tenstorrent hardware. Models, benchmarks, integrations, demos. If someone has run it on a Blackhole, it shows up here.</div>
</a>

</div>

## Choose Your Next Track

<div style="display:grid; gap:16px; margin: 2em 0;">

<a href="/builder-hacker/" style="display:block; background:var(--bg1); border-left:3px solid var(--gold); padding:16px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="color:var(--gold); font-weight:700; margin-bottom:4px;">Builder / Hacker →</div>
  <div style="font-size:13px; color:var(--text2);">Write code that runs directly on the Tensix cores. Metalium kernels, NoC data movement, compute pipelines from scratch. The architecture goes all the way down — this track follows it.</div>
</a>

<a href="/tinkerer/" style="display:block; background:var(--bg1); border-left:3px solid var(--green); padding:16px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="color:var(--green); font-weight:700; margin-bottom:4px;">Curious Tinkerer →</div>
  <div style="font-size:13px; color:var(--text2);">Customize, illuminate, and demo the machine. The LEDs, the desktop setup, the demos that make people stop and ask what that thing is running.</div>
</a>

</div>

You ran serious inference on serious hardware and you understand why it works the way it does. That's a meaningful thing to know. The QB2 is a beginning, and you've got your bearings.

---

[← Performance Tuning](/ml-practitioner/04-performance-tuning/) | [TT-Forge: Compile Anything →](/ml-practitioner/06-tt-forge/)
