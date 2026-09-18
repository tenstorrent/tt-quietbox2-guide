---
layout: layouts/lesson.njk
title: Build Your Own vLLM Environment
subtitle: "Run `vllm serve` yourself on a QB2 — why you would, what you have to build first, and the dependency traps between you and a working `import ttnn`."
eyebrow: "Cross-track lesson · Run & build"
description: "Build a working vLLM + ttnn environment on a Tenstorrent QuietBox 2 and serve models with vllm serve directly, instead of the managed tt-inference-server path."
permalink: /lessons/build-your-own-vllm/
time: "~40 min, most of it dependency resolution"
prereq: "A QB2 with the stack installed, and a reason not to use tt-inference-server"
backlinks:
  - href: /ml-practitioner/03-vllm-on-qb2/
    label: "Back to Serving Models on QB2"
    colorVar: "--pink"
  - href: /lessons/weights-caches-volumes/
    label: "Weights, Caches and Volumes"
    colorVar: "--pink"
---

Most people should serve models on a QB2 with `tt-inference-server`, which is what
[Serving Models on QB2](/ml-practitioner/03-vllm-on-qb2/) covers. It wraps vLLM in a
container, picks the mesh for you, and needs no environment building.

This lesson is the other route: running `vllm serve` yourself. You get flags the managed
path doesn't expose and a newer vLLM than the pinned image ships — and in exchange you own
the dependency tree. **vLLM is not installed on a QB2.** It isn't in `~/.tenstorrent-venv`
(which holds `tt-smi` and `tt-flash` and nothing else) and it isn't on the host at all; the
copy the managed path uses lives inside a container image. So this is a thing you set up
deliberately, not a thing you find.

That is also why the order here is inverted from the chapter's: **build the environment
first**, then serve. Read [Building the environment](#building-the-environment) before you
run anything in the next section.

## Serving directly with `vllm serve`

This assumes you have already built an environment with a working `vllm` **and** a working Python
`ttnn` — see [Building the environment](#building-the-environment) below, which is the
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
[Building the environment](#building-the-environment) below.
:::

On first run: the model weights get compiled into Blackhole-optimized op graphs. This takes 3–5 minutes. Subsequent starts are fast — the compiled artifacts are cached.

Watch the logs. When you see a line containing `Application startup complete`, the server is accepting requests.

:::callout type="tip"
The `TT_METAL_ARCH_NAME=blackhole` environment variable is required for Blackhole hardware — vLLM's Tenstorrent backend needs it to select the correct device. If you see errors about unknown architecture or device initialization failures, this is the first thing to check.
:::

:::callout type="warn"
**`ImportError` before hardware is even touched** (e.g. `cannot import name '...' from 'transformers...'`) means the venv's `transformers` version has drifted out of sync with the pinned Tenstorrent vLLM fork — not a device or driver problem. This venv accumulates whatever else gets `pip install`ed into it over time, and vLLM forks pin transformers tightly. Check `pip show transformers vllm` for a sane pairing, and if it's drifted, re-run the vLLM+plugin installer to re-sync the two rather than upgrading `transformers` alone.
:::

## Building the environment

Everything in the chapter works with the vLLM your QB2 shipped with. This is for running
ahead of it.

Tenstorrent's vLLM support has been extracted into a standalone **platform plugin**,
[tenstorrent/vllm-tt-plugin](https://github.com/tenstorrent/vllm-tt-plugin). It runs against
*upstream* vLLM rather than a Tenstorrent fork: the plugin contributes a `tt` platform through
vLLM's normal out-of-tree plugin mechanism, and vLLM selects it automatically whenever `ttnn`
is importable.

:::callout type="warn"
**This is not what tt-inference-server uses.** As of v0.19.0 its images still clone the
Tenstorrent vLLM fork and install the copy of the plugin that lives inside it, pinned per model.
So the managed path in the chapter and this lesson are genuinely different stacks. Do this on a box you are
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

---

<figure class="video-demo">
<img src="/assets/video/09-vllm-demo.gif" alt="Activating the TTNN venv, checking hardware with tt-smi, vLLM serve command on a QB2" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">Venv setup and hardware check before serving — four p300c chips ready</figcaption>
</figure>
