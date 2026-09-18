---
title: vLLM on QB2
currentChapter: 03-vllm-on-qb2
permalink: /ml-practitioner/03-vllm-on-qb2/
---
{% set persona = personas | findPersona(personaId) %}

# vLLM on QB2

This is the chapter with the most practical density. By the end of it you'll have a running OpenAI-compatible inference server, a working curl command, and a Python client snippet you can drop into any application. Everything in this chapter is production-ready, not toy code.

## The Deployment Stack

There are two ways to run models as a server, and only one of them works out of the box.

The **tt-inference-server path** wraps the vLLM backend in a Docker container with
one-command deploy syntax. This is what tt-studio and tt-local-generator use internally. It
handles Docker pulls, environment setup, and port mapping automatically. It is pre-installed
at `~/.local/lib/tt-inference-server`, and it is the whole of this chapter.

The **direct vLLM path** runs `vllm serve` yourself, for flags the managed path doesn't
expose or a newer vLLM than the pinned image ships. **vLLM is not installed on a QB2** — not
in `~/.tenstorrent-venv`, not on the host at all; the copy the managed path uses lives inside
a container image. Building that environment is its own project, so it has its own lesson:
**[Build Your Own vLLM Environment →](/lessons/build-your-own-vllm/)**. Come back here when
you want a server running rather than a toolchain.

Both produce the same OpenAI-compatible API on port 8000.

<img src="/assets/illustrations/inference-stack.svg" alt="Inference stack diagram showing the path from user interfaces through tt-inference-server and vLLM down to four Blackhole chips" class="spot-illustration" style="max-width:100%; margin: 2em 0;">

## Serving with tt-inference-server

tt-inference-server is pre-installed at `~/.local/lib/tt-inference-server`. It handles the Docker container lifecycle for you.

```bash
# run.py validates HF_TOKEN whenever --docker-server is passed — even when the
# weights are already local. Without it you get "⛔ HF_TOKEN not set." and no server.
export HF_TOKEN=hf_...

# Deploy Llama-3.1-8B-Instruct with one command
python3 ~/.local/lib/tt-inference-server/run.py \
  --model Llama-3.1-8B-Instruct \
  --tt-device p300x2 \
  --workflow server --docker-server

# p300x2 = a QB2: two P300 cards, four Blackhole chips
# On first run: Docker pull + weight compilation (~5 min)
# Then: port 8000 is ready
```

`--tt-device p300x2` is what identifies a QB2 — two P300 cards, four chips, and the value you
want almost every time. `p300` selects a single card (two chips), which is the mesh that has
failed fabric bring-up on our hardware — prefer `p150` if you deliberately want less than the
whole box. **`p100` is a single Blackhole chip**, so it under-uses a QB2 rather than failing
loudly. Not every model has an entry for every topology: `Qwen3-8B`, for instance, is listed for
`p300` but not `p300x2`, while `Llama-3.1-8B-Instruct` and `Qwen3-32B` both have `p300x2`
entries. The full list of options is in the [tt-inference-server lesson →](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-inference-server/)

On this path you do **not** set `MESH_DEVICE` or `TT_MESH_GRAPH_DESC_PATH` yourself — `run.py`
derives them per model from its spec, and on a QB2 the correct value is model-dependent.

:::callout type="tip"
**Three more flags worth knowing on this path.** `--host-hf-cache` reuses weights you've already
downloaded **yourself** to the Hugging Face cache instead of re-pulling them into a fresh Docker
volume — see ["Check Space Before Downloading"](/ml-practitioner/02-model-zoo/) in the previous
chapter for why that disk hit matters. Note it is the wrong flag for the pre-cached Qwen3-32B,
which sits outside any Hugging Face cache — use `--host-weights-dir` for that, as above. `--no-auth` skips JWT authentication for
local, unauthenticated serving (fine on a trusted LAN, not for internet exposure). `--service-port`
sets the port the managed model's container API listens on — e.g. `--service-port 8002`. A full
command combining them:

```bash
# Llama-3.1-8B-Instruct here, not Qwen3-32B: --host-hf-cache reuses weights you
# downloaded yourself, and this is a model you would have pulled with `hf download`.
python3 ~/.local/lib/tt-inference-server/run.py \
  --model Llama-3.1-8B-Instruct \
  --tt-device p300x2 \
  --workflow server --docker-server \
  --no-auth --service-port 8002 --host-hf-cache
```
:::

{% chunk "precached-model" %}

## Verifying the Server

Once the server reports ready, confirm it's working:

```bash
# List available models — start here, and use the id it prints
curl -s http://localhost:8000/v1/models | python3 -m json.tool

# First chat completion
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "meta-llama/Llama-3.1-8B-Instruct",
    "messages": [
      {"role": "user", "content": "Explain tensor parallelism in one sentence."}
    ],
    "max_tokens": 120
  }' | python3 -m json.tool
```

The response JSON has the generated text at `choices[0].message.content`. If you get a connection refused, the server isn't ready yet — give it another 30 seconds.

:::callout type="warn"
**`"model"` has to match what the server actually loaded**, or you get back a 404, not a
fallback — `{"error": {"message": "The model \`Qwen3-0.6B\` does not exist.", "code": 404}}`.
Take the string from `/v1/models` rather than from an example. **The server does not use the
short name you pass to `--model`** — `run.py` hands the container the model's full Hugging
Face repo id (`hf_model_repo`) and nothing renames it, so `--model Llama-3.1-8B-Instruct` is
served as `meta-llama/Llama-3.1-8B-Instruct`, and `--model Qwen3-32B` as `Qwen/Qwen3-32B`.
The direct-vLLM path is different — its `--served-model-name` flag renames the model
explicitly — but that is [its own lesson](/lessons/build-your-own-vllm/). The examples below
use the managed path's naming; substitute whatever your box actually reports — `curl -s http://localhost:8000/v1/models | python3 -m json.tool` tells you.
:::

:::callout type="tip"
**Serving a Qwen3 model instead?** They reason before answering, so a small `max_tokens` gets
spent entirely inside the `<think>` block and comes back as `finish_reason: "length"` with an
empty answer. Add `"chat_template_kwargs": {"enable_thinking": false}` to the request body above
(or `extra_body={"chat_template_kwargs": {"enable_thinking": False}}` in the Python SDK examples
below) for direct replies — see [Qwen3 Reasoning Modes](/ml-practitioner/02-model-zoo/). Llama and
other non-reasoning models don't need it; sending it anyway isn't guaranteed to be a harmless
no-op on every model, so only add it for a model that actually supports it.
:::

## OpenAI Python SDK

The server is API-compatible with OpenAI's client library. Point `base_url` at `localhost:8000` and set `api_key` to any non-empty string — the server ignores it.

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-checked"
)

response = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
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

:::callout type="tip"
**Serving a Qwen3 model instead?** Add `extra_body={"chat_template_kwargs": {"enable_thinking":
False}}` to `create()` — see the note under [Verifying the Server](#verifying-the-server) above.
Only add it when the served model is actually a reasoning model; Llama and similar models don't
need it.
:::

## Streaming Responses

For applications that need to show text as it generates — chat interfaces, interactive tools — use the streaming mode:

```python
stream = client.chat.completions.create(
    model="meta-llama/Llama-3.1-8B-Instruct",
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
Continuous batching is fundamentally different from static batching. Static batching waits to collect N requests before dispatching — it adds latency to achieve throughput. Continuous batching inserts new decode sequences into the in-flight batch as slots open up, achieving throughput without adding per-request waiting time. vLLM pioneered this for transformer inference. Tenstorrent's vLLM backend carries it onto Blackhole, where KV-cache management happens in L1 and DRAM across the chip grid.
:::

## Port Map

Keep these ports clear. Other services on the QB2 use them.

| Port | Service |
|---|---|
| `8000` | vLLM / tt-inference-server (OpenAI-compatible API) |
| `3000` | tt-studio (web UI) |
| `4000` | tt-studio's LiteLLM gateway (coding-agent surface — see `agents.md`) |
| `8001` | tt-local-generator's prompt server — **not** tt-inference-server |
| `8002` | a managed model's container API, when serving with `--service-port 8002` |

If port 8000 is already in use when you try to start vLLM, check for a running tt-studio or
tt-inference-server instance first.

:::callout type="tip"
On a box already running tt-studio, port 8000 is taken before you start — its backend container
publishes it, and `vllm serve` exits with `OSError: [Errno 98] Address already in use`. Because
the listener is a container mapping, `lsof -i :8000` often shows nothing useful; `docker ps` names
the real owner. Easiest fix is to leave tt-studio alone and serve on a free port such as `8003`,
remembering to change it in the `curl` commands too.
:::

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

## Multi-Chip: Using All Four Chips

:::callout type="warn"
**`--tensor-parallel-size` does not work here.** The Tenstorrent platform rejects both tensor
parallel and pipeline parallel outright, before anything reaches the device. Multi-chip is
selected by the **mesh shape** instead. If you have seen `--tensor-parallel-size 4` in older
QB2 notes — including earlier versions of this page — that is why it failed.
:::

On the managed path you don't choose the mesh — `run.py` derives it per model from its spec.
For a 70B across all four Blackhole chips that is just:

```bash
python3 ~/.local/lib/tt-inference-server/run.py \
  --model Llama-3.1-70B-Instruct \
  --tt-device p300x2 \
  --workflow server --docker-server
```

The model weights distribute across all four chips' DRAM, and the KV cache is allocated per
chip across the mesh. From the client's perspective the API is identical — same URL, same
request format.

Setting the mesh by hand is a direct-vLLM concern — `MESH_DEVICE`, its accepted names, and the
case difference from `--tt-device` are covered in [Build Your Own vLLM
Environment](/lessons/build-your-own-vllm/). One thing carries over to this path regardless:

:::callout type="warn"
**Two-chip meshes fail on our QB2.** Whichever path you use, asking for exactly two chips dies
during fabric bring-up:

```text
Fabric Router Sync: Timeout after 10000 ms on Device 2 ... Ethernet handshake likely failed
```

One chip and all four both work; two does not, reproducibly across board resets. On this path
that means `--tt-device p300` is the value to avoid — prefer `p150` to go narrower, or
`p300x2` for the whole box.
:::

:::callout type="tip"
**Why a P300 box writes a cache directory called `P150x4`.** On the first run for a model,
tt-metal converts the weights into `~/models/<model>/<device-name>/`, and that name comes from
the **number of chips in the mesh, not the board type** — four Blackhole chips are labelled
`P150x4` even though they are two P300 cards. It is not a sign you picked the wrong hardware.

The cache is per-mesh-size, so switching between `P150` and `P300x2` writes a second directory
and pays the conversion again. An unexpectedly slow "second" start usually means the mesh
changed, not that something broke.
:::

:::callout type="tip"
**Status on our hardware.** The four-chip serving path brings up correctly — the plugin selects
the TT platform, opens all four chips, loads weights and allocates the KV cache on the mesh, and
the OpenAI-compatible endpoints respond. We have **not** yet signed off on output quality: in our
testing generation degenerated into repetition, and we reproduced that across two vLLM versions,
three models, and both one- and four-chip meshes — so it is not specific to the mesh. Our current
suspicion is host firmware and driver versions running ahead of the tested pairings. Treat
four-chip throughput numbers as unverified until that is resolved.
:::

## When Startup Stalls

Startup has long silent stretches, so "stuck" and "working" look alike in the log. Two quiet
phases are normal: building rotary-embedding matrices, which prints nothing at all, and the
warmup prefill sweeps that follow weight loading. Warmup also emits
`TT_FATAL: Only TILE layout is supported for BFLOAT8_B dtype!` at `critical` level, sometimes
hundreds of times — it is caught internally and startup continues. Worth knowing if you script a
log watcher, since grepping for `FATAL` will trip on it.

A real device hang looks different: the log stops, CPU sits near 100%, and RSS stops moving
entirely. Real work moves RSS. Confirm with a native stack dump:

```bash
uv tool install py-spy   # isolated install — not into the vLLM venv you're diagnosing
py-spy dump --native --pid "$(pgrep -n -f 'VLLM::EngineCore')"
```

`-n` on `pgrep` matters if more than one matching process is running: `py-spy --pid` takes exactly
one PID, and an unfiltered `pgrep -f` can print several.

A hang in the command queue is unmistakable — `pthread_cond_wait` under
`FDMeshCommandQueue::wait_for_outstanding_reads`, meaning the device never acknowledged a write.
`--native` matters: the plain Python stack only shows `ttnn.from_torch` and looks like ordinary
work.

The usual cause is stale state from a run that did not exit cleanly, and a reset clears it:

```bash
sudo lsof -w /dev/tenstorrent/*   # must print nothing before you continue
tt-smi -r                          # reset all boards
```

`lsof` exits `1` when nothing holds the devices, so for this check non-zero is the answer you
want.

:::callout type="warn"
**Stop vLLM with Ctrl-C or SIGTERM, never `kill -9`.** A graceful exit lets the engine drain its
command queue and close the mesh device; killing it mid-queue is what leaves boards wedged, so
the *next* start hangs and gets the blame. Note too that boards can report healthy under
`tt-smi -s` — sane temperatures, `dram_status: true` — while still holding state that hangs a
fresh mesh. Healthy telemetry does not rule out needing a reset.
:::

## Going further

Two things this chapter deliberately leaves out, because each is a project rather than a step:

{% card "lesson", "/lessons/build-your-own-vllm/", "Build Your Own vLLM Environment", "Run `vllm serve` yourself — the plugin install, the numpy/ttnn override that bites everyone, and the mesh variables the managed path sets for you.", "~40 min" %}

{% card "lesson", "/lessons/weights-caches-volumes/", "Weights, Caches and Volumes", "Where the shipped Qwen3-32B actually lives, why `--host-hf-cache` is the wrong flag, and how to reuse the 30 GB of pre-compiled kernels.", "~15 min" %}

---

**Next:** [Performance Tuning →](/ml-practitioner/04-performance-tuning/)
