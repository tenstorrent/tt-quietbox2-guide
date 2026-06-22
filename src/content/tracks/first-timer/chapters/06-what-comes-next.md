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

The QB2 ships with a full stack, but the ecosystem is bigger. Here's what's available and where to find it.

<div style="display:grid; gap:12px; margin: 1.5em 0;">

<div style="background:var(--bg1); border-left:3px solid var(--teal); padding:16px; border-radius:var(--radius);">
  <div style="color:var(--teal); font-weight:700; margin-bottom:4px;"><a href="https://docs.tenstorrent.com/tt-toplike" style="color:inherit; text-decoration:none;">tt-toplike</a></div>
  <div style="font-size:13px; color:var(--text2); margin-bottom:6px;">Real-time hardware monitor — htop for your chips. Chip temps, power, utilization, DRAM bandwidth. Runs in the terminal, updates live.</div>
  <code style="font-size:12px; color:var(--muted);">cargo install tt-toplike</code>
  <span style="color:var(--muted); font-size:12px;">  or download the <a href="https://github.com/tenstorrent/tt-toplike/releases" style="color:var(--muted);">.deb from GitHub releases</a> (not in the apt PPA)</span>
</div>

<div style="background:var(--bg1); border-left:3px solid var(--teal); padding:16px; border-radius:var(--radius);">
  <div style="color:var(--teal); font-weight:700; margin-bottom:4px;"><a href="https://github.com/tenstorrent/tt-studio" style="color:inherit; text-decoration:none;">tt-studio</a></div>
  <div style="font-size:13px; color:var(--text2); margin-bottom:6px;">Web UI for model serving. Pick a model, click Run, get tokens. Handles the Docker container and compilation automatically.</div>
  <code style="font-size:12px; color:var(--muted);">tt-studio</code>
  <span style="color:var(--muted); font-size:12px;">  →  </span>
  <code style="font-size:12px; color:var(--muted);">http://localhost:3000</code>
</div>

<div style="background:var(--bg1); border-left:3px solid var(--teal); padding:16px; border-radius:var(--radius);">
  <div style="color:var(--teal); font-weight:700; margin-bottom:4px;"><a href="https://docs.tenstorrent.com/tt-local-generator" style="color:inherit; text-decoration:none;">tt-local-generator</a></div>
  <div style="font-size:13px; color:var(--text2); margin-bottom:6px;">GTK4 desktop app for video generation, image generation, and art on QB2. Uses tt-inference-server for diffusion models and a local prompt server for LLM-based prompt polishing.</div>
  <code style="font-size:12px; color:var(--muted);">tt-local-generator</code>
</div>

<div style="background:var(--bg1); border-left:3px solid var(--teal); padding:16px; border-radius:var(--radius);">
  <div style="color:var(--teal); font-weight:700; margin-bottom:4px;"><a href="https://github.com/tenstorrent/tt-inference-server" style="color:inherit; text-decoration:none;">tt-inference-server</a></div>
  <div style="font-size:13px; color:var(--text2); margin-bottom:6px;">Docker-based one-command model deployment. The server that tt-studio and tt-local-generator both route through. Run it directly to get a fully OpenAI-compatible HTTP API on port 8000.</div>
  <code style="font-size:12px; color:var(--muted);">https://github.com/tenstorrent/tt-inference-server</code>
</div>

<div style="background:var(--bg1); border-left:3px solid var(--teal); padding:16px; border-radius:var(--radius);">
  <div style="color:var(--teal); font-weight:700; margin-bottom:4px;"><a href="https://docs.tenstorrent.com/tt-vscode-toolkit" style="color:inherit; text-decoration:none;">tt-vscode-toolkit</a></div>
  <div style="font-size:13px; color:var(--text2); margin-bottom:6px;">VS Code extension with 40+ interactive lessons that run directly against your QB2. Guided walkthroughs for inference, kernel writing, performance tuning, and multi-chip workloads.</div>
  <code style="font-size:12px; color:var(--muted);">https://docs.tenstorrent.com/tt-vscode-toolkit</code>
</div>

<div style="background:var(--bg1); border-left:3px solid var(--teal); padding:16px; border-radius:var(--radius);">
  <div style="color:var(--teal); font-weight:700; margin-bottom:4px;"><a href="https://tenstorrent.github.io/tt-awesome/" style="color:inherit; text-decoration:none;">tt-awesome</a></div>
  <div style="font-size:13px; color:var(--text2); margin-bottom:6px;">Community catalog of everything built on Tenstorrent hardware — models, demos, benchmarks, integrations, research projects. If someone has done it, it's in here.</div>
  <code style="font-size:12px; color:var(--muted);">https://tenstorrent.github.io/tt-awesome/</code>
</div>

</div>

## Where to Go From Here

Pick a specific thing you want to do and follow the link directly.

<div style="margin: 1.5em 0; overflow-x:auto;">
<table style="width:100%; border-collapse:collapse; font-size:13px;">
<thead>
<tr style="border-bottom:1px solid rgba(79,209,197,0.2);">
  <th style="text-align:left; padding:8px 12px; color:var(--muted); font-weight:600;">If you want to...</th>
  <th style="text-align:left; padding:8px 12px; color:var(--muted); font-weight:600;">Go here</th>
  <th style="text-align:left; padding:8px 12px; color:var(--muted); font-weight:600;">Time</th>
</tr>
</thead>
<tbody>
<tr style="border-bottom:1px solid rgba(79,209,197,0.07);">
  <td style="padding:8px 12px; color:var(--text2);">Serve a model with an OpenAI-compatible API</td>
  <td style="padding:8px 12px;"><a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/vllm-production/">Production Inference with vLLM</a></td>
  <td style="padding:8px 12px; color:var(--muted);">30 min</td>
</tr>
<tr style="border-bottom:1px solid rgba(79,209,197,0.07);">
  <td style="padding:8px 12px; color:var(--text2);">Run Llama-3.1-8B with one command</td>
  <td style="padding:8px 12px;"><a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-inference-server/">TT-Inference-Server</a></td>
  <td style="padding:8px 12px; color:var(--muted);">20 min</td>
</tr>
<tr style="border-bottom:1px solid rgba(79,209,197,0.07);">
  <td style="padding:8px 12px; color:var(--text2);">Chat with an LLM directly in Python</td>
  <td style="padding:8px 12px;"><a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/interactive-chat/">Interactive Chat</a></td>
  <td style="padding:8px 12px; color:var(--muted);">20 min</td>
</tr>
<tr style="border-bottom:1px solid rgba(79,209,197,0.07);">
  <td style="padding:8px 12px; color:var(--text2);">Run Llama-3.3-70B locally (the biggest model QB2 supports)</td>
  <td style="padding:8px 12px;"><a href="/lessons/llama-70b/">Running Llama-3.3-70B on QB2</a></td>
  <td style="padding:8px 12px; color:var(--muted);">45 min</td>
</tr>
<tr style="border-bottom:1px solid rgba(79,209,197,0.07);">
  <td style="padding:8px 12px; color:var(--text2);">Run AI agents locally on a 70B model</td>
  <td style="padding:8px 12px;"><a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/qb2-local-agents/">Local AI Agents on QB2</a></td>
  <td style="padding:8px 12px; color:var(--muted);">60 min</td>
</tr>
<tr style="border-bottom:1px solid rgba(79,209,197,0.07);">
  <td style="padding:8px 12px; color:var(--text2);">Generate video on QB2</td>
  <td style="padding:8px 12px;"><a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/qb2-video-generation/">QB2 Video Generation</a></td>
  <td style="padding:8px 12px; color:var(--muted);">45 min</td>
</tr>
<tr style="border-bottom:1px solid rgba(79,209,197,0.07);">
  <td style="padding:8px 12px; color:var(--text2);">Build kernels from scratch on Tensix cores</td>
  <td style="padding:8px 12px;"><a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/explore-metalium/">Explore TT-Metalium</a></td>
  <td style="padding:8px 12px; color:var(--muted);">open-ended</td>
</tr>
<tr>
  <td style="padding:8px 12px; color:var(--text2);">Write cookbook-style parallel algorithms</td>
  <td style="padding:8px 12px;"><a href="https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/cookbook-overview/">Cookbook Overview</a></td>
  <td style="padding:8px 12px; color:var(--muted);">varies</td>
</tr>
</tbody>
</table>
</div>

## Choose Your Next Track

<div style="display:grid; gap:16px; margin: 2em 0;">

<a href="/ml-practitioner/" style="display:block; background:var(--bg1); border-left:3px solid var(--pink); padding:16px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="color:var(--pink);font-weight:700;margin-bottom:4px;">ML Practitioner →</div>
  <div style="font-size:13px;color:var(--text2);">Serve real models. Understand performance. Integrate with your existing ML workflow. If you're coming from CUDA, this is where the familiar parts live and where the new parts pay off.</div>
</a>

<a href="/builder-hacker/" style="display:block; background:var(--bg1); border-left:3px solid var(--gold); padding:16px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="color:var(--gold);font-weight:700;margin-bottom:4px;">Builder / Hacker →</div>
  <div style="font-size:13px;color:var(--text2);">Write code that runs on the chips directly — kernels, data movement, compute pipelines. The architecture goes all the way down and you can follow it.</div>
</a>

<a href="/tinkerer/" style="display:block; background:var(--bg1); border-left:3px solid var(--green); padding:16px 18px; border-radius:var(--radius); text-decoration:none; color:var(--text);">
  <div style="color:var(--green);font-weight:700;margin-bottom:4px;">Curious Tinkerer →</div>
  <div style="font-size:13px;color:var(--text2);">Customize, illuminate, break, and fix things. The LEDs, the desktop, the demos that make people stop and ask what that machine is.</div>
</a>

</div>

The QB2 is a beginning. There's a lot of surface area here, and you've only scratched it.

---

**[← Back to First Timer track](/first-timer/)**
