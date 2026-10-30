---
title: The Model Zoo
currentChapter: 02-model-zoo
permalink: /ml-practitioner/02-model-zoo/
---
{% set persona = personas | findPersona(personaId) %}

# The Model Zoo

Four chips. Up to 560 Tensix compute cores available at once. The question isn't whether the hardware can handle real models — it's which ones, at what scale, and how to get them here.

## What's Supported

:::callout type="tip"
**Ask `tt` first.** The table below is a snapshot. The live answer for your machine is
`tt model list` (models with a serving profile for your detected hardware) and
`tt model info <name>` (disk and RAM needed, and the validation status on each board). `tt model
list --catalog` shows only the released catalog, `--type llm` narrows by kind, and `--all` shows
every model on every device.
:::

The QB2 supports a focused set of model families, optimized for Blackhole silicon. These aren't compatibility hacks — they're models with hand-tuned TTNN kernels for the Blackhole architecture, validated for throughput and output quality.

| Model Family | Variants | Chips Required | Disk Space |
|---|---|---|---|
| Qwen3 | 0.6B, 8B, 14B | 1 (0.6B/8B), 2-4 (14B) | 1.5 GB / ~16 GB / 28 GB |
| Qwen3 | 32B | 4 | ~64 GB |
| Llama 3.1 | 8B-Instruct | 1 | ~16 GB |
| Llama 3.1 | 70B-Instruct | 4 | ~140 GB |
| Llama 3.3 | 70B-Instruct | 4 | ~140 GB |
| Mistral | 7B-Instruct | 1 | ~14 GB |

The model zoo lesson in tt-vscode-toolkit covers this in interactive depth, with live benchmarks you can run against your own QB2: [tt-vscode-toolkit lessons →](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/)

{% chunk "tt-studio-media-gen" %}

## Community Models and tt-model-manager

The released catalog is the models Tenstorrent ships and tests through tt-inference-server.
Beyond it, anyone can publish a **model bundle** to the Hugging Face Hub with
[tt-model-manager](https://github.com/tenstorrent/tt-model-manager): a bring-up packaged so that
someone else can serve it with the same commands they use for catalog models. A bundle carries
the engine the author built and a pointer to the weights, which download into your own Hugging
Face cache under your own token.

:::callout type="warn"
**Community models are not reviewed by Tenstorrent. Serve at your own risk.** Bundles are
published by their owners. Tenstorrent does not test or maintain them, and a bundle can run code
and download weights you have not looked at. Read `tt model info` and the author's page before you
pull one, and do not point one at data you would not trust to a stranger's software. Compatibility
checks (below) catch a wrong chip architecture, not a bad or unsafe model.
:::

To browse instead of search, the [tt-awesome model browser](https://docs.tenstorrent.com/tt-awesome/models/)
lists every catalog model and community bundle by collection, family, kind and hardware, with the
commands to install and run each. It marks community bundles with the same warning.

```bash
tt model search qwen3 --limit 5     # find published bundles on the Hub
tt model list --community           # community bundles that run on this machine
tt model info raahemnabeel/qwen3-coder-next    # manifest and compatibility verdict
tt model pull raahemnabeel/qwen3-coder-next
tt model profiles raahemnabeel/qwen3-coder-next
tt serve raahemnabeel/qwen3-coder-next         # served by tt-model-manager
```

A real search on a QB2:

```
          tt-model bundles on the Hub — every published bundle matching 'qwen3'
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━━┳━━━━━━━━━━━┓
┃ name                                ┃ visibility ┃ downloads ┃ updated    ┃ installed ┃
┡━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━━╇━━━━━━━━━━━┩
│ raahemnabeel/qwen3-5-122b-a10b      │ public     │ 0         │ 2026-10-28 │ —         │
│ raahemnabeel/qwen3-coder-next       │ public     │ 0         │ 2026-10-28 │ ✓         │
│ episod/qwen3.8-27b-dflash2-p300     │ public     │ 0         │ 2026-10-28 │ ✓         │
└─────────────────────────────────────┴────────────┴───────────┴────────────┴───────────┘
```

Names are `namespace/name`. A name with a slash that is not a catalog model is a bundle, and `tt
serve` routes it to tt-model-manager. `tt model ps` lists both kinds side by side, with a
`backend` column (`inference-server` or `model-manager`) and the port each is on.

How to choose:

| If you want | Use |
|---|---|
| The most tested path, a model Tenstorrent supports | A catalog model: `tt serve Qwen3.8-27B` |
| A newer or different model, and you accept less testing | A community bundle: `tt serve namespace/name` |
| To publish your own bring-up for others | `tt-model package` and `tt-model push`, described in the [community models guide](https://github.com/tenstorrent/tt-cli/blob/main/docs/community-models.md) |

Compatibility is **checked, not guaranteed**: pulling or serving a bundle checks that its
binaries were built for your chip architecture (a mismatch fails on purpose) and warns if your
box has fewer chips than the profile needs. Read `tt model info` before a large download.

### "I want to..." and what to search

These are all community bundles, so the warning above applies to every row.
`tt model search` matches the text of a bundle's name, so search for a model family or a task
word that models usually carry in their name. These all returned bundles on a QB2 on 2026-10-28.
Bundles are published often, so your results will differ.

| I want to... | Try | What came back |
|---|---|---|
| Write code with a local model | `tt model search coder` | `raahemnabeel/qwen3-coder-next`, `raahemnabeel/qwen3-coder-30b-a3b` |
| Try the newest Qwen on my box | `tt model search qwen3.8` | `episod/qwen3.8-27b-dflash2-p300`, `episod/qwen3.8-27b-pi-p300` |
| Chat with a Gemma or Llama model | `tt model search gemma`, `tt model search llama` | `stisiTT/gemma-4-12b-it-p150`, `stisiTT/llama-3.2-3b-blackhole-v51` |
| Generate or edit images | `tt model search image`, `tt model search flux` | `sunandbean/qwen-image-edit-2511-p100a`, `stisiTT/flux2-dev-qb2` |
| Turn text into speech | `tt model search tts` | `tt-hous/qwen3-tts-1.7b-base`, `tt-hous/qwen3-tts-1.7b-voicedesign` |
| Make music | `tt model search music` | `jashansinghTT/minimax-music3-blackhole` |
| Embed text for search | `tt model search embed` | `tt-hous/embeddinggemma-2` |
| Detect objects or segment images | `tt model search yolo`, `tt model search sam` | `changh95/yolox-p150`, `changh95/sam3-p150` |
| Estimate depth or reconstruct 3D | `tt model search depth`, `tt model search mast3r` | `changh95/depth-anything-3-p150`, `changh95/mast3r-p150` |
| Work on self-driving perception | `tt model search bev` | `changh95/bevdet-p150`, `changh95/bevformer-p150`, `changh95/bevfusion-p150` |
| Run a robot policy | `tt model search pi05` | `changh95/pi05-base-p300x2` |

The two coder bundles are the fast ones for agents: 30B and 80B parameters on disk, 3B active
per token. Measured 2026-10-30 on one P300 board (`--profile p300`), 384 output tokens at
temperature 0: `qwen3-coder-30b-a3b` 80 tok/s, `qwen3-coder-next` 107 tok/s. Their cards report
95 and 178 tok/s on all four chips (`--profile p300x2`). Both set the `qwen3_coder` tool parser,
and both passed the tt-agents tool-calling check (`00_verify_tools.py`). A bundle you pulled
earlier keeps the revision it was pulled at; if `tt serve` says `no serve profile named
'p300'` for a profile the card lists, add `-- --refresh` to fetch the current one.

Some searches found nothing (`whisper`, `video`, `robot`, `pose`, `rerank`). Two reasons:
speech-to-text and video models such as `whisper-large-v3` and `Wan2.2-T2V-A14B-Diffusers` are
**catalog** models, not bundles, so look for them with `tt model list --type audio` or
`tt model list --type video`. The other terms are just not in any bundle's name yet. Empty
results mean nobody has published one, not that the hardware cannot do it.

The suffix on a bundle name is the hardware it was built for. `-p150` is one chip, `-p300` is
one board of two chips, and `-p300x2` is the whole QB2, so a `-p150` bundle fits on a QB2 and a
`-p300x2` bundle needs all four chips. `tt model list --community --hw p300x2` shows only the
bundles that fit your machine, and `tt model search <query> --catalog` keeps just the ones in
the community catalog.

## Picking a Starting Point

**Qwen3-0.6B** is the fastest way to confirm the stack is working. It downloads in seconds, loads in under a minute, and produces real answers. Think of it as the "hello world" of this hardware — with one caveat worth knowing before you build a plan around it: it is **absent from `tt-inference-server`'s model list**, so `run.py --model Qwen3-0.6B` has nothing to select. It's a smoke test for direct TTNN work and for a hand-rolled `vllm serve`, not a model you can deploy down the managed path.

**Llama-3.1-8B-Instruct** is where you start if you need production-quality output on a single chip. Strong reasoning, strong instruction-following, 128K context. The model most people actually use for serious work on a single Blackhole.

**Qwen3-8B** is a strong alternative in the same size class as Llama-3.1-8B. Use it if your workload benefits from Qwen's architectural choices, or to compare against the 0.6B for quality/speed tradeoffs. Note that `tt-inference-server` lists it for `p300` (two chips) but **not** `p300x2` — and the two-chip mesh is the one that has failed fabric bring-up on our hardware. Llama-3.1-8B-Instruct, which has both a `p300` and a `p300x2` entry, is the lower-risk pick in this size class on a QB2.

**Llama-3.1-70B-Instruct** requires all four chips and 140 GB of storage. It's the top-of-rack option for workloads where quality is the priority. Inference speed is lower than the 8B, but the output quality difference is real on complex tasks.

**Qwen3-32B** is the best *zero-download* default: it comes pre-cached on QB2, so there's no multi-gigabyte pull standing between you and a real model. It needs all four chips (32B is the same size class as a 70B for chip-sizing purposes — use `--tt-device p300x2`), runs a 131K context window, and serves up to 8 concurrent requests. If you want a strong model running in the next sixty seconds, this is it.

**Llama-3.3-70B-Instruct** is the flagship choice — the same four-chip, 131K-context, up-to-8-concurrent profile as Qwen3-32B, but Meta's newest 70B-class weights for maximum output quality. See the [dedicated Llama-3.3-70B lesson](/lessons/llama-70b/) for a full walkthrough.

<div class="rcard-grid">

{% card "model", "https://huggingface.co/Qwen/Qwen3-0.6B", "Qwen3-0.6B", "The fastest way to confirm the stack is working — the \"hello world\" of this hardware. Single chip; not servable via tt-inference-server.", "0.6B · 1.5 GB" %}

{% card "model", "https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct", "Llama-3.1-8B-Instruct", "Production-quality output on a single chip — strong reasoning, strong instruction-following, 128K context.", "8B · ~16 GB · gated" %}

{% card "model", "https://huggingface.co/Qwen/Qwen3-8B", "Qwen3-8B", "Qwen's 8B-class model — a strong single-chip alternative to Llama-3.1-8B for workloads that benefit from Qwen's architecture.", "8B · ~16 GB" %}

{% card "model", "https://huggingface.co/Qwen/Qwen3-32B", "Qwen3-32B", "Pre-cached on QB2 — the best zero-download default. Four chips, 131K context, up to 8 concurrent requests.", "32B · ~64 GB" %}

{% card "model", "https://huggingface.co/meta-llama/Llama-3.1-70B-Instruct", "Llama-3.1-70B-Instruct", "The top-of-rack option for quality-first workloads — requires all four chips and 140 GB of storage.", "70B · ~140 GB · gated" %}

{% card "model", "https://huggingface.co/meta-llama/Llama-3.3-70B-Instruct", "Llama-3.3-70B-Instruct", "The flagship pick for maximum quality — Meta's newest 70B weights, same four-chip profile as Qwen3-32B.", "70B · ~140 GB · gated" %}

</div>

### Model-Suitability Caveats

Two more models are worth knowing about *before* you reach for them — especially for agentic or tool-calling use (see [`agents.md`](/agents.md)'s Coding Agents section for the tt-studio gateway setup), because neither holds up well under sustained multi-step agent loops:

:::callout type="warn"
**gemma-4-31B-it — EXPERIMENTAL.** In our testing this model crashed the runtime under sustained
agentic load. It's also the most context-limited of the models in this chapter (49K vs. 131K+
for the Qwen3/Llama models) and only serves one request at a time
(`max_num_seqs=1`, single-stream — no continuous-batching headroom). Fine for short, supervised
sessions; don't point a long-running agent loop at it yet.
:::

:::callout type="warn"
**Qwen3.6-27B — reasoning-first, not agent-first.** It has the longest context window here
(262K) and a dedicated tool parser (`qwen3_coder`), but it's tuned to reason at length before
acting, which tends to derail multi-step agent/tool loops that expect fast, decisive tool calls.
Like gemma-4-31B-it, it's single-stream (`max_num_seqs=1`). Good for one-shot reasoning-heavy
prompts; not the model to hand an autonomous coding agent.
:::

## Downloading Models

For catalog models, `tt` downloads for you: `tt serve <name>` fetches the weights on first use,
and `tt model pull <name>` fetches them ahead of time (`tt model pull Llama-3.1-8B-Instruct`
fetches into the Hugging Face cache and reports where). The `hf` commands below are for
downloading a repository you will use outside `tt`, such as the TTNN examples.

Downloads go through the `hf` CLI — not `huggingface-cli`, not Python API calls. It's faster and it handles partial downloads and resumption correctly.

It is **not** pre-installed. `huggingface_hub` isn't in any environment tt-installer creates, so
`hf` won't be on your PATH out of the box. Install it into an environment of its own — not
`~/.tenstorrent-venv`, which holds `tt-smi` and `tt-flash` and is activated for you at login:

```bash
uv tool install huggingface_hub     # or: pipx install huggingface_hub
hf version
```

```bash
# Make sure the models directory exists
mkdir -p ~/models

# Qwen3-0.6B — 1.5 GB, fast start
hf download Qwen/Qwen3-0.6B --local-dir ~/models/Qwen3-0.6B

# Llama-3.1-8B-Instruct — 16 GB, requires HF login with license acceptance
hf download meta-llama/Llama-3.1-8B-Instruct --local-dir ~/models/Llama-3.1-8B-Instruct

# Qwen3-8B — ~16 GB
hf download Qwen/Qwen3-8B --local-dir ~/models/Qwen3-8B

# Llama-3.1-70B-Instruct — 140 GB, plan your storage
hf download meta-llama/Llama-3.1-70B-Instruct --local-dir ~/models/Llama-3.1-70B-Instruct
```

Llama models require accepting the Meta license on Hugging Face first. If `hf download` returns a 401 or 403, run `hf login` and authenticate with a token that has access to the gated model.

:::callout type="warn"
Check your disk space before downloading large models. `df -h ~/models` shows available space. The 70B model is 140 GB — if your root partition is 256 GB, that's a significant commitment. A partial download leaves the directory in an incomplete state; use `hf download --resume-download` to continue interrupted downloads.
:::

## Model Storage Layout

Every Tenstorrent tutorial uses the `~/models/<family>-<variant>/` convention. The tt-inference-server `--model` flag accepts a path or a model name, but matching the convention means tutorial commands work verbatim.

```
~/models/
  Qwen3-0.6B/
    config.json
    tokenizer.json
    model.safetensors
    ...
  Llama-3.1-8B-Instruct/
    config.json
    tokenizer.json
    model-00001-of-00004.safetensors
    ...
    ...
  Llama-3.1-70B-Instruct/
    ...
```

Shard count depends on model size, not family — small models like Qwen3-0.6B download as one
`model.safetensors` file; larger ones split across several `model-0000N-of-0000M.safetensors`
files (verified against the actual repo file listings: Qwen3-0.6B is genuinely single-file —
confirmed by downloading it — and Llama-3.1-8B-Instruct is 4 shards).

## Qwen3 Reasoning Modes

Qwen3 models support two inference modes: **thinking mode** and **non-thinking mode**. In thinking mode, the model emits `<think>...</think>` tokens before its final answer — extended chain-of-thought reasoning that improves quality on multi-step problems at the cost of more tokens and higher latency.

When calling through the OpenAI-compatible API, `enable_thinking` is a **chat-template**
parameter, not a top-level sampling one — it goes through `extra_body`'s `chat_template_kwargs`,
the same way vLLM passes any other kwarg into the tokenizer's `apply_chat_template()`:

```python
# Thinking mode (default for Qwen3) — slower, more thorough
response = client.chat.completions.create(
    model="Qwen/Qwen3-32B",
    messages=[{"role": "user", "content": "What is 17 * 23 + 48?"}],
    extra_body={"chat_template_kwargs": {"enable_thinking": True}}
)

# Non-thinking mode — faster, direct answers
response = client.chat.completions.create(
    model="Qwen/Qwen3-32B",
    messages=[{"role": "user", "content": "What is 17 * 23 + 48?"}],
    extra_body={"chat_template_kwargs": {"enable_thinking": False}}
)
```

:::callout type="warn"
**Leave room for the thinking block.** With thinking on and a tight `max_tokens`, the entire
budget goes into `<think>…</think>` and you get back `finish_reason: "length"` with no answer at
all — which reads like a broken model rather than a truncated one. Either raise `max_tokens` or
pass `extra_body={"chat_template_kwargs": {"enable_thinking": False}}`, as above.
:::

For conversational workloads where speed matters, non-thinking mode is the better choice. For tasks where the reasoning trace improves output quality — math, code, multi-hop questions — thinking mode earns its overhead.

## Single-Chip vs. Four-Chip Layout

When you run a single-chip model, all 120 Tensix cores on one chip handle the entire forward pass. When you scale to four chips with tensor parallelism, attention heads split across chips and activations flow chip-to-chip via the Ethernet cores in the left and right columns of the grid.

{% tensixsystem "qb2", "70B tensor-parallel — attention heads split across four chips" %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">One chip for small models. Four chips sharing attention heads for 70B scale.</p>

## Check Space Before Downloading

```bash
# Check available space
df -h ~/models

# Verify a download completed (no missing shards)
ls -lh ~/models/Llama-3.1-8B-Instruct/*.safetensors | wc -l
```

A correctly downloaded Llama-3.1-8B-Instruct should have 4 safetensors shards. Qwen3-0.6B has 1.

<figure class="video-demo">
<img src="/assets/video/08-model-download-demo.gif" alt="Browsing Qwen3-0.6B model files, hf CLI version, disk usage on a QB2" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">Qwen3-0.6B already downloaded — files, size, and the hf download command</figcaption>
</figure>

---

**Next:** [Serving Models on QB2 →](/ml-practitioner/03-vllm-on-qb2/)
