## TT-Forge: Compile Your Model to Silicon

`forge.compile()` takes a PyTorch model and produces a compiled artifact that runs natively on Tenstorrent hardware. No server. No inference runtime to configure. One call rewires the model's execution path from CPU to Tensix cores.

Three paths into the compiler stack:

| Path | Entry point | Use for |
|------|-------------|---------|
| **TT-Forge** | `forge.compile(model, sample_inputs)` | PyTorch `nn.Module` models |
| **TT-XLA** | `jax.jit` + `pjrt_plugin_tt` | JAX / Flax models |
| **TT-Forge-ONNX** | `tt_forge_onnx` | ONNX exports from any framework |

All three live in the same venv. Activate it once:

```bash
source ~/tt-forge-venv/bin/activate
```

Here is the full forge compile-and-run pattern:

```python
import torch
import forge
from third_party.tt_forge_models.resnet.pytorch import ModelLoader

# Load model and representative inputs
model = ModelLoader.load_model(dtype_override=torch.bfloat16)
inputs = ModelLoader.load_inputs()

# One call — model is now compiled for Tenstorrent silicon
compiled_model = forge.compile(model, sample_inputs=inputs)

# Inference API is identical to PyTorch
output = compiled_model(*inputs)
```

The compiled model behaves exactly like the original. Switch to `compiled_model` in your inference loop and nothing else changes.

:::callout type="tip"
The [tt-forge-models zoo](https://github.com/tenstorrent/tt-forge-models) ships 200+ pretrained models with a standardized `ModelLoader` interface — ResNet, BERT, CLIP, DINOv2, BLOOM, LLaMA, and more. Every model loads in two lines and arrives ready for `forge.compile()`. See the [forge-models-zoo lesson](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/forge-models-zoo/) for the full catalog.
:::

Full walkthrough: [TT-Forge Intro lesson](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-forge-intro/)
