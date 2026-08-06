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

<img src="/assets/illustrations/inference-stack.svg" alt="Inference stack diagram showing the path from user interfaces through tt-inference-server and vLLM down to four Blackhole chips" class="spot-illustration" style="max-width:100%; margin: 2em 0;">

## Path 1: Direct vLLM

```bash
# Activate the main tenstorrent venv
source ~/.tenstorrent-venv/bin/activate

# Blackhole architecture flag
export TT_METAL_ARCH_NAME=blackhole

# Mesh shape. This — not --tensor-parallel-size — is how you choose chips.
# P300 = one card (2 chips). P300x2 = all four chips of a QB2.
export MESH_DEVICE=P300

# Model load and first compile far exceed vLLM's default RPC deadline (10s)
export VLLM_RPC_TIMEOUT=900000

# HF_MODEL is required when --model is a local path: tt-metal's tt_transformers
# uses it as the checkpoint directory, not just a name.
export HF_MODEL=~/models/Llama-3.1-8B-Instruct

vllm serve ~/models/Llama-3.1-8B-Instruct \
  --served-model-name meta-llama/Llama-3.1-8B-Instruct \
  --port 8000
```

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

`--tt-device p300x2` is what identifies a QB2 — two P300 cards, four chips. Use `p300` for a
single card. **`p100` is a single Blackhole chip**, so it under-uses a QB2 rather than failing
loudly. The full list of options is in the [tt-inference-server lesson →](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-inference-server/)

On this path you do **not** set `MESH_DEVICE` or `TT_MESH_GRAPH_DESC_PATH` yourself — `run.py`
derives them per model from its spec, and on a QB2 the correct value is model-dependent.

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
Continuous batching is fundamentally different from static batching. Static batching waits to collect N requests before dispatching — it adds latency to achieve throughput. Continuous batching inserts new decode sequences into the in-flight batch as slots open up, achieving throughput without adding per-request waiting time. vLLM pioneered this for transformer inference. Tenstorrent's vLLM backend carries it onto Blackhole, where KV-cache management happens in L1 and DRAM across the chip grid.
:::

## Port Map

Keep these ports clear. Other services on the QB2 use them.

| Port | Service |
|---|---|
| `8000` | vLLM / tt-inference-server (OpenAI-compatible API) |
| `3000` | tt-studio (web UI) |
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

## Multi-Chip: Using All Four Chips

:::callout type="warn"
**`--tensor-parallel-size` does not work here.** The Tenstorrent platform rejects both tensor
parallel and pipeline parallel outright, before anything reaches the device. Multi-chip is
selected by the **mesh shape** instead. If you have seen `--tensor-parallel-size 4` in older
QB2 notes — including earlier versions of this page — that is why it failed.
:::

For 70B models, set `MESH_DEVICE=P300x2` to put all four Blackhole chips in one mesh:

```bash
# Direct vLLM across all four chips
export TT_METAL_ARCH_NAME=blackhole
export MESH_DEVICE=P300x2            # (1,4) — two P300 cards, four chips
export VLLM_RPC_TIMEOUT=900000
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
matters: it is `P300x2` with a lowercase `x`.

:::callout type="tip"
**Status on our hardware.** The four-chip serving path brings up correctly — the plugin selects
the TT platform, opens all four chips, loads weights and allocates the KV cache on the mesh, and
the OpenAI-compatible endpoints respond. We have **not** yet signed off on output quality: in our
testing generation degenerated into repetition, and we reproduced that across two vLLM versions,
three models, and both one- and four-chip meshes — so it is not specific to the mesh. Our current
suspicion is host firmware and driver versions running ahead of the tested pairings. Treat
four-chip throughput numbers as unverified until that is resolved.
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

Run this **inside an environment that already has a working `ttnn`** — on a QB2 that is
`~/.tenstorrent-venv`. The plugin binds to whatever tt-metal that environment provides.

```bash
source ~/.tenstorrent-venv/bin/activate

# uv is required: the installer uses `uv pip`'s --override, which pip has no equivalent for
python3 -m pip install --upgrade pip setuptools wheel uv

git clone https://github.com/tenstorrent/vllm-tt-plugin.git ~/vllm-tt-plugin
cd ~/vllm-tt-plugin
source docs/install-vllm-tt.sh
```

That installer pins upstream `vllm==0.24.0`, removes a CUDA `torchaudio` that cannot load beside
a CPU torch, and installs the plugin itself.

:::callout type="warn"
**The `--override` in that script is not optional.** `ttnn` requires `numpy<2`, while vLLM's
opencv dependency floor wants `numpy>=2`. Resolve vLLM without the override and the install
*appears to succeed*, then `import ttnn` fails — and since the plugin only activates when `ttnn`
imports, vLLM starts up quietly seeing no hardware. Running the shipped installer applies it
for you; hand-rolling the pip commands is where people get bitten.
:::

Two dependencies the installer does not cover, because upstream assumes you are installing into
a full tt-metal environment:

```bash
uv pip install --override docs/vllm-overrides.txt pytest
uv pip install --override docs/vllm-overrides.txt \
  --extra-index-url https://download.pytorch.org/whl/cpu --index-strategy unsafe-best-match \
  torchvision
```

`pytest` because tt-metal's `models/common/utility_functions.py` imports it at module scope, and
`torchvision` because transformers' image processor imports it while vLLM inspects the TT model
class. Missing either shows up as `Model architectures [...] failed to be inspected`, which does
not obviously point at a missing test framework.

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
