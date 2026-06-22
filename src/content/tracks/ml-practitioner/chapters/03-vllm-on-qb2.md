---
title: vLLM on QB2
currentChapter: 03-vllm-on-qb2
permalink: /ml-practitioner/03-vllm-on-qb2/
---
{% set persona = personas | findPersona(personaId) %}

# vLLM on QB2

This is the chapter with the most practical density. By the end of it you'll have a running OpenAI-compatible inference server, a working curl command, and a Python client snippet you can drop into any application. Everything in this chapter is production-ready, not toy code.

## The Deployment Stack

The QB2 ships with two paths to running models as a server.

The **direct vLLM path** activates the pre-built venv and launches the API server directly. More control, lower ceremony.

The **tt-inference-server path** wraps the same vLLM backend in a Docker container with one-command deploy syntax. This is what tt-studio and tt-local-generator use internally. It handles Docker pulls, environment setup, and port mapping automatically.

Both paths produce the same OpenAI-compatible API on port 8000. Which you use depends on whether you want the control surface of running vLLM directly or the simplicity of a single command.

<img src="/assets/illustrations/inference-stack.svg" alt="Inference stack diagram showing the path from user interfaces through tt-inference-server and vLLM down to four Blackhole P300c chips" class="spot-illustration" style="max-width:100%; margin: 2em 0;">

## Path 1: Direct vLLM

```bash
# Activate the main tenstorrent venv (contains vLLM)
source ~/.tenstorrent-venv/bin/activate

# Set the Blackhole architecture flag
export TT_METAL_ARCH_NAME=blackhole

# Start the server
python3 -m vllm.entrypoints.openai.api_server \
  --model ~/models/Qwen3-0.6B \
  --port 8000
```

On first run: the model weights get compiled into Blackhole-optimized op graphs. This takes 3–5 minutes. Subsequent starts are fast — the compiled artifacts are cached.

Watch the logs. When you see a line containing `Application startup complete`, the server is accepting requests.

:::callout type="tip"
The `TT_METAL_ARCH_NAME=blackhole` environment variable is required for Blackhole hardware. The vLLM TT fork needs it to select the correct device backend. If you see errors about unknown architecture or device initialization failures, this is the first thing to check.
:::

## Path 2: tt-inference-server

The tt-inference-server is pre-installed at `~/.local/lib/tt-inference-server`. It handles the Docker container lifecycle for you.

```bash
# Deploy Llama-3.1-8B-Instruct with one command
python3 ~/.local/lib/tt-inference-server/run.py \
  --model Llama-3.1-8B-Instruct \
  --tt-device p100

# The p100 flag targets QB2 P300c hardware
# On first run: Docker pull + weight compilation (~5 min)
# Then: port 8000 is ready
```

The `--tt-device p100` flag tells tt-inference-server you're running on QB2/P300c hardware. The full list of options is in the [tt-inference-server lesson →](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-inference-server/)

## Verifying the Server

Once the server reports ready, confirm it's working:

```bash
# List available models
curl -s http://localhost:8000/v1/models | python3 -m json.tool

# First chat completion
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3-0.6B",
    "messages": [
      {"role": "user", "content": "Explain tensor parallelism in one sentence."}
    ]
  }' | python3 -m json.tool
```

The response JSON has the generated text at `choices[0].message.content`. If you get a connection refused, the server isn't ready yet — give it another 30 seconds.

## OpenAI Python SDK

The server is API-compatible with OpenAI's client library. Point `base_url` at `localhost:8000` and set `api_key` to any non-empty string — the server ignores it.

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-checked"
)

response = client.chat.completions.create(
    model="Qwen3-0.6B",
    messages=[
        {"role": "system", "content": "You are a concise technical assistant."},
        {"role": "user", "content": "What is the Tenstorrent NOC fabric?"}
    ],
    max_tokens=256,
    temperature=0.7
)

print(response.choices[0].message.content)
```

This is the integration point for any application that already talks to OpenAI. Change the base URL, change the model name, and the rest of the code runs unchanged.

## Streaming Responses

For applications that need to show text as it generates — chat interfaces, interactive tools — use the streaming mode:

```python
stream = client.chat.completions.create(
    model="Qwen3-0.6B",
    messages=[{"role": "user", "content": "Describe continuous batching."}],
    stream=True
)

for chunk in stream:
    delta = chunk.choices[0].delta
    if delta.content:
        print(delta.content, end="", flush=True)

print()  # newline at end
```

Each chunk arrives as a server-sent event; the OpenAI SDK unwraps them into delta objects. The pattern is identical to streaming from `api.openai.com` — because it's the same API.

## Continuous Batching

This is one of the QB2's practical advantages in production. vLLM's continuous batching algorithm fills the KV-cache space as requests arrive, packing multiple users' decode steps into the same chip invocation. You're not running one request at a time — the server is interleaving decode steps from multiple concurrent clients across every chip cycle.

For single-user interactive work, this doesn't matter. For serving a team, an API endpoint, or anything with concurrent load, it means the throughput numbers scale with parallelism rather than collapsing under it. A second concurrent user adds very little overhead up to the throughput ceiling of the chip.

:::callout type="deep-dive"
Continuous batching is fundamentally different from static batching. Static batching waits to collect N requests before dispatching — it adds latency to achieve throughput. Continuous batching inserts new decode sequences into the in-flight batch as slots open up, achieving throughput without adding per-request waiting time. vLLM pioneered this for transformer inference. The Tenstorrent vLLM fork implements it on Blackhole, where the KV-cache management happens in Tensix SRAM and DRAM across the chip grid.
:::

## Port Map

Keep these ports clear. Other services on the QB2 use them.

| Port | Service |
|---|---|
| `8000` | vLLM / tt-inference-server (OpenAI-compatible API) |
| `7860` | tt-studio (web UI) |
| `8001` | tt-inference-server prompt server |

If port 8000 is already in use when you try to start vLLM, check for a running tt-studio or tt-inference-server instance first: `lsof -i :8000`

## Remote Access via SSH Port Forward

The vLLM server listens on localhost only by default. To access it from another machine on your network — or from your laptop over SSH — use port forwarding:

```bash
# Run this on your laptop / remote machine
# Forwards your local port 8000 to the QB2's port 8000
ssh -L 8000:localhost:8000 your-user@your-qb2-hostname

# Now on your laptop, this works:
curl http://localhost:8000/v1/models
```

Keep the SSH session open while you use the forwarded port. For a persistent setup, look at `autossh` or tmux to keep the tunnel alive.

:::callout type="warn"
Don't expose port 8000 directly to the internet without authentication. The OpenAI-compatible API has no built-in auth layer — it trusts any caller. For internal network use or behind a VPN it's fine. For public exposure, put a reverse proxy with authentication in front of it.
:::

## Multi-Chip: Using All Four Cards

For 70B models, add the `--tensor-parallel-size 4` flag to use all four Blackhole chips:

```bash
# Direct vLLM, 4-chip tensor parallel
python3 -m vllm.entrypoints.openai.api_server \
  --model ~/models/Llama-3.1-70B-Instruct \
  --tensor-parallel-size 4 \
  --port 8000

# Or with tt-inference-server:
python3 ~/.local/lib/tt-inference-server/run.py \
  --model Llama-3.1-70B-Instruct \
  --tt-device p100 \
  --num_chips 4
```

The model weights distribute across all four chips' DRAM. The KV-cache splits across the chips' Tensix cores. From the client's perspective, the API is identical — same URL, same request format.

<figure class="video-demo">
<img src="/assets/video/09-vllm-demo.gif" alt="Activating the TTNN venv, checking hardware with tt-smi, vLLM serve command on a QB2" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">Venv setup and hardware check before serving — four p300c chips ready</figcaption>
</figure>

---

**Next:** [Performance Tuning →](/ml-practitioner/04-performance-tuning/)
