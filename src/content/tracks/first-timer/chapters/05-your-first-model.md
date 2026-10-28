---
title: Serve a Model
currentChapter: 05-your-first-model
permalink: /first-timer/05-your-first-model/
---
{% set persona = personas | findPersona(personaId) %}

# Serve a Model

Four chips, one command. `tt serve` downloads or finds the weights, starts the model in a
container, waits until it answers, and tells you the address. What you get is an
OpenAI-compatible HTTP API running on your own hardware, which every chat app, coding agent
and SDK already knows how to talk to.

This chapter serves **Qwen3-32B**, the model your QB2 shipped with. Its weights and compiled
kernels are already on disk, so the first serve does not download 62 GB.

## Pick the Model

`tt` knows which models run on your hardware:

```bash
tt model list
```

On a QB2 it detects a `p300x2` configuration (two p300 boards, four chips) and lists the
models that have a serving profile for it. `tt model info` tells you what a model needs and how
well it is validated:

```bash
tt model info Qwen3-32B
```

```
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ hf_repo             │ Qwen/Qwen3-32B                                         │
│ type                │ llm                                                    │
│ engines             │ vLLM                                                   │
│ via                 │ inference-server, studio                               │
│ servable            │ yes — `tt serve Qwen3-32B` (`--studio` deploys it with │
│                     │ TT-Studio)                                             │
│ parameters          │ 32B                                                    │
│ min disk            │ 84 GB                                                  │
│ min ram             │ 80 GB                                                  │
│ on p300x2           │ vLLM — FUNCTIONAL, max context 131072                  │
│ ...                 │                                                        │
└─────────────────────┴────────────────────────────────────────────────────────┘
```

Validation status goes `EXPERIMENTAL`, `FUNCTIONAL`, `COMPLETE`. `FUNCTIONAL` means it runs
correctly and is not fully tuned. The status is per board, so check the `p300x2` row.

### Models worth starting with on a QB2

These have a `p300x2` profile in the released catalog, from `tt model list --catalog`:

| Model | Kind | Status on QB2 | Why start here |
|---|---|---|---|
| `Qwen3-32B` | LLM | FUNCTIONAL | Ships with the box. Weights and compiled cache are local. |
| `Qwen3.8-27B` | LLM | COMPLETE | Fully validated chat and reasoning model, 262k context. |
| `gemma-4-31B-it` / `gemma-4-12B-it` | LLM | COMPLETE | Fully validated, 262k context. |
| `Llama-3.3-70B-Instruct` | LLM | FUNCTIONAL | The largest LLM in the catalog for this box. |
| `FLUX.1-dev` / `FLUX.1-schnell` | Image | COMPLETE | Image generation. |
| `whisper-large-v3` | Audio | COMPLETE | Speech to text. |
| `Wan2.2-T2V-A14B-Diffusers` | Video | COMPLETE | Text to video. |

Gated models (Llama, Gemma) need you to accept the license on the model's Hugging Face page
first. The `hf_repo` line in `tt model info` names the page.

## Log In to Hugging Face

Serving needs a Hugging Face token, even for models that are free to download, because
`tt-inference-server` checks it before it starts. Log in once:

```bash
tt model login
```

Choose **Log in with your browser** (it shows a URL and a short code) or paste a read token
from [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens). `tt` finds the
token again on every later run, and `tt serve --dry-run` tells you where it came from without
printing it.

## Check That `tt` Will Reuse the Shipped Weights

Preview the serve before you run it. `--dry-run` starts nothing:

```bash
tt serve Qwen3-32B --dry-run
```

```
✓ Detecting device configuration  p300x2 (override with --device)
                    tt serve Qwen3-32B — dry run
┌──────────────────┬──────────────────────────────────────────────────────────┐
│ backend          │ tt-inference-server                                      │
│ workflow         │ server                                                   │
│ device           │ p300x2                                                   │
│ engines          │ vLLM                                                     │
│ status           │ FUNCTIONAL                                               │
│ docker image     │ ghcr.io/tenstorrent/tt-inference-server/vllm-tt-metal-…  │
│ tool-call parser │ hermes                                                   │
│ reasoning parser │ qwen3                                                    │
│ weights          │ /home/ttuser/data/tt-cache                               │
│                  │ pre-seeded volume — weights and tt_metal_cache reused;   │
│                  │ the HF cache is not consulted                            │
│ HF token         │ from the Hugging Face login store                        │
│ port             │ 20000  (server default)                                  │
└──────────────────┴──────────────────────────────────────────────────────────┘
```

Look at the `weights` row. **`pre-seeded volume`** means `tt` found the shipped weights *and*
the compiled kernel cache, so the first start takes minutes and downloads nothing. If it says
`~/.cache/huggingface` instead, `tt` did not recognize the shipped directory and a real serve
would download 62 GB. The fix is one symbolic link:

:::callout type="tip"
**Magic of symlinks.** `tt` looks for a volume named `volume_id_tt_transformers-Qwen3-32B-v<version>`
(the version comes from the model spec; the dry run's image tag shows it). The shipped directory
on our QB2 ended in `-vqb2_launch`, so we aliased it:

```bash
ln -s ~/data/tt-cache/volume_id_tt_transformers-Qwen3-32B-vqb2_launch \
      ~/data/tt-cache/volume_id_tt_transformers-Qwen3-32B-v0.17.0
```

Re-run the dry run after every `tt update`; if it falls back to the Hugging Face cache, the
version changed. Two more links are handy: `ln -s ~/.cache/huggingface/hub ~/models` for a short
path to downloaded weights, and `ln -s code/tt-metal ~/tt-metal` so older instructions work.
**Make links relative and keep targets inside your home directory.** Containers mount home at
`/home/user`, so absolute links and links that leave home dangle inside them (a Hugging Face
cache linking to a blob store outside the model directory failed this way).
:::

## Serve It

```bash
tt serve Qwen3-32B
```

`tt serve` shows the boot as a live checklist instead of thousands of log lines: host ready,
weights ready, image ready, container started, engine started, device opened, KV cache
configured, model warmed up, endpoint answering. It returns only once the endpoint answers, so
whatever you run next will work. When it finishes you get a box with the endpoint
(`http://127.0.0.1:20000/v1`) and the commands to look at logs and stop the model.

To watch the raw server log while it boots, run this in a second terminal:

```bash
tt model logs Qwen3-32B --follow
```

Pressing Ctrl-C in the `tt serve` terminal stops *watching*. The server is a separate container and keeps
booting, and `tt model stop Qwen3-32B` ends it.

:::callout type="tip"
**A first serve of a model you have not run before takes longer.** The image (about 18 GB) and
the weights are downloaded, then the model is compiled for your chips and warmed up. In the
`tt` documentation, a first serve of a 27B model on a QB2 took about 15 minutes, 7 of them
downloading weights. The shipped Qwen3-32B skips the download and the compile.
:::

## Ask It a Question

```bash
tt model curl "Explain what an API is in one sentence." --max-tokens 2048
```

`tt model curl` asks the server which model it is serving, sends your prompt as a chat
completion, and prints the JSON reply. The text is in `choices[0].message.content`. Unknown
options become fields of the request, so `--max-tokens 2048` sets `max_tokens`. Add `--print` to
see the equivalent `curl` command.

Qwen3-32B is a **reasoning model** (the dry run above shows a `qwen3` reasoning parser): it
thinks first, in a separate `reasoning` field, and then answers in `content`. A small token
budget can be used up by the thinking, so give it room when `content` comes back empty.

:::callout type="warn"
**Pick prompts that do not depend on the model knowing about Tenstorrent.** We asked
Llama-3.1-8B "In one sentence, what is Tenstorrent?" and it replied with a confident, invented
company history. Small models do not know recent or niche facts. That is a property of the
model and says nothing about your hardware.
:::

The same endpoint speaks the standard OpenAI API, so any client works. Note the model name:
the server reports the **full Hugging Face id**, which differs from the short name you gave `tt serve`
(for Llama-3.1-8B-Instruct we saw `meta-llama/Llama-3.1-8B-Instruct`).

```bash
curl -s http://localhost:20000/v1/models | python3 -m json.tool | grep '"id"'
```

```bash
curl -s http://localhost:20000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B",
    "messages": [{"role": "user", "content": "Explain what an API is in one sentence."}],
    "max_tokens": 2048
  }' | python3 -m json.tool
```

## Manage What Is Running

```bash
tt model ps                    # what is served, on which port, and whether it is healthy
tt model logs Qwen3-32B        # the newest server log
tt model stop Qwen3-32B        # stop it
```

`tt model ps` shows every server `tt` started, including ones on other ports:

```
┏━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━┳━━━━━━━━━┳━━━━━━━━┓
┃ name                  ┃ backend          ┃ container                    ┃ port  ┃ health  ┃ uptime ┃
┡━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━╇━━━━━━━━━╇━━━━━━━━┩
│ Llama-3.1-8B-Instruct │ inference-server │ tt-inference-server-162a825f │ 20000 │ healthy │ 5m     │
└───────────────────────┴──────────────────┴──────────────────────────────┴───────┴─────────┴────────┘
```

`healthy` means the server answers `GET /v1/models`. `starting` means the container is running
and not answering yet. `tt model stop` stops only the named model's container.

## Serving on Half the Machine

A QB2 is two p300 boards. A model with a `p300` profile uses one board (two chips). For example,
`Llama-3.1-8B-Instruct` has a `p300` profile:

```bash
tt serve Llama-3.1-8B-Instruct --device p300 --dry-run
```

Use `--device` to override what `tt` detected. `tt serve` does not let you choose *which* board:
the container is given every Tenstorrent device node on the machine, so run a half-machine model
only when nothing else is using the chips. How to pin a server to specific chips is in
[Serving Models on QB2](/ml-practitioner/03-vllm-on-qb2/).

## What Just Happened

`tt serve` ran `tt-inference-server`, which started a container holding vLLM and the
Tenstorrent plugin. The container opened a mesh across your chips, loaded the weights into
device memory, compiled and warmed up the kernels, and published the API. The detail of each
stage, and how to run `tt-inference-server` yourself, is in
[Serving Models on QB2](/ml-practitioner/03-vllm-on-qb2/).

---

**Next:** [Launch Software →](/first-timer/06-launch-software/)
