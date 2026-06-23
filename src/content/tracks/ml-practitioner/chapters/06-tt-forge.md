---
title: TT-Forge — Compile Anything
currentChapter: 06-tt-forge
permalink: /ml-practitioner/06-tt-forge/
---
{% set persona = personas | findPersona(personaId) %}

# TT-Forge: Compile Anything

vLLM is a curated serving runtime. It knows exactly which models it supports, it has them tuned and tested, and it presents a clean HTTP API for inference. Tremendous for what it does. But it covers a specific list.

TT-Forge is the other gate. You bring the model — any PyTorch `nn.Module`, any JAX function, any ONNX export — and `forge.compile()` traces it, lowers it to Tensix operations, and returns a compiled artifact that runs on your QB2 hardware. One call. Hardware execution. No server, no model list to consult.

If vLLM is the highway, TT-Forge is the ability to go anywhere.

---

## The Three Compilation Paths

Every framework has an entry point into the stack. Run them via the `tt-forge` container wrapper:

```bash
# Run a script through the forge container
tt-forge python3 my_model.py

# Or drop into a forge shell
tt-forge bash
```

| Path | Backend | Entry point | Use for |
|------|---------|-------------|---------|
| TT-Forge (PyTorch) | `forge.compile()` | `import forge` | Any PyTorch `nn.Module` |
| TT-XLA (JAX) | `jax.jit` + PJRT plugin | `import pjrt_plugin_tt` | JAX / Flax models |
| TT-Forge-ONNX | `tt_forge_onnx` | `import tt_forge_onnx` | ONNX exports from any framework |

`tt-forge` is a Docker container wrapper installed to `~/.local/bin/` by tt-installer. It bundles Python 3.12 with all three backends. Keep it separate from TTNN work — the two environments conflict if mixed.

:::callout type="warn"
If you have `TT_METAL_HOME` set (from TTNN work), unset it before activating the forge venv: `unset TT_METAL_HOME`. Leaving it set can cause import errors.
:::

---

## Your First forge.compile()

ResNet is the right first target. Well-understood architecture, small enough to compile fast, and it ships in tt-forge-models with everything wired up.

```python
import torch
import forge
from third_party.tt_forge_models.resnet.pytorch import ModelLoader

# Step 1: Load the model and a batch of representative inputs
model = ModelLoader.load_model(dtype_override=torch.bfloat16)
inputs = ModelLoader.load_inputs()

# Step 2: Compile — forge traces the model graph and lowers to Tensix ops
compiled_model = forge.compile(model, sample_inputs=inputs)

# Step 3: Run inference — same call signature as the original PyTorch model
output = compiled_model(*inputs)

print(output.shape)   # torch.Size([1, 1000]) — standard ImageNet logits
```

What `forge.compile()` does: it traces the model using `sample_inputs` to determine shapes, lowers the traced graph to TTNN operations, compiles those operations to Tensix kernels via Metalium, and returns a callable that dispatches to hardware. The first compilation is slow (tens of seconds for ResNet, longer for large models). Subsequent calls with the same input shapes hit a compiled cache and run fast.

The `dtype_override=torch.bfloat16` argument requests a bfloat16 model. Blackhole is bfloat16-native. Running in bfloat16 gives you full hardware throughput. Running in float32 works, but leaves performance on the table.

Here is the chip view during compilation and inference:

{% tensixviz "blackhole", [
  {"step": "highlight", "cores": [[1,0],[2,0],[3,0],[4,0],[5,0],[6,0],[7,0],[9,0],[10,0],[11,0],[12,0],[13,0],[14,0],[15,0],[1,11],[2,11],[3,11],[4,11],[5,11],[6,11],[7,11],[9,11],[10,11],[11,11],[12,11],[13,11],[14,11],[15,11]], "color": "dram", "label": "Model weights loading into DRAM banks", "ms": 800},
  {"step": "pause", "ms": 400},
  {"step": "transfer", "from": [4,0], "to": [4,3], "ms": 500},
  {"step": "transfer", "from": [7,0], "to": [7,4], "ms": 500},
  {"step": "transfer", "from": [11,0], "to": [11,3], "ms": 500},
  {"step": "pause", "ms": 300},
  {"step": "highlight", "cores": [[1,1],[2,1],[3,1],[4,1],[5,1],[6,1],[7,1],[9,1],[10,1],[11,1],[12,1],[13,1],[14,1],[15,1],[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[7,2],[9,2],[10,2],[11,2],[12,2],[13,2],[14,2],[15,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3],[9,3],[10,3],[11,3],[12,3],[13,3],[14,3],[15,3],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4],[9,4],[10,4],[11,4],[12,4],[13,4],[14,4],[15,4],[1,5],[2,5],[3,5],[4,5],[5,5],[6,5],[7,5],[9,5],[10,5],[11,5],[12,5],[13,5],[14,5],[15,5]], "color": "tensixActive", "label": "Tensix cores running compiled inference kernels", "ms": 1000},
  {"step": "pause", "ms": 800},
  {"step": "clear"}
] %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">forge.compile() dispatches weight loads from DRAM then fans work across the Tensix grid.</p>

:::callout type="tip"
`compiled_model` is a drop-in replacement for the original PyTorch model. Swap it into any existing inference loop — any code that calls `model(*inputs)` works unchanged. You don't need to change anything except the activation step and the compile call.
:::

---

## The tt-forge-models Zoo

Writing `ModelLoader` boilerplate for 200 different models is tedious. Somebody already did it. `tt-forge-models` is the standardized model zoo for TT-Forge: 200+ pretrained models, every one loadable in two lines.

The repo lives at `~/code/tt-forge-models` and on GitHub at [tenstorrent/tt-forge-models](https://github.com/tenstorrent/tt-forge-models).

Directory structure follows a consistent pattern:

```
tt-forge-models/
  resnet/
    pytorch/
      loader.py       # ModelLoader class
  bert/
    pytorch/
      loader.py
    onnx/
      loader.py
  clip/
    pytorch/
      loader.py
  dinov2/
    jax/
      loader.py       # Flax variant
  llama/
    pytorch/
      loader.py
```

Every `loader.py` exports a `ModelLoader` class with two static methods:

```python
from third_party.tt_forge_models.bert.pytorch import ModelLoader

# Load the pretrained model
model = ModelLoader.load_model(dtype_override=torch.bfloat16)

# Load representative inputs (correct shape and dtype for this model)
inputs = ModelLoader.load_inputs()

# compile and run — same as always
compiled = forge.compile(model, sample_inputs=inputs)
output = compiled(*inputs)
```

Five models worth knowing immediately:

| Model | What it does | Good for |
|-------|-------------|----------|
| **ResNet-50** | Image classification, 1000-class ImageNet | Fast compile baseline, benchmarking |
| **BERT-base** | Bidirectional text encoder | Embedding tasks, classification, QA |
| **CLIP** | Paired image-text embedding | Semantic search, zero-shot classification |
| **DINOv2** | Self-supervised vision transformer | Feature extraction, segmentation |
| **DeiT** | Data-efficient image transformer | Vision tasks, strong bfloat16 performance |

Models not on this table: BLOOM, GPT-2, LLaMA, YOLOv4, BEiT, and 190+ more. Browse the full zoo in the [forge-models-zoo lesson](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/forge-models-zoo/).

<div class="rcard-grid">

{% card "repo", "https://github.com/tenstorrent/tt-forge-models", "tt-forge-models", "The standardized model zoo for TT-Forge — 200+ pretrained models, every one loadable in two lines.", "~/code/tt-forge-models" %}

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/forge-models-zoo/", "forge-models-zoo", "Browse the full zoo — the 190+ models beyond the five worth knowing immediately.", "" %}

</div>

:::callout type="tip"
`dtype_override=torch.bfloat16` is the recommended default for all models. Blackhole runs bfloat16 at native hardware throughput. If you need float32 for precision reasons, omit the override — but expect slower inference.
:::

---

## JAX and TT-XLA

For JAX and Flax models, the compilation path uses TT-XLA. Import `pjrt_plugin_tt` and the TT hardware backend registers automatically:

```python
import jax
import jax.numpy as jnp
import pjrt_plugin_tt  # registers TT hardware as the XLA backend

# Any JAX function — jax.jit traces it and compiles to TT hardware
@jax.jit
def predict(params, x):
    return model.apply(params, x)

output = predict(params, batch)
```

The `pjrt_plugin_tt` import is the entire setup. After that, `jax.jit` compiles to Tensix cores instead of CPU or GPU. Flax transformer models slot directly into this pattern — load the model, load weights, wrap `model.apply` in `jax.jit`, run inference.

Full walkthrough: [TT-XLA / JAX lesson](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-xla-jax/).

<div class="rcard-grid">

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-xla-jax/", "TT-XLA / JAX", "The full walkthrough for compiling JAX and Flax models to TT hardware via the PJRT plugin.", "" %}

</div>

---

## Compiletron: The Expedition Game

Someone at Tenstorrent decided the best way to stress-test the compiler stack across hundreds of model architectures was to make it a roguelike game. They were right.

**tt-forge-compiletron** is a model-compilation expedition game (it lives at `tenstorrent/tt-forge-compiletron`). You launch expeditions into the model zoo. Each expedition compiles a different model. The chip runs the compilation. You score points. You build a bestiary.

Start it:

```bash
# From inside the tt-forge-compiletron directory
python3 expedition.py run --tui
```

A three-screen Textual TUI opens. The countdown is four seconds — then the expedition begins automatically.

The **bestiary** (`data/bestiary.json`) is a persistent record of every model you've successfully compiled. Base score per compile: 200 points. First time you compile a model, ever: multiplier of 5, making it 1,000 points. Freshness and rarity bonuses stack on top. The scoring structure incentivizes breadth: you gain more by compiling 10 new models than by recompiling the same model 10 times.

Compiletron supports both compiler backends from a single interface:

| Backend | What runs | Invoke with |
|---------|-----------|-------------|
| `forge` | PyTorch models via `forge.compile()` | Default |
| `xla` | JAX/Flax models via `jax.jit` + PJRT | `--backend xla` |

**Side quests** activate when the mesh is busy with a large model compilation. Idle chips get assigned fast curated models to compile in parallel, keeping hardware utilization high and points accumulating while you wait. The game manages chip allocation automatically.

For unattended recording (VHS demos, overnight compilation runs), use `--auto-quit N`:

```bash
python3 expedition.py run --tui --auto-quit 30
```

The game exits after 30 compiled models, bestiary saved, score written to disk.

{% tensixsystem "qb2", "Four chips compiling at once — main model + side quests" %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">All four chips busy — main expedition on Chip 0, three side quests running simultaneously.</p>

Compiletron was built to find compiler bugs. It works through that bestiary systematically, surfacing edge cases in graph lowering and kernel generation that sequential targeted testing would miss. Every expedition you run contributes data to that effort. Points are real. The bestiary is real. And the compiler gets better.

---

[← Performance Tuning](/ml-practitioner/04-performance-tuning/) | [Going Deeper →](/ml-practitioner/05-going-deeper/)
