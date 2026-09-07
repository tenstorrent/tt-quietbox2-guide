---
title: vLLM on QB2
currentChapter: 03-vllm-on-qb2
permalink: /ml-practitioner/03-vllm-on-qb2/
---
{% set persona = personas | findPersona(personaId) %}

# vLLM on QB2

This is the chapter with the most practical density. By the end of it you'll have a running OpenAI-compatible inference server, a working curl command, and a Python client snippet you can drop into any application. Everything in this chapter is production-ready, not toy code.

## The Deployment Stack

There are two paths to running models as a server, and only one of them works out of the box.

The **tt-inference-server path** wraps the vLLM backend in a Docker container with one-command deploy syntax. This is what tt-studio and tt-local-generator use internally. It handles Docker pulls, environment setup, and port mapping automatically. It is pre-installed at `~/.local/lib/tt-inference-server`, and it is where you should start.

The **direct vLLM path** runs `vllm serve` yourself for more control and lower ceremony — but you have to build that environment first. **vLLM is not installed on a QB2.** It isn't in `~/.tenstorrent-venv` (which holds `tt-smi` and `tt-flash` and nothing else) and it isn't on the host at all; the copy the managed path uses lives inside a container image. So Path 1 below is a thing you set up deliberately, not a thing you find.

Both paths produce the same OpenAI-compatible API on port 8000.

:::callout type="tip"
**If you just want a server running, skip to [Path 2](#path-2-tt-inference-server).** Path 1 is
worth the setup when you need flags `run.py` doesn't expose, or a newer vLLM than the pinned
image ships — see [Running the latest vLLM plugin](#running-the-latest-vllm-plugin) for how that
environment gets built.
:::

<img src="/assets/illustrations/inference-stack.svg" alt="Inference stack diagram showing the path from user interfaces through tt-inference-server and vLLM down to four Blackhole chips" class="spot-illustration" style="max-width:100%; margin: 2em 0;">

## Path 1: Direct vLLM

This assumes you have already built an environment with a working `vllm` **and** a working Python
`ttnn` — see [Running the latest vLLM plugin](#running-the-latest-vllm-plugin) below, which is the
supported way to get one. Substitute your own venv for `~/.venvs/vllm-tt` throughout.

:::callout type="warn"
Build that venv anywhere except `~/.tenstorrent-venv`. Your QB2 activates that one at login and
it holds `tt-smi` and `tt-flash`; vLLM's dependency tree resolved on top of them is how people
lose their hardware tooling to an unrelated install.
:::

First get the weights (see [Model Zoo](/ml-practitioner/02-model-zoo/) for installing `hf`).
Qwen3-0.6B is small enough to download in a minute and start fast, which makes it a good first
model:

```bash
hf download Qwen/Qwen3-0.6B --local-dir ~/models/Qwen3-0.6B
```

:::callout type="tip"
`hf download` can succeed and still print a `click.exceptions.Exit: 0` traceback afterward — a
typer/click version mismatch, not a failed download. Check the files rather than the output:
`ls ~/models/Qwen3-0.6B` should show one or more `*.safetensors` files (one, for this model) and
a `config.json` — larger models shard weights across several `model-0000N-of-0000M.safetensors`
files, so don't treat the exact filename as a pass/fail signal.
:::

Then serve it:

```bash
# Your own vLLM environment — not the tooling venv
source ~/.venvs/vllm-tt/bin/activate

# Blackhole architecture flag
export TT_METAL_ARCH_NAME=blackhole

# Mesh shape. This — not --tensor-parallel-size — is how you choose chips.
# P150 = one chip, plenty for a 0.6B model — P300x2 (all four) is for the 70B
# example further down. Avoid the two-chip mesh (see below).
export MESH_DEVICE=P150

# Model load and first compile far exceed vLLM's default engine-ready deadline
export VLLM_ENGINE_READY_TIMEOUT_S=1800

# HF_MODEL is required when --model is a local path: tt-metal's tt_transformers
# uses it as the checkpoint directory, not just a name.
export HF_MODEL=~/models/Qwen3-0.6B

vllm serve ~/models/Qwen3-0.6B \
  --served-model-name Qwen3-0.6B \
  --block_size 64 --max_num_seqs 32 \
  --port 8000
```

:::callout type="warn"
**Two-chip meshes fail on our QB2.** `MESH_DEVICE=P300` dies during fabric bring-up:

```text
Fabric Router Sync: Timeout after 10000 ms on Device 2 ... Ethernet handshake likely failed
```

One chip (`P150`) and all four (`P300x2` / `P150x4`) both work; two does not, reproducibly across
board resets. Neither escape hatch helps — `fabric_config: DISABLED` opens the mesh and then
fails on `Trying to get un-initialized fabric context`, and `fabric_reliability_mode:
RELAXED_INIT` gives the same timeout. Until that is understood, pick `P150` or `P300x2`.
:::

:::callout type="tip"
`Qwen3-0.6B` has no entry in tt-metal's `tt_transformers` model table, but the plugin registers
`Qwen3ForCausalLM` generically, so it serves anyway. `--block_size 64` and `--max_num_seqs 32`
come from the plugin's own `examples/server_example_tt.py` rather than vLLM's defaults.
:::

:::callout type="tip"
**Check that vLLM actually claimed your hardware.** Whichever vLLM your box shipped with, the
startup log tells you: look for a line naming the `tt` platform as it initialises. If vLLM
starts but never mentions Tenstorrent, it is running without hardware support and every
request will be slow or wrong rather than failing outright.

If you want the newest Tenstorrent vLLM rather than what shipped, see
[Running the latest vLLM plugin](#running-the-latest-vllm-plugin) at the end of this chapter.
:::

On first run: the model weights get compiled into Blackhole-optimized op graphs. This takes 3–5 minutes. Subsequent starts are fast — the compiled artifacts are cached.

Watch the logs. When you see a line containing `Application startup complete`, the server is accepting requests.

:::callout type="tip"
The `TT_METAL_ARCH_NAME=blackhole` environment variable is required for Blackhole hardware — vLLM's Tenstorrent backend needs it to select the correct device. If you see errors about unknown architecture or device initialization failures, this is the first thing to check.
:::

:::callout type="warn"
**`ImportError` before hardware is even touched** (e.g. `cannot import name '...' from 'transformers...'`) means the venv's `transformers` version has drifted out of sync with the pinned Tenstorrent vLLM fork — not a device or driver problem. This venv accumulates whatever else gets `pip install`ed into it over time, and vLLM forks pin transformers tightly. Check `pip show transformers vllm` for a sane pairing, and if it's drifted, re-run the vLLM+plugin installer to re-sync the two rather than upgrading `transformers` alone.
:::

## Path 2: tt-inference-server

The tt-inference-server is pre-installed at `~/.local/lib/tt-inference-server`. It handles the Docker container lifecycle for you.

```bash
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
downloaded to the Hugging Face cache instead of re-pulling them into a fresh Docker volume — see
["Check Space Before Downloading"](/ml-practitioner/02-model-zoo/) in the previous chapter for
why that disk hit matters. `--no-auth` skips JWT authentication for
local, unauthenticated serving (fine on a trusted LAN, not for internet exposure). `--service-port`
sets the port the managed model's container API listens on — e.g. `--service-port 8002`. A full
command combining them:

```bash
python3 ~/.local/lib/tt-inference-server/run.py \
  --model Qwen3-32B \
  --tt-device p300x2 \
  --workflow server --docker-server \
  --no-auth --service-port 8002 --host-hf-cache
```
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
    "model": "Llama-3.1-8B-Instruct",
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
Take the string from `/v1/models` rather than from an example: Path 2 reports the model as you
named it in `--model`, while Path 1's `--served-model-name` above renames it to `Qwen3-0.6B`.
The examples below use `Llama-3.1-8B-Instruct` (Path 2's naming); substitute whatever your box
actually reports — `curl -s http://localhost:8000/v1/models | python3 -m json.tool` tells you.
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
    model="Llama-3.1-8B-Instruct",
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
    model="Llama-3.1-8B-Instruct",
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

For 70B models, set `MESH_DEVICE=P300x2` to put all four Blackhole chips in one mesh:

```bash
# Direct vLLM across all four chips — from your own vLLM venv (see Path 1)
source ~/.venvs/vllm-tt/bin/activate
export TT_METAL_ARCH_NAME=blackhole
export MESH_DEVICE=P300x2            # (1,4) — two P300 cards, four chips
export VLLM_ENGINE_READY_TIMEOUT_S=1800
export HF_MODEL=~/models/Llama-3.1-70B-Instruct

vllm serve ~/models/Llama-3.1-70B-Instruct \
  --served-model-name meta-llama/Llama-3.1-70B-Instruct \
  --port 8000

# Or with tt-inference-server, which picks the mesh for you
python3 ~/.local/lib/tt-inference-server/run.py \
  --model Llama-3.1-70B-Instruct \
  --tt-device p300x2 \
  --workflow server --docker-server
```

The model weights distribute across all four chips' DRAM, and the KV cache is allocated per
chip across the mesh. From the client's perspective the API is identical — same URL, same
request format.

The mesh names the plugin accepts on Blackhole are `P100` and `P150` (single chip), `P300` and
`P150x2` (two chips), `P150x4` and `P300x2` (four chips), and `P150x8` (eight). Spelling
matters: it is `P300x2` with a lowercase `x` — and note the case difference between the two
surfaces, since they are easy to cross-wire: `MESH_DEVICE` takes `P300x2`, while
`run.py --tt-device` takes `p300x2`. Names with the same chip count are equivalent — the plugin
maps each to a grid shape, so `P300x2` and `P150x4` are both `(1, 4)` on a QB2.

Accepted is not the same as working. The two-chip meshes (`P300`, `P150x2`) are the ones to avoid
on a QB2 — see the fabric bring-up warning under Path 1.

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

## Running the latest vLLM plugin

*Advanced, and entirely optional.* Everything above works with the vLLM your QB2 shipped with.
This section is for when you want to run ahead of it.

Tenstorrent's vLLM support has been extracted into a standalone **platform plugin**,
[tenstorrent/vllm-tt-plugin](https://github.com/tenstorrent/vllm-tt-plugin). It runs against
*upstream* vLLM rather than a Tenstorrent fork: the plugin contributes a `tt` platform through
vLLM's normal out-of-tree plugin mechanism, and vLLM selects it automatically whenever `ttnn`
is importable.

:::callout type="warn"
**This is not what tt-inference-server uses.** As of v0.19.0 its images still clone the
Tenstorrent vLLM fork and install the copy of the plugin that lives inside it, pinned per model.
So "Path 2" above and this section are genuinely different stacks. Do this on a box you are
happy to experiment on, not one you depend on.
:::

### What you gain

Newer model support lands in the plugin before it reaches a tt-inference-server release, and
you get a normal upstream vLLM underneath — so upstream features and fixes arrive without
waiting for a fork to rebase.

### Installing it

Run this **inside an environment that already has a working Python `ttnn`**. The plugin binds to
whatever tt-metal that environment provides, and it only activates when `import ttnn` succeeds.

Finding such an environment is the real work on a QB2, and it is worth being clear-eyed about it:

- `~/.tenstorrent-venv` is **not** one. It contains `tt-smi` and `tt-flash`; `import ttnn` fails there.
- The apt packages `tt-metalium` and `tt-nn` are the **C++ runtime libraries**, not the Python module.
- The Python `ttnn` on a QB2 lives inside the Metalium container. The `tt-metalium` wrapper runs
  that container with `--rm`, so anything you pip-install in a session is gone when you exit —
  to use it as a base you need a derived image (`FROM` the Metalium image) that installs the
  plugin at build time.

So the practical options are a container image you build yourself, or a venv where you have
installed a `ttnn` wheel from Tenstorrent's package index. Confirm before you start:

```bash
source ~/.venvs/vllm-tt/bin/activate
python3 -c "import ttnn; print('ttnn ok')"   # must succeed, or the plugin will never activate

# uv is required: the installer uses `uv pip`'s --override, which pip has no equivalent for
python3 -m pip install --upgrade pip setuptools wheel uv

git clone https://github.com/tenstorrent/vllm-tt-plugin.git ~/vllm-tt-plugin
cd ~/vllm-tt-plugin
source docs/install-vllm-tt.sh
```

That installer pins upstream `vllm==0.26.0`, removes a CUDA `torchaudio` that cannot load beside
a CPU torch, and installs the plugin itself. It fetches vLLM's dependency list from
`raw.githubusercontent.com`, so it needs network access beyond your package index.

:::callout type="warn"
**The `--override` in that script is not optional.** `ttnn` requires `numpy<2`, while vLLM's
opencv dependency floor wants `numpy>=2`. Resolve vLLM without the override and the install
*appears to succeed*, then `import ttnn` fails — and since the plugin only activates when `ttnn`
imports, vLLM starts up quietly seeing no hardware. Running the shipped installer applies it
for you; hand-rolling the pip commands is where people get bitten.
:::

One dependency the installer does not cover, because upstream assumes you are installing into
a full tt-metal environment:

```bash
uv pip install --override docs/vllm-overrides.txt pytest
```

`pytest` because tt-metal's `models/common/utility_functions.py` imports it at module scope.
Missing it shows up as `Model architectures [...] failed to be inspected`, which does not
obviously point at a missing test framework. Earlier versions of this page also had you install
`torchvision` by hand; the installer now does it for you, so check
`python3 -c "import torchvision"` before adding it.

### Serving a model with the plugin

`vllm serve` works exactly as it does above. On a QB2, with the mesh caveat from Path 1 in mind:

```bash
source ~/.venvs/vllm-tt/bin/activate          # the plugin venv from "Installing it" above

export MESH_DEVICE=P150                       # or P300x2 for all four chips
export HF_MODEL=~/models/Qwen3-0.6B

vllm serve ~/models/Qwen3-0.6B \
  --served-model-name Qwen3-0.6B \
  --block_size 64 --max_num_seqs 32 \
  --port 8003
```

The plugin disables chunked prefill for TT models and raises `max_num_batched_tokens` to match
`max_model_len`; both are logged at startup and neither needs your input.

### Checking what you already have

Before installing, it is worth knowing what is on the box — some QB2s carry an older fork
checkout. Run this in the environment you serve from. It only *locates* packages and never
imports vLLM, because a stale install often fails on import and would hide the answer:

```bash
python3 - <<'EOF'
import importlib.util
from importlib.metadata import distributions

def where(mod):
    try:
        spec = importlib.util.find_spec(mod)
    except Exception:
        return None
    return spec.origin if spec and spec.origin else None

def versions(name):
    want = name.lower().replace("_", "-")
    seen = []
    for dist in distributions():
        try:
            if (dist.metadata["Name"] or "").lower().replace("_", "-") == want:
                seen.append(dist.version)
        except Exception:
            pass
    return list(dict.fromkeys(seen))

for label, mod, dist in (("vllm", "vllm", "vllm"),
                         ("plugin", "vllm_tt_plugin", "vllm-tt-plugin"),
                         ("ttnn", "ttnn", "ttnn")):
    print(f"{label:8}: {', '.join(versions(dist)) or 'not installed'} | {where(mod) or '-'}")
EOF
```

A `vllm` outside `site-packages` (say under `~/tt-vllm`) is a fork checkout. To move across,
uninstall first so the old one cannot shadow the new — `uv pip uninstall vllm vllm-tt-plugin`
— then follow the install above. Old clones are harmless to leave on disk once uninstalled.

### Status, honestly

On our QB2 this brings up correctly: the plugin activates, `TTPlatform` is selected, all four
Blackhole chips open, weights load, the KV cache allocates across the mesh, and the
OpenAI-compatible endpoints respond.

**We have not signed off on output quality.** In our testing generation degenerated into
repetition, and that reproduced across two vLLM versions, three models, and both one- and
four-chip meshes — so it is not specific to this plugin or to the mesh. Host firmware and driver
versions running ahead of the tested pairings is the current suspicion. Treat this path as
something to experiment with, not to benchmark against.

---

<figure class="video-demo">
<img src="/assets/video/09-vllm-demo.gif" alt="Activating the TTNN venv, checking hardware with tt-smi, vLLM serve command on a QB2" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">Venv setup and hardware check before serving — four p300c chips ready</figcaption>
</figure>

---

**Next:** [Performance Tuning →](/ml-practitioner/04-performance-tuning/)
