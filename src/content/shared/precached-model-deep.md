### What's actually in that directory

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

:::callout type="tip"
**`model_file_symlinks_map/` looks broken, and that's fine.** It holds a symlink to
`/home/container_app_user/cache_root/weights/Qwen3-32B` — a path that exists inside the
serving container, not on your host, so `ls` reports a broken link. It's tt-inference-server's
own bookkeeping. Leave it alone.
:::

:::callout type="deep-dive"
**Reusing the compiled kernels too, and the version trap in the way.**

`--host-weights-dir` gets you the weights but not the 30 GB of compiled kernels. For those you
point `run.py` at the whole persistent volume instead:

```bash
python3 ~/.local/lib/tt-inference-server/run.py \
  --model Qwen3-32B --tt-device p300x2 \
  --workflow server --docker-server \
  --host-volume ~/data/tt-cache
```

There's a catch, and it's the kind that wastes an afternoon. `run.py` doesn't look inside that
directory to see what's there — it *computes* the name it expects, as
`volume_id_<impl>-<model>-v<version>`. That version is not the tt-inference-server release
number; it comes from the **model spec entry matching your model and device**. For `Qwen3-32B`
on `p300x2` that entry is `impl: tt_transformers, version: 0.17.0`, so `run.py` goes looking
for `volume_id_tt_transformers-Qwen3-32B-v0.17.0`.

Your box ships `volume_id_tt_transformers-Qwen3-32B-vqb2_launch` — a build label, not a
version. The names don't match, so `run.py` finds nothing to reuse and quietly starts
downloading into a brand-new volume beside the one it was meant to use.

Don't take that version on faith — it moves between releases, and there are four different
`Qwen3-32B` spec entries. Ask your own box:

```bash
python3 ~/.local/lib/tt-inference-server/run.py \
  --model Qwen3-32B --tt-device p300x2 \
  --workflow server --docker-server \
  --host-volume ~/data/tt-cache \
  --print-docker-cmd --skip-system-sw-validation
```

That prints the `docker run` it *would* issue without starting anything. Read the `src=` path
in the `--mount` line — that's the exact directory name it wants. Then alias the shipped one
to it, substituting whatever name you actually saw:

```bash
cd ~/data/tt-cache
ln -s volume_id_tt_transformers-Qwen3-32B-vqb2_launch \
      volume_id_tt_transformers-Qwen3-32B-v0.17.0
```

The same output carries `TT_CACHE_PATH=.../tt_metal_cache/cache_Qwen3-32B/P300x2`, which is
precisely where the shipped kernels live — confirmation that the cache you're aliasing is the
one the container will read.

`--skip-system-sw-validation` is there only because validation shells out to `tt-smi` and will
stop you before anything prints if the chips are busy. You're just printing a command, so
skipping it is safe; don't carry that flag into a real run.

Because the alias tracks a version that moves, upgrading tt-inference-server will eventually
invalidate it. That maintenance cost is exactly why `--host-weights-dir` is the better default:
it's version-independent, and a one-time kernel compile beats a symlink that silently stops
matching.
:::
