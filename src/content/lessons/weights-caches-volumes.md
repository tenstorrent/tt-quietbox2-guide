---
layout: layouts/lesson.njk
title: Weights, Caches and Volumes
subtitle: "Where a QB2 actually keeps model weights and compiled kernels, and how to make tt-inference-server reuse what already shipped instead of downloading it again."
eyebrow: "Cross-track lesson · Run & build"
description: "How tt-inference-server's persistent volume layout works on a Tenstorrent QuietBox 2, and how to reuse the pre-cached Qwen3-32B weights and compiled Blackhole kernels."
permalink: /lessons/weights-caches-volumes/
time: "~15 min"
prereq: "A QB2 with tt-inference-server installed"
backlinks:
  - href: /ml-practitioner/03-vllm-on-qb2/
    label: "Back to Serving Models on QB2"
    colorVar: "--pink"
  - href: /lessons/build-your-own-vllm/
    label: "Build Your Own vLLM Environment"
    colorVar: "--pink"
---

Your QB2 shipped with Qwen3-32B already on disk. [Serving Models on
QB2](/ml-practitioner/03-vllm-on-qb2/) shows the one command that uses it. This lesson is
the layer underneath: what that directory actually is, why the obvious flag is the wrong
one, and how to reuse the compiled kernel cache as well as the weights.

## What's actually in that directory

`~/data/tt-cache` is **tt-inference-server's persistent volume root**. Each model it knows
about gets a `cache_root` beneath it, and the one your box shipped with looks like this:

```text
~/data/tt-cache/                                        <- persistent volume root
└── volume_id_tt_transformers-Qwen3-32B-vqb2_launch/    <- one model's cache_root
    ├── weights/Qwen3-32B/                              <- ~62 GB, a normal HF model dir
    ├── tt_metal_cache/cache_Qwen3-32B/P300x2/P150x4/   <- ~30 GB of compiled kernels
    ├── logs/
    └── model_file_symlinks_map/
```

`weights/Qwen3-32B/` holds exactly what you'd expect — `config.json`, `tokenizer.json`,
`model.safetensors.index.json` and 17 `.safetensors` shards. Only the *location* is unusual,
which is why `--host-weights-dir` works on it directly.

It is **not** a Hugging Face cache, and this is the part that catches people: a factory QB2
has no `~/.cache/huggingface` and no `~/models` at all. Reaching for `--host-hf-cache`
therefore resolves `HOST_HF_HOME`, then `HF_HOME`, then `~/.cache/huggingface`, finds
nothing, and downloads all 62 GB again.

:::callout type="tip"
**`model_file_symlinks_map/` looks broken, and that's fine.** It holds a symlink to
`/home/container_app_user/cache_root/weights/Qwen3-32B` — a path that exists inside the
serving container, not on your host, so `ls` reports a broken link. It's tt-inference-server's
own bookkeeping. Leave it alone.
:::

## Reusing the compiled kernels, and the version trap in the way

`--host-weights-dir` gets you the weights but not the 30 GB of compiled kernels. For those
you point `run.py` at the whole persistent volume with `--host-volume ~/data/tt-cache` — but
don't run that yet, because on a stock box it does the opposite of what you want.

`run.py` doesn't look inside that directory to see what's there. It *computes* the name it
expects, as `volume_id_<impl>-<model>-v<version>`. That version is not the
tt-inference-server release number; it comes from the **model spec entry matching your model
and device**. For `Qwen3-32B` on `p300x2` that entry is `impl: tt_transformers, version:
0.17.0`, so `run.py` goes looking for `volume_id_tt_transformers-Qwen3-32B-v0.17.0`.

Your box ships `volume_id_tt_transformers-Qwen3-32B-vqb2_launch` — a build label, not a
version. The names don't match, so `run.py` finds nothing to reuse and quietly starts
downloading 62 GB into a brand-new volume beside the one it was meant to use. Set up the
alias first, then launch.

### Step 1 — ask your box which name it wants

Don't take the version above on faith; it moves between releases, and there are four
different `Qwen3-32B` spec entries.

```bash
# HF_TOKEN first: run.py validates it up front whenever --docker-server is passed,
# including on this dry run. Without it you get "⛔ HF_TOKEN not set." and no output.
export HF_TOKEN=hf_...

python3 ~/.local/lib/tt-inference-server/run.py \
  --model Qwen3-32B --tt-device p300x2 \
  --workflow server --docker-server \
  --host-volume ~/data/tt-cache \
  --print-docker-cmd --skip-system-sw-validation
```

`--print-docker-cmd` prints the `docker run` it *would* issue and starts nothing, so this is
safe to run before the alias exists. Read the `src=` path in the `--mount` line — that's the
exact directory name it wants. The same output carries
`TT_CACHE_PATH=.../tt_metal_cache/cache_Qwen3-32B/P300x2`, confirming the kernel cache you're
about to alias is the one the container will read.

`--skip-system-sw-validation` is there only because validation shells out to `tt-smi` and will
stop you before anything prints if the chips are busy. You're only printing a command, so
skipping it is safe — don't carry that flag into a real run.

### Step 2 — alias the shipped directory to that name

Substituting whatever name you actually saw:

Copy the directory name out of the `src=` path Step 1 printed — don't retype the `v0.17.0`
above, which is only what *this* spec version happened to want:

```bash
cd ~/data/tt-cache

# Paste the basename of the src= path from Step 1 here.
WANTED=volume_id_tt_transformers-Qwen3-32B-v0.17.0

ln -s volume_id_tt_transformers-Qwen3-32B-vqb2_launch "$WANTED"
ls -l "$WANTED"        # should resolve to the -vqb2_launch directory
```

### Step 3 — serve, reusing both weights and kernels

:::callout type="warn"
**This replaces the `--host-weights-dir` command from the chapter — it is not a next step.**
Both start a server on the same four chips and the same port, and the chips have one owner at
a time. If one is already running, stop it first (`Ctrl-C`, or `docker ps` then `docker stop`)
and confirm with `sudo lsof -w /dev/tenstorrent/*` printing nothing.
:::

```bash
export HF_TOKEN=hf_...

python3 ~/.local/lib/tt-inference-server/run.py \
  --model Qwen3-32B --tt-device p300x2 \
  --workflow server --docker-server \
  --host-volume ~/data/tt-cache
```

Because the alias tracks a version that moves, upgrading tt-inference-server will eventually
invalidate it and you'll be back at step 1. That maintenance cost is exactly why
`--host-weights-dir` is the better default for most people: it's version-independent, and a
one-time kernel compile beats a symlink that silently stops matching.
