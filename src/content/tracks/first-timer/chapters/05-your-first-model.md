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

The fastest path to actually generating text is vLLM. It handles model loading, tokenization, batching, and presents an OpenAI-compatible HTTP API.

```bash
source ~/.tenstorrent-venv/bin/activate

# Make sure the model is downloaded first (see above)
# Then start the server:
python3 -m vllm.entrypoints.openai.api_server \
  --model ~/models/Qwen3-0.6B \
  --port 8000
```

You'll see initialization messages as the model loads. This takes a minute or two on first run — the model weights are being compiled for the Blackhole architecture. Subsequent runs are faster.

Once you see `INFO: Application startup complete`, the server is ready. In a new terminal:

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3-0.6B",
    "messages": [{"role": "user", "content": "What makes the Tenstorrent Blackhole chip different?"}]
  }' | python3 -m json.tool
```

The response is JSON. The answer is in `choices[0].message.content`.

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">💡</span>
<strong>Why Qwen3-0.6B?</strong> It's the recommended starter model for all Tenstorrent hardware: small enough to load fast (~1.5 GB), capable enough to give real answers, reasoning-capable with dual thinking modes (add <code>"think": false</code> to the request to skip extended reasoning), and requires no Hugging Face license. Start here before trying larger models.
</div>

## Using tt-studio (the Web UI)

{% chunk "tt-studio-intro" %}

## Multi-Device: Using All Four Chips

To spread a model across all four Blackhole chips, use `CreateDevices` instead of `open_device`:

```bash
source ~/tt-metal/python_env/bin/activate

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
