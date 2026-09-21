## Use the Model That's Already on Your Box

Before you download another model, know what you already have. Your QB2 shipped with
**Qwen3-32B** on disk — and not just the weights:

| What | Size | Can you re-download it? |
|---|---|---|
| The weights | ~62 GB | Yes, given time and disk |
| Compiled Blackhole kernels | ~30 GB | **No** |

The second row is the one to care about. Those are the model's operations already compiled
for a four-chip mesh — the work that otherwise happens the first time you serve a model,
while you watch a quiet log and wonder whether it has hung. It cannot be fetched from
Hugging Face because nobody publishes it; it is built against *your* topology. Tenstorrent
pre-built it and shipped it to you.

So the case for using it isn't that downloading is slow. It's that **a download can't give
you the kernel cache** — pull the weights yourself and you still pay the compile, having
thrown away the more valuable half of what shipped. You'd also be spending another ~62 GB on
a disk that already holds this model once. And it is no compromise: Qwen3-32B runs a 131K
context window across all four chips and serves up to 8 concurrent requests.

Confirm it arrived — the same check Tenstorrent's ISO acceptance test runs:

```bash
du -sh ~/data/tt-cache/
```

You want roughly `87G`–`91G`. Much smaller or missing means the model didn't make it onto
your box, and the rest of this section won't work.

### Give it a name you'll remember

The weights are real Hugging Face model files, but they are **not** in a Hugging Face cache —
a factory QB2 has no `~/.cache/huggingface` and no `~/models` at all. They sit in
tt-inference-server's storage layout, under a directory named for a build label. One symlink
puts them on the path the rest of this guide already uses, so you never type that name again:

```bash
mkdir -p ~/models
ln -s ~/data/tt-cache/volume_id_tt_transformers-Qwen3-32B-vqb2_launch/weights/Qwen3-32B \
      ~/models/Qwen3-32B
```

A symlink, not a copy — a copy would be another 62 GB for no benefit. Check it resolves:

```bash
ls ~/models/Qwen3-32B/config.json
```

Now `~/models/Qwen3-32B` sits beside the `~/models/Qwen3-0.6B` you'd get from `hf download`,
and tools take it as an ordinary path:

:::callout type="warn"
**This replaces the launch command near it — it is not a next step.** One model owns the four
chips and port 8000 at a time, so if you already started something (the command above, or a
deploy from tt-studio), stop it before running this: `Ctrl-C`, or `docker ps` then
`docker stop <id>`. `sudo lsof -w /dev/tenstorrent/*` printing nothing means the chips are
free. Pick whichever launch you want; don't run both.
:::

```bash
# run.py requires HF_TOKEN whenever --docker-server is used, local weights or not.
# That is a workflow precondition, not a license gate: Qwen3-32B is Apache-2.0 and
# ungated. Omit it and you get "⛔ HF_TOKEN not set." before anything starts.
export HF_TOKEN=hf_...

python3 ~/.local/lib/tt-inference-server/run.py \
  --model Qwen3-32B \
  --tt-device p300x2 \
  --workflow server --docker-server \
  --host-weights-dir ~/models/Qwen3-32B
```

`--host-weights-dir` mounts that directory into the container read-only: your weights can't
be modified by the server, and no second copy is made. Once it is up, the server reports the
model by its **full Hugging Face repo id** — query it as `Qwen/Qwen3-32B`, not `Qwen3-32B`, or
read the exact string from `curl -s http://localhost:8000/v1/models`. The same path works for a direct
`vllm serve ~/models/Qwen3-32B` with `HF_MODEL=~/models/Qwen3-32B`, if you have built that
environment.

:::callout type="warn"
**Not `--host-hf-cache`.** It's the flag that *sounds* right. It reuses a Hugging Face cache —
resolving `HOST_HF_HOME`, then `HF_HOME`, then `~/.cache/huggingface` — and on a factory QB2
none of those exist, so you get a fresh 62 GB download of a model you already own.
`--host-hf-cache` is for weights *you* pulled with `hf download`; `--host-weights-dir` is for
the ones that shipped. Leave `HF_HOME` alone too — it plays no part in reaching this model.
:::
