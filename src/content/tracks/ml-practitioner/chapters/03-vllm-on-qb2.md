---
title: Serving Models on QB2
currentChapter: 03-vllm-on-qb2
permalink: /ml-practitioner/03-vllm-on-qb2/
---
{% set persona = personas | findPersona(personaId) %}

# Serving Models on QB2

[Serve a Model](/first-timer/05-your-first-model/) got a model answering with one `tt serve`
command. This chapter is what is underneath that command, and what to do when you need more
than the default: another port, two servers at once, a model that is not in the catalog, or
a server on specific chips. By the end you will have an OpenAI-compatible server, a working
curl command, and a Python client snippet you can drop into an application.

## The Deployment Stack

`tt serve <model>` picks one of three serving paths from the model:

| Path | Chosen when | What it runs |
|---|---|---|
| **tt-inference-server** | The model is in the released catalog (`tt model list` shows source `tt-inference-server`). The default. | tt-inference-server's `run.py`, which starts a vLLM container from a pinned image. |
| **TT-Studio** | The model is only in TT-Studio's catalog, or you pass `--studio`. | TT-Studio's `run.py`, which brings up its services, deploys the model, and gives you a web UI. |
| **tt-model-manager** | The name is a community bundle (`namespace/name`). | `tt-model`, which serves a bundle published to Hugging Face. See [Community Models](/ml-practitioner/02-model-zoo/). |

`tt model info <model>` lists the paths a model supports, and `--inference-server`, `--studio` or
`--model-manager` forces one. All three produce an OpenAI-compatible API.

The **direct vLLM path** runs `vllm serve` yourself, for flags the managed path doesn't expose or
a newer vLLM than the pinned image ships. **vLLM is not installed on a QB2**, not in
`~/.tenstorrent-venv` and not on the host at all; the copy the managed path uses lives inside a
container image. Building that environment is its own project:
**[Build Your Own vLLM Environment →](/lessons/build-your-own-vllm/)**.

<img src="/assets/illustrations/inference-stack.svg" alt="Inference stack diagram showing the path from user interfaces through tt-inference-server and vLLM down to four Blackhole chips" class="spot-illustration">

## Serving with `tt serve`

```bash
tt serve Qwen3-32B                    # the model that ships with the box
tt serve Qwen3-32B --port 8000        # choose the host port
tt serve Qwen3-32B --dry-run          # show the resolved configuration and command
tt serve Llama-3.1-8B-Instruct --device p300   # use a different mesh than the detected one
```

**The default port is 20000**, which is `tt-inference-server`'s own default through `tt`. The
curl examples later in this chapter use 8000, so either start the server with `--port 8000` or
substitute `20000` in the examples.

`tt serve --dry-run` prints the exact `run.py` command `tt` would run. This is the best way to
learn what `tt` does for you, and to copy a command when you want to run it yourself:

```
/home/ttuser/.local/share/tenstorrent/tools/tt-inference-server-v0.25.0/venv/bin/python
  .../src/run.py --model Qwen3-32B --workflow server --docker-server --no-auth
  --host-volume /home/ttuser/data/tt-cache --device p300x2
  --vllm-override-args '{"enable-auto-tool-choice": true, "tool-call-parser": "hermes",
  "reasoning-parser": "qwen3"}' --service-port 20000
```

Three things `tt` adds that a bare `run.py` call does not:

* **The parsers.** `tool-call-parser` and `reasoning-parser` are in the model spec but
  `run.py` does not apply them on its own. Without them a container cannot answer
  `tool_choice: "auto"` requests, and coding agents get empty replies.
* **Weights.** It reuses a pre-seeded volume when one matches (the `--host-volume` above), and
  otherwise the Hugging Face cache (`--host-hf-cache`). See
  [Magic of symlinks](/first-timer/05-your-first-model/) and
  [Weights, Caches and Volumes](/lessons/weights-caches-volumes/).
* **The checklist.** It answers `run.py`'s interactive prompts for you and returns only when the
  endpoint is answering.

## Running `run.py` Yourself

:::callout type="warn"
**Two copies of tt-inference-server can be on the box.** `tt` uses its own pinned copy under
`~/.local/share/tenstorrent/tools/`. A machine set up with `tt-installer` alone also has a
checkout at `~/.local/lib/tt-inference-server` that `tt` does not use or update. On the test QB2
the two were `v0.25.0` and `v0.10.0-1138-g2aa7f72f`. Older guides, including some chapters of
this one, call the `~/.local/lib` copy. It still works, but it is older and its model list and
flags differ. Prefer `tt serve`, or the pinned copy below.
:::

`tt` keeps its own pinned copy of tt-inference-server under
`~/.local/share/tenstorrent/tools/tt-inference-server-<version>/`. You can call it directly. Two
reasons to: pinning a server to specific chips, and passing an option `tt serve` does not expose.
These details were verified on a QB2:

```bash
cd ~/.local/share/tenstorrent/tools/tt-inference-server-v0.25.0/src   # run.py reads ./VERSION
export HF_TOKEN=$(cat ~/.cache/huggingface/token)
export MODEL_SOURCE=huggingface     # otherwise it asks "How do you want to provide a model?"
export JWT_SECRET=unused            # otherwise it asks for a secret, even with --no-auth

../venv/bin/python run.py \
  --model Llama-3.1-8B-Instruct --workflow server --docker-server --no-auth \
  --host-hf-cache ~/.cache/huggingface \
  --device p300 --device-id 2,3 --service-port 20000 --bind-host 127.0.0.1 \
  --vllm-override-args '{"enable-auto-tool-choice": true, "tool-call-parser": "llama3_json"}'
```

`--no-auth` turns authentication off, and `run.py` publishes the port on every network
interface by default (`--bind-host 0.0.0.0` in v0.25.0). `--bind-host 127.0.0.1` keeps this server
reachable from the QB2 itself only; reach it from another machine with an SSH tunnel. Leave auth
on, and drop `--no-auth`, before you expose a server to a network. (The flag is in v0.25.0's
`run.py`; we added it to this command after the test run described above.)

Without `MODEL_SOURCE` and `JWT_SECRET`, run from a script or an SSH session, `run.py` stops with
`EOFError` at a prompt nobody can answer. Without the `--vllm-override-args` line the server
starts but cannot do tool calling.

### Pinning a server to specific chips

`tt serve` gives the container every `/dev/tenstorrent` node. `run.py --device-id 2,3` gives it
only chips 2 and 3, which lets two servers share the machine. In our test, Llama-3.1-8B served on
chips 2 and 3 (one P300 board) while Qwen3-Coder-Next kept running on chips 0 and 1; the
`Opening user mode device driver` and `Fabric initialized on 2 devices` lines in the server log
confirm which chips it opened. Which board holds which chip numbers is in `tt device status`
(the `#` column) and `tt device info` (the `board_id` row). If you share the machine with other
people or agents, take a lease first (`gozer`) so two servers never claim the same chips.

:::callout type="warn"
**A weights cache that contains links leaving its directory fails inside the container.** The
server mounts only `~/.cache/huggingface/hub/models--<org>--<name>`. If the files in
`snapshots/` are links into a shared blob store elsewhere, they dangle inside the container and
the server stops with `FileNotFoundError: …/model-00001-of-00004.safetensors`, even though the
files open on the host. See [Magic of symlinks](/first-timer/05-your-first-model/).
:::

:::callout type="tip"
**`--device`.** `p300x2` is the whole QB2. `p300` is one board. `p100` is a single Blackhole chip,
so it under-uses a QB2 rather than failing loudly. Not every model has every profile: `tt model
list` shows each model's profiles, and `tt model info <model>` shows the status per board. The
flag `--tt-device` is an accepted spelling of the same option, and many guides use it.
:::

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
| `20000` | `tt serve` default for tt-inference-server (OpenAI-compatible API) |
| `8000` | vLLM / `run.py` default, and `tt serve --port 8000` |
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
tt serve Llama-3.3-70B-Instruct --device p300x2
```

The model weights distribute across all four chips' DRAM, and the KV cache is allocated per
chip across the mesh. From the client's perspective the API is identical — same URL, same
request format.

Setting the mesh by hand is a direct-vLLM concern — `MESH_DEVICE`, its accepted names, and the
case difference from `--tt-device` are covered in [Build Your Own vLLM
Environment](/lessons/build-your-own-vllm/). One thing carries over to this path regardless:

:::callout type="tip"
**Two-chip meshes.** Earlier versions of this page said a two-chip mesh fails fabric bring-up
(`Fabric Router Sync: Timeout after 10000 ms … Ethernet handshake likely failed`). On a QB2
running TT-KMD 2.11.0 and firmware bundle 19.16.0, a `p300` mesh on **one board** (chips 2 and
3) came up cleanly (`Fabric initialized on 2 devices`) and served Llama-3.1-8B-Instruct. We did
not retest the older failure, a pair of chips on different boards, or the other board's pair.
If you see the timeout on your box, check `tt update --dry-run` for a newer firmware first, and
use `p150` (one chip) or `p300x2` (the whole box) in the meantime.
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
