## Running Your First Model

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">⚡</span>
<strong>Already loaded:</strong> your QB2 ships with <strong>Qwen3-32B</strong> pre-cached on disk. The no-download path to your first token is <a href="https://github.com/tenstorrent/tt-studio">tt-studio</a> — run <code>tt-studio</code>, pick <strong>Qwen3-32B</strong> from the Deploy Model dropdown, click Run. The first deploy takes a few minutes (no multi-GB download — the weights are already there). You enter a Hugging Face token once; the model is gated even though the weights are local.
</div>

This chapter takes the *other* path — the hands-on one, where you talk to a chip directly in Python and pull a tiny model down yourself. The starter is [Qwen/Qwen3-0.6B](https://huggingface.co/Qwen/Qwen3-0.6B) — no license gate, 1.5 GB, runs on any Tenstorrent hardware.

First, get into the TTNN environment. On a factory QB2 there is no `~/tt-metal`
checkout on the host — TT-Metalium ships as a container, and the QB2 provides a
wrapper command that starts it:

```bash
tt-metalium
```

That drops you into a shell inside the container with your home directory mounted.
TTNN is already on the default interpreter, so there is no venv to activate. Check it:

```bash
which python3
# → /opt/venv/bin/python3
```

<div class="callout callout--info">
<span class="callout-icon illustrated-only">ℹ</span>
<strong>First run downloads the image.</strong> <code>tt-metalium</code> pulls a multi-GB
container the first time you run it. Later runs start immediately.
</div>

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

<div class="callout callout--warn">
<span class="callout-icon illustrated-only">⚠️</span>
<strong>The chips can only have one owner.</strong> If a model is already deployed
through tt-studio, it holds the devices and their hugepages, and opening a device here
fails with a UMD error like <code>Expected NOC address: 0x1000000000000000, but got
0x1000000040000000</code>. That is contention, not broken hardware — stop the deployed
model (or <code>docker ps</code> and stop the inference container) and try again.
</div>

### Download a model

Downloading weights by hand needs the `hf` CLI, which is **not** part of the QB2's
preinstalled stack — `huggingface_hub` isn't in any environment the installer creates, so
`hf` isn't on your PATH. Install it first, and install it **somewhere other than**
`~/.tenstorrent-venv`: that venv holds `tt-smi` and `tt-flash`, a factory QB2 activates it
for you in every shell, and a bad dependency resolution in there costs you the tooling you
diagnose the machine with. `uv tool` and `pipx` each give the CLI its own environment, which
is exactly what you want:

```bash
uv tool install huggingface_hub     # or: pipx install huggingface_hub
```

Ubuntu 24.04 is an externally-managed Python, so a plain `pip install` on the host will
refuse — that refusal is the system protecting itself, not an error to force past with
`--break-system-packages`.

Then pull the weights (run this on the host, not inside `tt-metalium`):

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
