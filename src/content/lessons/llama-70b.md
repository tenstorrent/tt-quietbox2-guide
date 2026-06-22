---
layout: layouts/base.njk
title: Running Llama-3.3-70B on QB2
description: "Deploy a full 70-billion parameter model on your TT-QuietBox® 2 using tt-inference-server. Step-by-step from prerequisites to first response."
permalink: /lessons/llama-70b/
---

<style>
.lesson-layout { max-width: 860px; margin: 0 auto; padding: 32px 24px 80px; }
.lesson-eyebrow { font-size: 11px; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); margin: 0 0 8px; }
.lesson-title { font-size: clamp(1.8rem, 4vw, 2.8rem); font-weight: 700; color: var(--teal); margin: 0 0 12px; line-height: 1.15; }
.lesson-subtitle { font-size: 1.1rem; color: var(--text2); margin: 0 0 32px; max-width: 640px; }
.lesson-meta { display: flex; gap: 20px; font-size: 12px; color: var(--muted); margin-bottom: 40px; padding-bottom: 24px; border-bottom: 1px solid var(--bg2); }
.track-pill { display: inline-flex; align-items: center; gap: 6px; padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 600; background: var(--bg1); }
.track-pill--teal  { color: var(--teal); border: 1px solid rgba(79,209,197,0.3); }
.track-pill--pink  { color: var(--pink); border: 1px solid rgba(236,150,184,0.3); }
.track-pill--gold  { color: var(--gold); border: 1px solid rgba(244,196,113,0.3); }
.track-pill--green { color: var(--green); border: 1px solid rgba(39,174,96,0.3); }
.spec-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin: 24px 0; }
@media (max-width: 600px) { .spec-grid { grid-template-columns: 1fr; } }
.spec-card { background: var(--bg1); border: 1px solid var(--bg2); border-radius: var(--radius); padding: 16px 18px; }
.spec-card-label { font-size: 11px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); margin-bottom: 4px; }
.spec-card-value { font-size: 1rem; font-weight: 600; color: var(--text); }
.spec-card-sub { font-size: 12px; color: var(--text2); margin-top: 3px; }
.step-header { display: flex; align-items: baseline; gap: 12px; margin: 40px 0 12px; }
.step-number { font-size: 11px; font-weight: 700; color: var(--teal); text-transform: uppercase; letter-spacing: 0.08em; white-space: nowrap; }
.warning-box { background: rgba(244,196,113,0.08); border-left: 3px solid var(--gold); border-radius: var(--radius); padding: 14px 18px; margin: 20px 0; font-size: 14px; }
.warning-box strong { color: var(--gold); }
</style>

<div class="lesson-layout">

<p class="lesson-eyebrow">Cross-track lesson · All paths</p>
<h1 class="lesson-title">Running Llama-3.3-70B on QB2</h1>
<p class="lesson-subtitle">A full 70-billion parameter model, running locally on the four Blackhole chips in your TT-QuietBox® 2. No cloud. No API key. Just your hardware.</p>

<div style="display:flex; flex-wrap:wrap; gap:8px; margin-bottom:20px;">
  <a href="/first-timer/" class="track-pill track-pill--teal">Explore</a>
  <a href="/ml-practitioner/" class="track-pill track-pill--pink">Run & build</a>
  <a href="/builder-hacker/" class="track-pill track-pill--gold">Tinker</a>
  <a href="/tinkerer/" class="track-pill track-pill--green">Customize</a>
</div>

<div class="lesson-meta">
  <span>~45 min (mostly waiting on model download)</span>
  <span>Prerequisites: Docker installed, HuggingFace account</span>
</div>

---

## What you're actually deploying

**Llama-3.3-70B-Instruct** from Meta. 70 billion parameters — the largest Llama model that fits on a single QB2. This is the model that, two years ago, required a dedicated cloud VM with 8× A100s. Your QB2 has four Blackhole chips (on two p300c cards); together they have enough DRAM bandwidth and capacity to run it.

The same command also runs these weight variants:

- **Llama-3.1-70B-Instruct** — slightly older, same architecture
- **DeepSeek-R1-Distill-Llama-70B** — a reasoning model distilled from DeepSeek-R1 into the Llama-70B architecture. Swap the model name and you get chain-of-thought reasoning output from the same server.

<div class="spec-grid">
  <div class="spec-card">
    <div class="spec-card-label">Model</div>
    <div class="spec-card-value">Llama-3.3-70B-Instruct</div>
    <div class="spec-card-sub">meta-llama/Llama-3.3-70B-Instruct</div>
  </div>
  <div class="spec-card">
    <div class="spec-card-label">Status</div>
    <div class="spec-card-value">🟡 Functional</div>
    <div class="spec-card-sub">Tested on BH 4×P150 / QB2</div>
  </div>
  <div class="spec-card">
    <div class="spec-card-label">Max context</div>
    <div class="spec-card-value">131,072 tokens</div>
    <div class="spec-card-sub">128K context window</div>
  </div>
  <div class="spec-card">
    <div class="spec-card-label">Max batch size</div>
    <div class="spec-card-value">32</div>
    <div class="spec-card-sub">Concurrent requests</div>
  </div>
</div>

:::callout type="tip"
The official tt-inference-server documentation for this model lists the target hardware as "BH 4xP150" — that's the same Blackhole chip count and DRAM configuration as your QB2 P300c cards. The device flag is `p150x4`.
:::

---

## Before you start

**Docker must be installed.** The tt-inference-server uses Docker containers to manage the environment. If you've completed the Explore track, Docker is already present. Verify:

```bash
docker --version
# Docker version 24.x or later
```

**HuggingFace token with Llama access.** Meta's Llama models require accepting a license agreement on HuggingFace and using a token. This is a one-time step.

1. Go to [huggingface.co/meta-llama/Llama-3.3-70B-Instruct](https://huggingface.co/meta-llama/Llama-3.3-70B-Instruct)
2. Log in and accept the license
3. Create a read token at [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
4. Set it in your environment:

```bash
export HF_TOKEN=hf_your_token_here
# Add to ~/.bashrc to persist across sessions:
echo 'export HF_TOKEN=hf_your_token_here' >> ~/.bashrc
```

**Disk space.** The model weights are approximately 140 GB. Docker volumes store them in `/var/lib/docker/volumes/`. Make sure you have that space available:

```bash
df -h /var/lib/docker
```

**Hugepages.** The Tenstorrent driver requires 1G hugepages. If you've run any model before, these are already configured. To verify:

```bash
cat /proc/meminfo | grep HugePages
# HugePages_Total should be > 0
```

If hugepages are missing, the tt-installer script sets them up. See the [install chapter](/first-timer/04-installing-the-stack/).

---

## Step 1 — Pull tt-inference-server

tt-inference-server is Tenstorrent's Docker-based deployment tool. It wraps a TT-Metal-optimized fork of vLLM with one-command launch syntax.

```bash
git clone https://github.com/tenstorrent/tt-inference-server ~/code/tt-inference-server
cd ~/code/tt-inference-server
```

If you already have a clone, update it:

```bash
cd ~/code/tt-inference-server
git pull
```

---

## Step 2 — Start the server

The simplest path is the `run.py` helper from tt-inference-server — one command that pulls the container, downloads and compiles the weights, and maps the port:

```bash
cd ~/code/tt-inference-server
python3 run.py --model Llama-3.3-70B-Instruct --device p150x4 --workflow server --docker-server
```

**Under the hood**, `run.py` launches the TT vLLM container. If you'd rather drive Docker yourself — to pin flags, or run without the repo — the equivalent is:

```bash
docker run \
  --env "HF_TOKEN=$HF_TOKEN" \
  --ipc host \
  --publish 8000:8000 \
  --device /dev/tenstorrent \
  --mount type=bind,src=/dev/hugepages-1G,dst=/dev/hugepages-1G \
  --volume volume_id_Llama-3.3-70B-Instruct:/home/container_app_user/cache_root \
  ghcr.io/tenstorrent/tt-inference-server/vllm-tt-metal-src-release-ubuntu-22.04-amd64:0.10.1-555f240-22be241 \
  --model Llama-3.3-70B-Instruct \
  --tt-device p150x4
```

<div class="warning-box">
<strong>First run takes a long time.</strong> Docker will pull the container image (~15 GB), then download the model weights from HuggingFace (~140 GB). On a 500 Mbps connection, expect 40–60 minutes total. Subsequent starts use the cached Docker volume and take about 3–5 minutes.
</div>

**What to watch for:**

The container logs a lot during initialization. The meaningful signals:

```
# Docker image pulled and container starting
Starting vLLM server...

# Weights downloading (first run only)
Downloading shards: 100%|████████████████| 30/30

# Hardware initialization — all 4 chips should appear
Opening device 0... OK
Opening device 1... OK
Opening device 2... OK
Opening device 3... OK

# Op graph compilation — compiles Llama ops to Blackhole instructions
Compiling model graphs... (this takes 3-5 minutes)

# Ready
Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

When you see `Application startup complete`, the server is accepting requests.

---

## Step 3 — Send a request

The server exposes an OpenAI-compatible API on port 8000. Test it with curl:

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Llama-3.3-70B-Instruct",
    "messages": [
      {
        "role": "user",
        "content": "Explain tensor parallelism in 3 sentences. Be specific about what moves across chip boundaries."
      }
    ],
    "max_tokens": 200
  }' | python3 -m json.tool
```

Or pipe straight to the content:

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Llama-3.3-70B-Instruct",
    "messages": [{"role": "user", "content": "Write a haiku about Blackhole silicon."}]
  }' | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'])"
```

---

## Step 4 — Use it from Python

The server is a drop-in replacement for `api.openai.com`. Any code using the OpenAI SDK works unchanged — just point it at localhost:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-required",  # server doesn't enforce auth
)

response = client.chat.completions.create(
    model="Llama-3.3-70B-Instruct",
    messages=[
        {
            "role": "system",
            "content": "You are a concise technical assistant."
        },
        {
            "role": "user",
            "content": "What are the key differences between BF16 and FP16 for inference?"
        }
    ],
    max_tokens=300,
)

print(response.choices[0].message.content)
```

Install the SDK if needed:

```bash
pip install openai
```

---

## Step 5 — Watch the hardware work

Open a second terminal while inference is running. The difference between idle and active chips is visible in telemetry:

```bash
# Snapshot mode — JSON output, avoids TUI
tt-smi -s
```

Look for these fields across all four chips:

- **`aiclk`** — AI clock frequency. Climbs from ~200 MHz at idle to 900–1000 MHz during prefill, settles during decode.
- **`power`** — Power draw per chip. Expect 75–120W per chip during active inference, ~15W at idle.
- **`temperature`** — ASIC die temperature. Normal operating range is 50–80°C. The chips have thermal throttling; they will clock down before reaching dangerous temperatures.

A simpler view while a request is processing:

```bash
watch -n 1 "tt-smi -s | python3 -c \"
import json, sys
data = json.load(sys.stdin)
for i, chip in enumerate(data.get('device_info', [])):
    print(f'Chip {i}: aiclk={chip.get(\\\"aiclk\\\", \\\"?\\\"):>6} MHz  '
          f'power={chip.get(\\\"power\\\", \\\"?\\\"):>5} W  '
          f'temp={chip.get(\\\"temperature\\\", \\\"?\\\"):>4}°C')
\""
```

:::callout type="tip"
During a long prompt (prefill phase), you'll see aiclk spike across all four chips simultaneously — that's tensor parallelism in action. All four chips are processing different attention heads in parallel. During decode (generating tokens one at a time), the pattern changes: aiclk is lower because decode is memory-bandwidth-bound, not compute-bound.
:::

{% tensixviz "blackhole", [
  {"step": "highlight", "cores": [[0,1],[0,2],[0,3],[0,4],[0,5],[0,6],[0,7],[0,8],[0,9],[0,10],[16,1],[16,2],[16,3],[16,4],[16,5],[16,6],[16,7],[16,8],[16,9],[16,10]], "color": "eth", "label": "Ethernet cores — chip-to-chip AllReduce for tensor parallel", "ms": 600},
  {"step": "pause", "ms": 500},
  {"step": "highlight", "cores": [[1,0],[2,0],[3,0],[4,0],[5,0],[6,0],[7,0],[9,0],[10,0],[11,0],[12,0],[13,0],[14,0],[15,0],[1,11],[2,11],[3,11],[4,11],[5,11],[6,11],[7,11],[9,11],[10,11],[11,11],[12,11],[13,11],[14,11],[15,11]], "color": "dram", "label": "DRAM banks — streaming 140GB of weights through 4 chips", "ms": 600},
  {"step": "pause", "ms": 500},
  {"step": "highlight", "cores": [[1,1],[2,1],[3,1],[4,1],[5,1],[6,1],[7,1],[9,1],[10,1],[11,1],[12,1],[13,1],[14,1],[15,1],[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[7,2],[9,2],[10,2],[11,2],[12,2],[13,2],[14,2],[15,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3],[9,3],[10,3],[11,3],[12,3],[13,3],[14,3],[15,3],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4],[9,4],[10,4],[11,4],[12,4],[13,4],[14,4],[15,4],[1,5],[2,5],[3,5],[4,5],[5,5],[6,5],[7,5],[9,5],[10,5],[11,5],[12,5],[13,5],[14,5],[15,5],[1,6],[2,6],[3,6],[4,6],[5,6],[6,6],[7,6],[9,6],[10,6],[11,6],[12,6],[13,6],[14,6],[15,6],[1,7],[2,7],[3,7],[4,7],[5,7],[6,7],[7,7],[9,7],[10,7],[11,7],[12,7],[13,7],[14,7],[15,7],[1,8],[2,8],[3,8],[4,8],[5,8],[6,8],[7,8],[9,8],[10,8],[11,8],[12,8],[13,2],[14,2],[15,2],[1,9],[2,9],[3,9],[4,9],[5,9],[6,9],[7,9],[9,9],[10,9],[11,9],[12,9],[13,9],[14,9],[15,9],[1,10],[2,10],[3,10],[4,10],[5,10],[6,10],[7,10],[9,10],[10,10],[11,10],[12,10],[13,10],[14,10],[15,10]], "color": "tensixActive", "label": "All 120 Tensix cores computing — prefill in flight", "ms": 900},
  {"step": "pause", "ms": 1200},
  {"step": "clear"}
] %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">One Blackhole chip during Llama-3.3-70B prefill. All four of yours are doing this in parallel, each handling different layers.</p>

---

## Variant: DeepSeek-R1-Distill-Llama-70B

The same infrastructure runs **DeepSeek-R1-Distill-Llama-70B** — a reasoning model. It uses the Llama-70B architecture but was fine-tuned to produce explicit chain-of-thought reasoning before giving an answer. The Docker command is identical except for the model name:

```bash
docker run \
  --env "HF_TOKEN=$HF_TOKEN" \
  --ipc host \
  --publish 8000:8000 \
  --device /dev/tenstorrent \
  --mount type=bind,src=/dev/hugepages-1G,dst=/dev/hugepages-1G \
  --volume volume_id_DeepSeek-R1-Distill-Llama-70B:/home/container_app_user/cache_root \
  ghcr.io/tenstorrent/tt-inference-server/vllm-tt-metal-src-release-ubuntu-22.04-amd64:0.10.1-555f240-22be241 \
  --model DeepSeek-R1-Distill-Llama-70B \
  --tt-device p150x4
```

The HuggingFace model ID is `deepseek-ai/DeepSeek-R1-Distill-Llama-70B` — no gated license, so no need to request access. You do still need a HF token.

The reasoning model produces output in a different format: it wraps its thinking in `<think>` tags before the final answer. A multi-step math problem or logic puzzle will show its full reasoning chain.

```python
response = client.chat.completions.create(
    model="DeepSeek-R1-Distill-Llama-70B",
    messages=[{
        "role": "user",
        "content": "A train travels at 60 mph for 2 hours, then 90 mph for 1.5 hours. "
                   "What is the average speed for the entire trip?"
    }],
    max_tokens=600,
)
print(response.choices[0].message.content)
# Output starts with <think>...</think> showing the reasoning steps,
# then gives the final answer.
```

:::callout type="tip"
Reasoning models are worth trying on tasks where you want to see the model's work: code debugging, multi-step math, logic puzzles, structured analysis. The `<think>` section is the model's scratch pad — it often catches mistakes it would have made if it had answered directly.
:::

---

## Troubleshooting

**Docker can't find the hugepages mount:**

```
Error response from daemon: invalid mount config for type "bind",
option "source" does not exist: /dev/hugepages-1G
```

Hugepages aren't configured. Run the tt-installer script or configure them manually:

```bash
echo 'vm.nr_hugepages = 32' | sudo tee /etc/sysctl.d/99-hugepages.conf
sudo sysctl -p /etc/sysctl.d/99-hugepages.conf
sudo mkdir -p /dev/hugepages-1G
sudo mount -t hugetlbfs -o pagesize=1G hugetlbfs /dev/hugepages-1G
```

**Container starts but model download fails:**

```
huggingface_hub.errors.GatedRepoError: Access to model meta-llama/...
```

Your HF_TOKEN doesn't have access to Llama models. Accept the license at [huggingface.co/meta-llama/Llama-3.3-70B-Instruct](https://huggingface.co/meta-llama/Llama-3.3-70B-Instruct) while logged into the same account that generated the token.

**Four chips appear in `tt-smi` but container only finds some:**

Verify the driver exposes all devices:

```bash
ls /dev/tenstorrent/
# Should show: 0  1  2  3
```

If you only see some, the KMD may need a reload:

```bash
sudo rmmod tenstorrent
sudo modprobe tenstorrent
```

**Server starts but requests return very slowly:**

Confirm all four chips are active during inference using `tt-smi -s`. If only 1–2 show elevated aiclk, tensor parallelism isn't using all cards. Verify the `--tt-device p150x4` flag is present in your docker command.

**Out of disk space during Docker volume creation:**

The default Docker data root is `/var/lib/docker`. If your root partition is small, move it:

```bash
# Check where docker stores data
docker info | grep "Docker Root Dir"

# To move it, stop Docker and edit /etc/docker/daemon.json:
sudo systemctl stop docker
echo '{"data-root": "/your/larger/partition/docker"}' | sudo tee /etc/docker/daemon.json
sudo systemctl start docker
```

---

## Where this fits

This is the largest model the QB2 runs with official Tenstorrent support. Models beyond the ~70B range eventually need more memory or more chips than the QB2 has — an 8-chip system like a Wormhole t3k or a Blackhole LoudBox (8× p150). The 70B range is the practical ceiling for a single QB2.

Inside that ceiling: Llama-3.3-70B-Instruct is the capable baseline. DeepSeek-R1-Distill-Llama-70B is the reasoning variant. The smaller models in other chapters (Llama-3.1-8B, Qwen3-0.6B) are faster to start and better for experimentation — use those for iteration, and come back here when you want to show someone what the machine can actually do.

---

<div style="display:flex; flex-wrap:wrap; gap:12px; margin: 40px 0 0;">
  <a href="/ml-practitioner/03-vllm-on-qb2/" style="display:inline-flex; align-items:center; gap:6px; padding:10px 18px; background:var(--bg1); border-radius:var(--radius); text-decoration:none; color:var(--pink); font-weight:600; font-size:14px; border:1px solid rgba(236,150,184,0.25);">Run & build: Serving Models on QB2 →</a>
  <a href="/ml-practitioner/04-performance-tuning/" style="display:inline-flex; align-items:center; gap:6px; padding:10px 18px; background:var(--bg1); border-radius:var(--radius); text-decoration:none; color:var(--pink); font-weight:600; font-size:14px; border:1px solid rgba(236,150,184,0.25);">Performance Tuning →</a>
  <a href="/tinkerer/02-fun-demos/" style="display:inline-flex; align-items:center; gap:6px; padding:10px 18px; background:var(--bg1); border-radius:var(--radius); text-decoration:none; color:var(--green); font-weight:600; font-size:14px; border:1px solid rgba(39,174,96,0.25);">Fun Demos →</a>
</div>

</div>
