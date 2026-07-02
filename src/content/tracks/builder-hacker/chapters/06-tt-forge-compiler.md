---
title: TT-Forge — The Compiler Pipeline
currentChapter: 06-tt-forge-compiler
permalink: /builder-hacker/06-tt-forge-compiler/
---
{% set persona = personas | findPersona(personaId) %}

# TT-Forge: The Compiler Pipeline

TTNN is a hardware API. TT-Lang is a hardware DSL. Both give you explicit control over tiles, kernels, and data movement. Both speak fluent Tensix. Both require you to think in terms of the chip's actual execution model.

TT-Forge is a different kind of animal. It is a compiler. You give it a PyTorch model or a JAX model. It traces, lowers, compiles, and hands you back something that runs natively on Tensix cores. No tiles. No kernels. No data-movement-reader configuration. The compiler handles the translation. Your model runs.

Neither approach is better. They expose different truths about the hardware. TTNN and TT-Lang are surgical instruments. TT-Forge is a factory floor. Knowing when to pick each one is the actual skill.

## The Compilation Pipeline

Two entry points converge on the same Tensix machine code. Understanding both helps you understand TT-Forge's architecture.

**The PyTorch path:**

```
Your nn.Module → torch.compile(backend="tt") → torch-xla trace → StableHLO → TT-MLIR dialect → Tensix kernels
```

`torch.compile(model, backend="tt")` routes the model through `torch-xla`, which traces it into a StableHLO graph — a stable, framework-neutral IR. The TT-XLA PJRT plugin hands that StableHLO to TT-MLIR, the Tenstorrent MLIR dialect that describes ops in terms the Tensix pipeline understands. The MLIR pipeline compiles that representation all the way to Tensix machine code.

**The JAX path:**

```
Your JAX function → @jax.jit → PJRT plugin → StableHLO → TT-MLIR dialect → Tensix kernels
```

JAX JIT compilation traces the decorated function to StableHLO. The PJRT plugin registered by `import pjrt_plugin_tt` routes that representation through the same TT-MLIR pipeline. Both paths land on the same compiler backend. Both produce the same class of Tensix kernels.

The convergence is intentional — and it's why both frameworks share one frontend, **TT-XLA**, built on the [PJRT](https://github.com/openxla/xla/tree/main/xla/pjrt/c) interface and StableHLO. Model-framework choice doesn't divide the ecosystem: PyTorch users and JAX users compile to the same machine. (ONNX, TensorFlow, and PaddlePaddle take a separate TVM-based frontend, **TT-Forge-ONNX**, which still exposes the `forge.compile()` API and is single-chip only.)

{% tensixviz "blackhole", [
  {"step": "highlight", "cores": [[8,1],[8,2],[8,3],[8,4],[8,5],[8,6],[8,7],[8,8],[8,9],[8,10]], "color": "pcie", "label": "Step 1: PCIe column — model weights transferring from host", "ms": 700},
  {"step": "pause", "ms": 500},
  {"step": "highlight", "cores": [[1,0],[2,0],[3,0],[4,0],[5,0],[6,0],[7,0],[9,0],[10,0],[11,0],[12,0],[13,0],[14,0],[15,0],[1,11],[2,11],[3,11],[4,11],[5,11],[6,11],[7,11],[9,11],[10,11],[11,11],[12,11],[13,11],[14,11],[15,11]], "color": "dram", "label": "Step 2: DRAM rows — compiled weights buffered for dispatch", "ms": 700},
  {"step": "pause", "ms": 500},
  {"step": "highlight", "cores": [[1,1],[2,1],[3,1],[4,1],[5,1],[6,1],[7,1],[9,1],[10,1],[11,1],[12,1],[13,1],[14,1],[15,1],[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[7,2],[9,2],[10,2],[11,2],[12,2],[13,2],[14,2],[15,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3],[9,3],[10,3],[11,3],[12,3],[13,3],[14,3],[15,3],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4],[9,4],[10,4],[11,4],[12,4],[13,4],[14,4],[15,4],[1,5],[2,5],[3,5],[4,5],[5,5],[6,5],[7,5],[9,5],[10,5],[11,5],[12,5],[13,5],[14,5],[15,5]], "color": "tensixActive", "label": "Step 3: Tensix cores — compiled ops dispatching across the mesh", "ms": 900},
  {"step": "pause", "ms": 1200},
  {"step": "clear"}
] %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">The compile pipeline in motion. Weights arrive via PCIe, buffer in DRAM, dispatch to Tensix.</p>

## Prerequisite: Install Forge

Forge is **not** installed by default — a stock tt-installer run gives you the driver and base environment, not Forge. The TT-Forge docs install it as a **pip wheel** from Tenstorrent's package index; for the PyTorch/JAX work in this chapter that's the TT-XLA frontend:

```bash
source ~/.tenstorrent-venv/bin/activate
pip install pjrt-plugin-tt --extra-index-url https://pypi.eng.aws.tenstorrent.com/
tt-forge-install
```

Confirm it imports:

```bash
python3 -c "import torch_xla, tt_torch; print('TT-XLA ready')"
```

Building from source (`tt-forge-fe`, `~/tt-forge-fe/env/activate`) is still an option, but the docs are clear it's for *developing the compiler itself* — not a prerequisite for running models. The [ML-practitioner TT-Forge chapter](/ml-practitioner/06-tt-forge/) covers the wheel, Docker-image, and ONNX install paths in detail.

## Compiling a Model in Practice

Here is a complete BEiT image classification example using the tt-forge-models zoo, compiled through TT-XLA:

```python
import torch
import torch_xla.core.xla_model as xm
import torch_xla.runtime as xr
import tt_torch  # registers "tt" as a torch.compile backend
from third_party.tt_forge_models.beit.pytorch import ModelLoader

# Point PyTorch/XLA at the Tenstorrent device
xr.set_device_type("TT")
device = xm.xla_device()

# Load the BEiT-base-patch16-224 model at bfloat16 precision
model = ModelLoader.load_model(dtype_override=torch.bfloat16).eval()
inputs = ModelLoader.load_inputs(dtype_override=torch.bfloat16)

# Compile to Tensix machine code and move onto the device.
# First call: torch-xla traces to StableHLO, the TT-MLIR pipeline compiles it
# (seconds to minutes depending on model size). Later calls hit the cache.
compiled = torch.compile(model, backend="tt").to(device)
output = compiled(inputs.to(device))

# Same output structure as the original model
print(output.logits.argmax(-1))
```

Walk through what happens at each line. `ModelLoader.load_model()` fetches BEiT-base from HuggingFace and returns a standard PyTorch `nn.Module`. The `dtype_override=torch.bfloat16` argument casts weights to bfloat16, the Blackhole chip's native float format.

`torch.compile(model, backend="tt")` is where the work happens. `torch-xla` traces the model into a StableHLO graph; the TT-MLIR pipeline tunes tile shapes, assigns cores, schedules data movement, and emits Tensix machine code. The compiled callable is API-identical to the original `nn.Module` — call it with inputs, get outputs — except the computation now executes on Blackhole hardware instead of your CPU.

First-call JIT time is real. BEiT compiles in a few seconds; a large vision transformer can take a few minutes. Subsequent calls with the same input shapes skip compilation and hit the cached kernels directly.

:::callout type="tip"
Always load in `torch.bfloat16` for Blackhole deployment. The chip has hardware-accelerated BFP8 and BFP16 math. FP32 works but runs slower.

See the [TT-Forge intro lesson](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-forge-intro/) for compilation flags and caching options.
:::

<div class="rcard-grid">

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-forge-intro/", "TT-Forge intro", "Compile a PyTorch or JAX model to Tensix machine code — compilation flags and caching options.", "" %}

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-xla-jax/", "TT-XLA JAX", "The JAX path: register the TT PJRT plugin and compile @jax.jit functions through the TT-MLIR pipeline.", "" %}

</div>

## The ForgeModel Interface

The `tt-forge-models` zoo at `~/code/tt-forge-models` defines a standardized interface for 800+ model variants. Every loader implements the `ForgeModel` abstract base class from `base.py`:

- `load_model(variant, dtype_override)` — fetches, instantiates, and returns a ready-to-compile `nn.Module`
- `load_inputs()` — returns a tuple of sample tensors that match the model's expected input shape and dtype

The `ModelVariant` enum inside each loader names the specific checkpoints. BEiT's loader has variants for different patch sizes and training configurations. ResNet's loader offers:

```python
ModelLoader.ModelVariant.RESNET_50_HF    # HuggingFace checkpoint
ModelLoader.ModelVariant.RESNET_50_TIMM  # timm checkpoint
```

The `ModelTask` taxonomy in `config.py` organizes models by task type: `NLP_CAUSAL_LM`, `CV_IMAGE_CLS`, `CV_OBJECT_DETECTION`, and others. `ModelGroup` classifies models by family — Vision Transformers, CNNs, generative language models. The taxonomy is machine-readable, which matters for the compiletron game (more below).

This standardization exists so you can swap models without rewriting your compilation harness. The compilation loop is always:

```python
model = ModelLoader.load_model(variant=ModelLoader.ModelVariant.SOME_VARIANT)
inputs = ModelLoader.load_inputs()
compiled = torch.compile(model, backend="tt").to(device)
```

Read the full [forge-models zoo lesson](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/forge-models-zoo/) for traversal patterns and custom variant registration.

<div class="rcard-grid">

{% card "lesson", "https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/forge-models-zoo/", "forge-models zoo", "The standardized ForgeModel interface for 800+ model variants — traversal patterns and custom variant registration.", "" %}

</div>

:::callout type="deep-dive"
The JAX path requires one extra step before the compile call: `import pjrt_plugin_tt` at the top of your script. This import registers the TT PJRT plugin as a JAX backend. After that, `@jax.jit` decorated functions trace and compile through the same TT-MLIR pipeline.

```python
import jax
import jax.numpy as jnp
import pjrt_plugin_tt  # registers TT as JAX backend

@jax.jit
def forward(x):
    return jnp.sin(x) + jnp.cos(x)

x = jnp.ones((128, 128))
result = forward(x)  # compiles to Tensix on first call
```

Full details at the [TT-XLA JAX lesson](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-xla-jax/).
:::

## Forge vs. TTNN — When to Use Which

Three layers of the stack are now in front of you. They are not competing alternatives. They solve different problems at different altitudes.

| Use | When |
|-----|------|
| TT-Forge | You have an existing PyTorch or JAX model and want Tensix execution without rewriting ops |
| TTNN | You need control over tiling strategy, memory placement, or custom tensor ops within a larger model |
| TT-Lang | You are writing a new compute kernel, optimizing an existing one, or need instruction-level control |

The most common pattern in practice: use TT-Forge for whole-model compilation. Drop to TTNN for custom ops that TT-Forge doesn't yet support or where you need tiling control. Drop to TT-Lang for the one inner loop that the profiler says dominates your runtime.

Forge and TTNN are composable. A compiled model can call into TTNN ops, and a TTNN program can lean on `torch.compile(backend="tt")` for the transformer backbone while hand-tuning specialized attention variants in TTNN. The layers were designed to coexist.

## TT-Forge Compiletron

The tt-forge-compiletron at `~/code/tt-forge-compiletron` is a roguelike model compilation game built on top of the forge pipeline. It is also a serious tool for surveying the compile-compatibility landscape of the zoo and of HuggingFace at large.

:::callout type="warn"
Compiletron's `forge` backend drives the source-built `tt-forge-fe` / `forge.compile()` frontend — the legacy PyTorch path now being superseded by TT-XLA's `torch.compile(backend="tt")`. That's why its launch activates `~/tt-forge-fe/env/activate` rather than the wheel environment. The tool remains an excellent compiler stress-test; just note it's pinned to the older frontend.
:::

Set it up, then launch it:

```bash
cd ~/code/tt-forge-compiletron
bash scripts/install.sh --forge   # installs forge venv + tt-forge-fe shim, clones tt-forge-models
python3 expedition.py run --tui --seed-only --backend forge
```

The three-screen Textual TUI shows the model queue, live compilation progress per chip, and a running score. The `--seed-only` flag restricts the model pool to the `tt-forge-models` zoo — hundreds of curated models guaranteed to have standardized loaders. Drop `--seed-only` to enable `--frontier-only` mode, which discovers models live from HuggingFace based on download velocity and rarity signals.

Internally, `expedition.py` delegates to a router that reads `ModelConfig.task` and `ModelConfig.group` metadata from each zoo entry. That metadata informs backend selection (`forge` vs `xla`) and chip assignment. The `--backend mixed` flag alternates backends across the model queue, which is useful for cross-backend compile-rate comparison.

The bestiary at `data/bestiary.json` is a persistent record of every model the compiletron has ever attempted: compile status, timing, output shape, error class if it failed. The router uses the bestiary to deprioritize known-broken models and surface fresh targets. It is also the primary artifact if you are contributing compile-fix patches upstream — the bestiary tells you exactly which models need work and what failed.

Performance timeseries land in `data/perf_history.jsonl` — one JSON object per compile run, appended chronologically. Use it to track compile-time regressions across forge versions or to graph throughput trends after a driver update.

The `--bench-passes N` flag runs N inference passes after a successful compile and records tokens-per-second or images-per-second into the timeseries. Use this to measure real inference throughput, not just compile success.

:::callout type="tip"
Scoring: a successful compile earns a +200 base score. First-ever compile of a model (not yet in the bestiary) earns a ×5 multiplier for a +1,000 point burst. Freshness and rarity bonuses stack on top. Running in `--frontier-only` mode against live HuggingFace models maximizes scoring upside but also maximizes compile-time surprises.
:::

---

**Next steps:** The compiletron's First Voice feature runs a themed inference pass after each successful compile, printing the model's first decoded output on Tenstorrent silicon. It is genuinely entertaining as a throughput warm-up, but the underlying pattern — compile once, inference repeatedly, measure throughput via `perf_history.jsonl` — is the same pattern you use in production model benchmarking.

:::callout type="tip"
**Want an AI pair-programmer that runs on your own silicon?** tt-studio v2.8.0 can serve a deployed model to Claude Code or OpenCode through a local gateway — the coding agent runs against your Blackhole chips instead of a cloud API. The full setup is in [Serving Models on QB2](/ml-practitioner/03-vllm-on-qb2/).
:::

<div class="rcard-grid">

{% card "lesson", "/ml-practitioner/03-vllm-on-qb2/", "Claude Code & OpenCode on your QB2", "Point a coding agent at a model deployed on your own chips — no cloud, no per-token bill. New in tt-studio v2.8.0.", "coding agents" %}

</div>

---

[← Profiling](/builder-hacker/04-profiling/) | [Going Deep →](/builder-hacker/05-going-deep/)
