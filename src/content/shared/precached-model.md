## Use the Model That's Already on Your Box

Before you download anything, know what you already have. Your QB2 shipped with
**Qwen3-32B** on disk — and not just the weights. Two separate things are sitting in
`~/data/tt-cache`:

| What | Size | Can you re-download it? |
|---|---|---|
| The weights | ~62 GB | Yes, given time and disk |
| Compiled Blackhole kernels | ~30 GB | **No** |

The second row is the one worth caring about. Those are the model's operations already
compiled for a four-chip mesh — the work that otherwise happens the first time you serve a
model, while you watch a quiet log and wonder whether it has hung. It cannot be fetched from
Hugging Face because it is not a file anyone publishes; it is built against *your* topology.
Tenstorrent pre-built it and shipped it to you, which is why the factory acceptance test
expects a first deploy in under six minutes rather than the 3–5 minute compile the rest of
this guide warns you about.

So the argument for using it is not really "downloading is slow." It is:

- **You'd be paying twice.** A second copy of Qwen3-32B is another ~62 GB on a disk that has
  already spent that much on the first one.
- **A download cannot give you the kernel cache.** Pull the weights yourself and you still
  pay the compile — you have thrown away the more valuable half of what shipped.
- **It isn't a compromise model.** Qwen3-32B runs a 131K context window across all four
  chips and serves up to 8 concurrent requests. On a QB2 it is the strongest thing that
  comfortably fits, not a toy chosen because it was convenient.

Confirm it arrived before you build on it — this is the same check Tenstorrent's own ISO
acceptance test runs:

```bash
du -sh ~/data/tt-cache/
```

You want roughly `87G`–`91G`. If that directory is missing or much smaller, the model didn't
make it onto your box, and the rest of this section won't work.

### Why it isn't where you'd look for it

Nothing is wrong with your box, but nothing is where habit says it should be either. A
factory QB2 has **no `~/.cache/huggingface` and no `~/models` at all** — neither directory
exists until you create it. The weights are instead laid out the way
[tt-inference-server](https://github.com/tenstorrent/tt-inference-server) wants them, as a
*persistent volume*:

```text
~/data/tt-cache/                                        <- persistent volume root
└── volume_id_tt_transformers-Qwen3-32B-vqb2_launch/    <- one model's cache_root
    ├── weights/Qwen3-32B/                              <- the weights
    ├── tt_metal_cache/cache_Qwen3-32B/P300x2/P150x4/   <- the compiled kernels
    ├── logs/
    └── model_file_symlinks_map/
```

That `weights/Qwen3-32B/` directory is an ordinary Hugging Face model directory —
`config.json`, `tokenizer.json`, `model.safetensors.index.json` and 17 `.safetensors` shards.
Nothing exotic. It is only the *location* that is unusual.

:::callout type="tip"
**`model_file_symlinks_map/` looks broken, and that's fine.** It holds a symlink to
`/home/container_app_user/cache_root/weights/Qwen3-32B` — a path that exists inside the
serving container, not on your host, so `ls` reports it as a broken link. It's
tt-inference-server's own bookkeeping. Leave it alone.
:::

### Give it a name you'll remember

One symlink puts those weights on the path the rest of this guide already uses for models,
so you never have to type `volume_id_tt_transformers-Qwen3-32B-vqb2_launch` again:

```bash
mkdir -p ~/models
ln -s ~/data/tt-cache/volume_id_tt_transformers-Qwen3-32B-vqb2_launch/weights/Qwen3-32B \
      ~/models/Qwen3-32B
```

A symlink and not a copy, deliberately: a copy would be another 62 GB for no benefit, and
would drift from the original the moment either changed. Check it resolves:

```bash
ls ~/models/Qwen3-32B/config.json
```

Now `~/models/Qwen3-32B` sits next to the `~/models/Qwen3-0.6B` you'd get from
`hf download`, and every tool in this guide takes it as a path:

```bash
# tt-inference-server — the managed path
python3 ~/.local/lib/tt-inference-server/run.py \
  --model Qwen3-32B \
  --tt-device p300x2 \
  --workflow server --docker-server \
  --host-weights-dir ~/models/Qwen3-32B

# Direct vLLM, if you have built that environment
export HF_MODEL=~/models/Qwen3-32B
vllm serve ~/models/Qwen3-32B --served-model-name Qwen3-32B --port 8000
```

`--host-weights-dir` mounts that directory into the container read-only. Your weights cannot
be modified by the server, and no second copy is made.

:::callout type="warn"
**Don't reach for `--host-hf-cache` here.** It is the flag that *sounds* right, and it is the
wrong one. It reuses a Hugging Face cache — resolving `HOST_HF_HOME`, then `HF_HOME`, then
`~/.cache/huggingface` — and on a factory QB2 none of those exist. Point it at nothing and
you get a fresh 62 GB download of a model you already own. `--host-hf-cache` is for weights
*you* pulled with `hf download`; `--host-weights-dir` is for the ones that shipped.

For the same reason, leave `HF_HOME` alone. It plays no part in reaching this model, and
exporting it at something clever will not help.
:::

:::callout type="deep-dive"
**Reusing the compiled kernels too, and the version trap in the way.**

`--host-weights-dir` gets you the weights. To also reuse the 30 GB of compiled kernels you
point `run.py` at the whole persistent volume instead:

```bash
python3 ~/.local/lib/tt-inference-server/run.py \
  --model Qwen3-32B --tt-device p300x2 \
  --workflow server --docker-server \
  --host-volume ~/data/tt-cache
```

There is a catch, and it is the kind that wastes an afternoon. `run.py` doesn't look inside
that directory to see what's there — it *computes* the name it expects, as
`volume_id_<impl>-<model>-v<version>`. That version is not the tt-inference-server release
number; it comes from the **model spec entry matching your model and device**. For
`Qwen3-32B` on `p300x2` that entry is `impl: tt_transformers, version: 0.17.0`, so `run.py`
goes looking for `volume_id_tt_transformers-Qwen3-32B-v0.17.0`.

Your box ships the directory named `volume_id_tt_transformers-Qwen3-32B-vqb2_launch` — a
build label, not a version. The names don't match, `run.py` finds nothing to reuse, and
quietly begins downloading into a brand-new volume beside the one it was meant to use.

Don't take the version above on faith — it changes between releases, and there are four
different `Qwen3-32B` spec entries. Ask your own box what it expects:

```bash
python3 ~/.local/lib/tt-inference-server/run.py \
  --model Qwen3-32B --tt-device p300x2 \
  --workflow server --docker-server \
  --host-volume ~/data/tt-cache \
  --print-docker-cmd --skip-system-sw-validation
```

That prints the `docker run` it *would* issue without starting anything. Read the `src=` path
in the `--mount` line — that is the exact directory name it wants. Then alias the shipped one
to it:

```bash
cd ~/data/tt-cache
ln -s volume_id_tt_transformers-Qwen3-32B-vqb2_launch \
      volume_id_tt_transformers-Qwen3-32B-v0.17.0
```

Substitute whatever name `--print-docker-cmd` actually showed you. The same output also
carries `TT_CACHE_PATH=.../tt_metal_cache/cache_Qwen3-32B/P300x2`, which is precisely where
the shipped kernels live — a useful confirmation that the cache you're aliasing is the one
the container will read.

`--skip-system-sw-validation` is there because the validation step shells out to `tt-smi`
and will stop you before anything is printed if the chips are busy. You are only printing a
command, so skipping it is safe; don't carry that flag over to a real run.

Because the alias is tied to a version that moves, upgrading tt-inference-server will
eventually invalidate it and you'll need a new one. That maintenance cost is exactly why
`--host-weights-dir` above is the better default: it is version-independent, and paying a
one-time kernel compile beats a symlink that silently stops matching.
:::
