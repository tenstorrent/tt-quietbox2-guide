---
title: Your First Model
currentChapter: 05-your-first-model
permalink: /first-timer/05-your-first-model/
---
{% set persona = personas | findPersona(personaId) %}

# Your First Model

Everything up to now was preparation. This is the part where the machine does something interesting. Four chips, waiting. One small model, about to arrive.

{% chunk "run-first-model" %}

## What Just Happened

When that Python snippet ran without errors, the Blackhole chip opened a dispatch channel through the PCIe link, initialized its RISC-V cores, and confirmed it can receive work. Nothing computed yet. But the handshake — software to silicon — is the prerequisite for everything else.

{% tensixviz "blackhole", [
  {"step": "highlight", "cores": [[8,1],[8,2],[8,3],[8,4],[8,5],[8,6],[8,7],[8,8],[8,9],[8,10]], "color": "pcie", "label": "PCIe column — your open_device() call crosses here", "ms": 700},
  {"step": "pause", "ms": 500},
  {"step": "transfer", "from": [8,5], "to": [4,5], "ms": 600},
  {"step": "highlight", "cores": [[4,5]], "color": "pink", "label": "Dispatch core initialized", "ms": 600},
  {"step": "pause", "ms": 400},
  {"step": "transfer", "from": [4,5], "to": [7,5], "ms": 400},
  {"step": "transfer", "from": [4,5], "to": [4,7], "ms": 400},
  {"step": "transfer", "from": [4,5], "to": [10,5], "ms": 400},
  {"step": "pause", "ms": 600},
  {"step": "highlight", "cores": [[7,5],[4,7],[10,5]], "color": "teal", "label": "Worker cores ready", "ms": 600},
  {"step": "pause", "ms": 1000},
  {"step": "clear"}
] %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;"><code>ttnn.open_device(0)</code> — what happens inside the chip.</p>

## Serving a Model with vLLM

The fastest path to actually generating text is vLLM. It handles model loading,
tokenization, batching, and presents an OpenAI-compatible HTTP API.

On a QB2 you do not invoke `vllm` yourself, and it is **not** installed in
`~/.tenstorrent-venv` — that venv holds only the hardware tooling (`tt-smi`, `tt-flash`).
vLLM ships inside a container that `tt-inference-server` launches for you:

```bash
cd ~/.local/lib/tt-inference-server

export HF_TOKEN=hf_...   # required; gated repos need it even when weights are local

python3 run.py \
  --model Llama-3.1-8B-Instruct \
  --workflow server \
  --tt-device p300x2 \
  --docker-server
```

`run.py` selects the right container image, sets `TT_METAL_ARCH_NAME`, `MESH_DEVICE` and
the vLLM RPC timeout for you, and publishes the OpenAI-compatible API. Add
`--print-docker-cmd` to see the exact `docker run` it would issue before it launches.

:::callout type="tip"
`--tt-device p300x2` is the whole QB2 — two P300 boards, four Blackhole chips. Passing
`p300` uses a single board, so half the machine sits idle. Check what a given model
supports: not every model is built for every topology.
:::

:::callout type="tip"
If you already pulled weights with `hf download`, add `--host-hf-cache` so the server
mounts `~/.cache/huggingface` read-only instead of downloading its own copy into a
Docker volume.
:::

:::callout type="tip"
Llama-3.1-8B is the safer first model here. Very small models like Qwen3-0.6B will load — the
plugin maps them by architecture — but they have no tuned implementation in tt-metal's
`tt_transformers`, so output quality is not something to judge the hardware by. Note that
Qwen3-0.6B is not in `tt-inference-server`'s model list at all: it is fine for the direct
TTNN handshake above, but you cannot serve it with the command in this section.
:::

You'll see initialization messages as the model loads. This takes a minute or two on first run — the model weights are being compiled for the Blackhole architecture. Subsequent runs are faster.

Once you see `INFO: Application startup complete`, the server is ready. In a new terminal:

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.1-8B-Instruct",
    "messages": [{"role": "user", "content": "What makes the Tenstorrent Blackhole chip different?"}]
  }' | python3 -m json.tool
```

The response is JSON. The answer is in `choices[0].message.content`.

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">💡</span>
<strong>Why two different models?</strong> Qwen3-0.6B is the starter for the <em>direct TTNN</em> path earlier in this chapter: ~1.5 GB, no Hugging Face license gate, fast to pull. For <em>serving</em>, use Llama-3.1-8B-Instruct — Qwen3-0.6B has no tuned <code>tt_transformers</code> implementation and is not in <code>tt-inference-server</code>'s model list, so the vLLM command above cannot serve it.
</div>

## Using tt-studio (the Web UI)

{% chunk "tt-studio-intro" %}

## Multi-Device: Using All Four Chips

To spread a model across all four Blackhole chips, use `CreateDevices` instead of `open_device`:

```bash
tt-metalium

python3 -c "
import ttnn
devices = ttnn.CreateDevices({0, 1, 2, 3})
print('All devices:', devices)
ttnn.CloseDevices(devices)
print('Done.')
"
```

`CreateDevices` handles the mesh configuration that lets the chips coordinate. Models loaded this way can distribute layers across chips, increasing the effective memory pool and throughput. Large models (Llama-3.1-70B) require this — they don't fit on one chip's memory alone.

{% tensixsystem "qb2", "One mesh, four chips — what CreateDevices opens" %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;"><code>CreateDevices</code> spans all four chips: a large model's layers spread across them for more memory and throughput. (A small model like Qwen3-0.6B runs happily on one chip.)</p>

<figure class="video-demo">
<img src="/assets/video/05-first-model-demo.gif" alt="TTNN device open and Qwen3-0.6B model files on a live QB2" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">Opening TTNN device and browsing model files on a live QB2</figcaption>
</figure>

---

**Next:** [What Comes Next →](/first-timer/06-what-comes-next/)
