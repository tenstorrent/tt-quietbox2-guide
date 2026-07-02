---
title: What Comes Next
currentChapter: 06-what-comes-next
permalink: /first-timer/06-what-comes-next/
---
{% set persona = personas | findPersona(personaId) %}

# What Comes Next

You unboxed a machine that most people have never touched. You confirmed four Blackhole chips were alive and talking to the system. You navigated Python environments that would trip up someone who wasn't paying attention. You ran a model on accelerator hardware and watched tokens come back. That's not a tutorial warmup — that's the actual thing.

The rest is up to you.

<img src="/assets/illustrations/inference-stack.svg" class="spot-illustration" alt="Inference stack diagram showing the path from user interfaces through tt-inference-server and vLLM down to four Blackhole chips" style="max-width:100%; margin: 2em 0;">

## Tools in Your World

The QB2 ships with a full stack, but the ecosystem is bigger. Start with **tt-toplike** — `htop` for your chips, except the telemetry comes alive as ASCII art:

<figure class="video-demo">
<img src="/assets/video/tt-toplike-insights.gif" alt="tt-toplike insights mode — live ASCII visualization of all four Blackhole chips during inference" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">tt-toplike insights mode — all four Blackhole chips under live inference, power and DRAM state rendered in real time</figcaption>
</figure>

<div class="rcard-grid">

{% card "repo", "https://github.com/tenstorrent/tt-toplike", "tt-toplike", "Real-time hardware monitor — htop for your chips: temps, power, utilization, DRAM bandwidth, live in the terminal.", "cargo install tt-toplike · .deb on Releases" %}

{% card "repo", "https://github.com/tenstorrent/tt-studio", "tt-studio", "Web UI for model serving. Pick a model, click Run, get tokens — and as of v2.8.0 it can back Claude Code / OpenCode and generate video and images too.", "tt-studio → localhost:3000" %}

{% card "site", "https://docs.tenstorrent.com/tt-local-generator", "tt-local-generator", "GTK4 desktop app for video, image, and art generation on QB2, on top of tt-inference-server.", "tt-local-generator" %}

{% card "repo", "https://github.com/tenstorrent/tt-inference-server", "tt-inference-server", "Docker-based one-command model deployment — the OpenAI-compatible server tt-studio and tt-local-generator route through.", "" %}

{% card "site", "https://docs.tenstorrent.com/tt-vscode-toolkit", "tt-vscode-toolkit", "VS Code extension with 40+ interactive lessons that run directly against your QB2.", "" %}

{% card "site", "https://tenstorrent.github.io/tt-awesome/", "tt-awesome", "Community catalog of everything built on Tenstorrent hardware — models, demos, benchmarks, research.", "" %}

</div>

## Where to Go From Here

Pick a thing you want to do and jump straight in.

<div class="rcard-grid">

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/vllm-production/", "Production Inference with vLLM", "Serve a model behind an OpenAI-compatible API.", "30 min" %}

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-inference-server/", "TT-Inference-Server", "Run Llama-3.1-8B with one command.", "20 min" %}

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/interactive-chat/", "Interactive Chat", "Chat with an LLM directly in Python.", "20 min" %}

{% card "lesson", "/lessons/llama-70b/", "Running Llama-3.3-70B on QB2", "Run the biggest model QB2 supports, across all four chips.", "45 min" %}

{% card "lesson", "/ml-practitioner/03-vllm-on-qb2/", "Claude Code on your QB2", "New in tt-studio v2.8.0 — point Claude Code or OpenCode at a model running on your own chips. No cloud, no per-token bill.", "coding agents" %}

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/qb2-local-agents/", "Local AI Agents on QB2", "Run AI agents locally on a 70B model.", "60 min" %}

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/qb2-video-generation/", "QB2 Video Generation", "Generate video on your QB2.", "45 min" %}

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/explore-metalium/", "Explore TT-Metalium", "Build kernels from scratch on the Tensix cores.", "open-ended" %}

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/cookbook-overview/", "Cookbook Overview", "Write cookbook-style parallel algorithms.", "varies" %}

</div>

## Choose Your Next Track

<div style="display:grid; gap:16px; margin: 2em 0;">

<a href="/ml-practitioner/" style="display:block; background:var(--bg1); border-left:3px solid var(--pink); padding:16px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="color:var(--pink);font-weight:700;margin-bottom:4px;">Run & build →</div>
  <div style="font-size:13px;color:var(--text2);">Serve real models. Understand performance. Integrate with your existing ML workflow. If you're coming from CUDA, this is where the familiar parts live and where the new parts pay off.</div>
</a>

<a href="/builder-hacker/" style="display:block; background:var(--bg1); border-left:3px solid var(--gold); padding:16px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="color:var(--gold);font-weight:700;margin-bottom:4px;">Tinker →</div>
  <div style="font-size:13px;color:var(--text2);">Write code that runs on the chips directly — kernels, data movement, compute pipelines. The architecture goes all the way down and you can follow it.</div>
</a>

<a href="/tinkerer/" style="display:block; background:var(--bg1); border-left:3px solid var(--green); padding:16px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="color:var(--green);font-weight:700;margin-bottom:4px;">Customize →</div>
  <div style="font-size:13px;color:var(--text2);">Customize, illuminate, break, and fix things. The LEDs, the desktop, the demos that make people stop and ask what that machine is.</div>
</a>

</div>

The QB2 is a beginning. There's a lot of surface area here, and you've only scratched it.

---

**[← Back to Explore](/first-timer/)**
