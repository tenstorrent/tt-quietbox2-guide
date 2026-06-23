## Running Your First Model

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">⚡</span>
<strong>Already loaded:</strong> your QB2 ships with <strong>Qwen3-32B</strong> pre-cached on disk. The no-download path to your first token is <a href="https://github.com/tenstorrent/tt-studio">tt-studio</a> — run <code>tt-studio</code>, pick <strong>Qwen3-32B</strong> from the Deploy Model dropdown, click Run. The first deploy takes a few minutes (no multi-GB download — the weights are already there). You enter a Hugging Face token once; the model is gated even though the weights are local.
</div>

This chapter takes the *other* path — the hands-on one, where you talk to a chip directly in Python and pull a tiny model down yourself. The starter is [Qwen/Qwen3-0.6B](https://huggingface.co/Qwen/Qwen3-0.6B) — no license gate, 1.5 GB, runs on any Tenstorrent hardware.

First, activate the TTNN environment and verify the hardware is accessible:

```bash
source ~/tt-metal/python_env/bin/activate
```

Your prompt will change to show `(python_env)`. That `which python3` will now point into the venv, not `/usr/bin/python3`. Check it:

```bash
which python3
# → /home/yourname/tt-metal/python_env/bin/python3
```

Now do the handshake — open a device, confirm it responds, close it:

```bash
python3 -c "
import ttnn
device = ttnn.open_device(device_id=0)
print('Device open:', device)
ttnn.close_device(device)
print('Done.')
"
```

If you see `Device open:` without errors, chip 0 is alive and responding. Repeat with `device_id=1`, `2`, `3` to verify all four.

<div class="callout callout--warn">
<span class="callout-icon illustrated-only">⚠️</span>
<strong>QB2 note:</strong> To work with all four chips together, use <code>ttnn.CreateDevices({0, 1, 2, 3})</code> — not four separate <code>open_device()</code> calls. Opening and closing devices individually can cause dispatch core errors on multi-chip configs.
</div>

### Download a model

Use the `hf` CLI (part of the `huggingface_hub` package already installed in the venv):

```bash
# hf — not huggingface-cli. The command is hf.
hf download Qwen/Qwen3-0.6B --local-dir ~/models/Qwen3-0.6B
```

This creates `~/models/Qwen3-0.6B/` with the HuggingFace-format weights (~1.5 GB). Check your disk first:

```bash
df -h ~
```

You need at least 3 GB free for this model alone. Larger models (Llama-3.1-8B) need 16+ GB.

<figure class="video-demo">
<img src="/assets/video/05-first-model-demo.gif" alt="TTNN device open handshake and model files check" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">TTNN device open handshake on chip 0 — then Qwen3-0.6B files on disk</figcaption>
</figure>
