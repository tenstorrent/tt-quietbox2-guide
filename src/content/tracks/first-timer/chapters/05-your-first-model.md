---
title: Your First Model
currentChapter: 05-your-first-model
permalink: /first-timer/05-your-first-model/
---
{% set persona = personas | findPersona(personaId) %}

# Your First Model

Everything up to now was preparation. This is the part where the machine does something interesting.

{% chunk "run-first-model" %}

## What Just Happened

When that Python snippet ran without errors, the Blackhole chip opened a communication channel, initialized its dispatch cores, and confirmed it can receive work. That's the handshake — chip to software — that makes everything else possible.

No model ran yet. That's next.

## Running a Model with tt-studio

{% chunk "tt-studio-intro" %}

## If You Prefer the Command Line

You can also serve a model directly via vLLM without the UI:

```bash
source ~/tt-metal/build/python_env_vllm/bin/activate

# Download and serve Qwen3-0.6B (fast, no license required)
python3 -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen3-0.6B \
  --port 8000
```

Then query it from another terminal:

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-0.6B",
    "messages": [{"role": "user", "content": "What is a Tenstorrent chip?"}]
  }' | python3 -m json.tool
```

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">🔬</span>
<strong>Why Qwen3-0.6B?</strong> It's the recommended starter model for Tenstorrent hardware: small enough to load fast, capable enough to give real answers, and requires no Hugging Face license agreement.
</div>

<div class="video-placeholder illustrated-only">
  <strong>Coming soon: First model run</strong>
  Running the TTNN device check and a vLLM inference call on a live QB2.
  <!-- VIDEO: VHS recording — TTNN device open, then vLLM server start, then curl query. Script: scripts/vhs/05-first-model-demo.tape -->
</div>

---

**Next:** [What Comes Next →](/first-timer/06-what-comes-next/)
