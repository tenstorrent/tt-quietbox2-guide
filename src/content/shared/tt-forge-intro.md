## TT-Forge: Compile Your Model to Silicon

TT-Forge takes a PyTorch, JAX, or ONNX model and produces a compiled artifact that runs natively on Tenstorrent hardware. No server. No inference runtime to configure. One call rewires the model's execution path from CPU to Tensix cores.

Two frontends cover every framework — both lower to the same TT-MLIR compiler:

| Frontend | Entry point | Use for | Chips |
|----------|-------------|---------|-------|
| **TT-XLA** (primary) | `torch.compile(model, backend="tt")` / `jax.jit` | PyTorch & JAX / Flax | single & multi |
| **TT-Forge-ONNX** | `forge.compile(model, inputs)` | ONNX, TensorFlow, PaddlePaddle | single only |

Forge is **not** installed by default. tt-installer sets up the base (driver, firmware, `~/.tenstorrent-venv`); install the frontend itself as a pip wheel from Tenstorrent's package index, the way the [TT-Forge docs](https://docs.tenstorrent.com/tt-forge/) recommend:

```bash
source ~/.tenstorrent-venv/bin/activate
pip install pjrt-plugin-tt --extra-index-url https://pypi.eng.aws.tenstorrent.com/
tt-forge-install
```

Here is the full PyTorch compile-and-run pattern (TT-XLA):

```python
import torch
import torch_xla.core.xla_model as xm
import torch_xla.runtime as xr
import tt_torch  # registers "tt" as a torch.compile backend
from torchvision.models import resnet50, ResNet50_Weights

xr.set_device_type("TT")
device = xm.xla_device()

model = resnet50(weights=ResNet50_Weights.DEFAULT).to(torch.bfloat16).eval()

# One call — model is now compiled for Tenstorrent silicon
compiled_model = torch.compile(model, backend="tt").to(device)

# Inference API is identical to PyTorch
input_tensor = torch.randn(1, 3, 224, 224, dtype=torch.bfloat16).to(device)
output = compiled_model(input_tensor)
```

The compiled model behaves exactly like the original — swap it into your inference loop once the model and inputs are on the TT device, and nothing else changes.

:::callout type="tip"
The [tt-forge-models zoo](https://github.com/tenstorrent/tt-forge-models) ships 800+ model variants with a standardized `ModelLoader` interface — ResNet, BERT, CLIP, DINOv2, BLOOM, LLaMA, and more. `load_model()` returns a plain `nn.Module`, so each one compiles with the same `torch.compile(..., backend="tt")` call. See the [forge-models-zoo lesson](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/forge-models-zoo/) for the full catalog.
:::

Full walkthrough: [TT-Forge Intro lesson](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-forge-intro/)
