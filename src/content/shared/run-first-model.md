## Running Your First Model

The fastest model to verify everything works is [Qwen3-0.6B](https://huggingface.co/Qwen/Qwen3-0.6B) — it works on all Tenstorrent hardware, requires no license, and runs in seconds.

Make sure your Python environment is active:

```bash
source ~/tt-metal/python_env/bin/activate
```

Then run:

```bash
python3 -c "
import ttnn
device = ttnn.open_device(device_id=0)
print('Device open:', device)
ttnn.close_device(device)
print('Done.')
"
```

If you see `Device open:` without errors, the hardware is responding and the software stack is intact.

For a full model run, see [tt-studio](https://github.com/tenstorrent/tt-studio) or the vLLM section in your track.

<!-- VIDEO: VHS recording of the TTNN device open/close verification. Script: scripts/vhs/05-first-model-demo.tape -->
