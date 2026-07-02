---
title: The Model Zoo
currentChapter: 02-model-zoo
permalink: /ml-practitioner/02-model-zoo/
---
{% set persona = personas | findPersona(personaId) %}

# The Model Zoo

Four chips. Up to 560 Tensix compute cores available at once. The question isn't whether the hardware can handle real models — it's which ones, at what scale, and how to get them here.

## What's Supported

The QB2 supports a focused set of model families, optimized for Blackhole silicon. These aren't compatibility hacks — they're models with hand-tuned TTNN kernels for the Blackhole architecture, validated for throughput and output quality.

| Model Family | Variants | Chips Required | Disk Space |
|---|---|---|---|
| Qwen3 | 0.6B, 8B, 14B | 1 (0.6B/8B), 2-4 (14B) | 1.5 GB / ~16 GB / 28 GB |
| Llama 3.1 | 8B-Instruct | 1 | ~16 GB |
| Llama 3.1 | 70B-Instruct | 4 | ~140 GB |
| Mistral | 7B-Instruct | 1 | ~14 GB |

The model zoo lesson in tt-vscode-toolkit covers this in interactive depth, with live benchmarks you can run against your own QB2: [tt-vscode-toolkit lessons →](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/)

{% chunk "tt-studio-media-gen" %}

## Picking a Starting Point

**Qwen3-0.6B** is the fastest way to confirm the stack is working. It downloads in seconds, loads in under a minute, and produces real answers. For evaluation, prototyping, and smoke-testing your setup, this is the right choice. Think of it as the "hello world" of this hardware.

**Llama-3.1-8B-Instruct** is where you start if you need production-quality output on a single chip. Strong reasoning, strong instruction-following, 128K context. The model most people actually use for serious work on a single Blackhole.

**Qwen3-8B** is a strong alternative in the same size class as Llama-3.1-8B. Use it if your workload benefits from Qwen's architectural choices, or to compare against the 0.6B for quality/speed tradeoffs.

**Llama-3.1-70B-Instruct** requires all four chips and 140 GB of storage. It's the top-of-rack option for workloads where quality is the priority. Inference speed is lower than the 8B, but the output quality difference is real on complex tasks.

<div class="rcard-grid">

{% card "model", "https://huggingface.co/Qwen/Qwen3-0.6B", "Qwen3-0.6B", "The fastest way to confirm the stack is working — the \"hello world\" of this hardware. Single chip.", "0.6B · 1.5 GB" %}

{% card "model", "https://huggingface.co/meta-llama/Llama-3.1-8B-Instruct", "Llama-3.1-8B-Instruct", "Production-quality output on a single chip — strong reasoning, strong instruction-following, 128K context.", "8B · ~16 GB · gated" %}

{% card "model", "https://huggingface.co/Qwen/Qwen3-8B", "Qwen3-8B", "Qwen's 8B-class model — a strong single-chip alternative to Llama-3.1-8B for workloads that benefit from Qwen's architecture.", "8B · ~16 GB" %}

{% card "model", "https://huggingface.co/meta-llama/Llama-3.1-70B-Instruct", "Llama-3.1-70B-Instruct", "The top-of-rack option for quality-first workloads — requires all four chips and 140 GB of storage.", "70B · ~140 GB · gated" %}

</div>

## Downloading Models

The `hf` CLI is pre-installed. Use it — not `huggingface-cli`, not Python API calls. The `hf` command is faster and handles partial downloads and resumption correctly.

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
    model-00001-of-00002.safetensors
    model-00002-of-00002.safetensors
    ...
  Llama-3.1-8B-Instruct/
    config.json
    tokenizer.json
    ...
  Llama-3.1-70B-Instruct/
    ...
```

## Qwen3 Reasoning Modes

Qwen3 models support two inference modes: **thinking mode** and **non-thinking mode**. In thinking mode, the model emits `<think>...</think>` tokens before its final answer — extended chain-of-thought reasoning that improves quality on multi-step problems at the cost of more tokens and higher latency.

When calling through the OpenAI-compatible API, pass `enable_thinking` in the request body:

```python
# Thinking mode (default for Qwen3) — slower, more thorough
response = client.chat.completions.create(
    model="Qwen3-0.6B",
    messages=[{"role": "user", "content": "What is 17 * 23 + 48?"}],
    extra_body={"enable_thinking": True}
)

# Non-thinking mode — faster, direct answers
response = client.chat.completions.create(
    model="Qwen3-0.6B",
    messages=[{"role": "user", "content": "What is 17 * 23 + 48?"}],
    extra_body={"enable_thinking": False}
)
```

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
