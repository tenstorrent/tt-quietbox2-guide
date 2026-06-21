## Running Your First Model

The fastest path to a working inference call is [Qwen/Qwen3-0.6B](https://huggingface.co/Qwen/Qwen3-0.6B) — no license gate, 1.5 GB, runs on any Tenstorrent hardware.

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

<!-- VIDEO: VHS recording of the TTNN device open/close verification and hf download. Script: scripts/vhs/05-first-model-demo.tape -->
