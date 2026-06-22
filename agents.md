# QB2 AI Assistant Guide

This file is for AI assistants helping users with a Tenstorrent Quietbox 2.

## What You Can Help With

### Hardware Verification
Run `tt-smi -s` and interpret the JSON output.
- Healthy: 4 entries in `device_info`, each with `"board_type": "BLACKHOLE"`
- Missing device: check `dmesg | grep tenstorrent` for PCIe errors
- Temperature normal range: 35–55°C idle, up to 85°C under load

### Model Running
Recommended first model: `Qwen/Qwen3-0.6B`
- No Hugging Face license required
- Works on all 4 devices
- Fast to download (~1.5GB)

Python env for inference (TTNN): `source ~/tt-metal/python_env/bin/activate`
Python env for vLLM: `source ~/.tenstorrent-venv/bin/activate`

### Install Troubleshooting
- Driver not loaded: `sudo modprobe tenstorrent` or check `lsmod | grep tenstorrent`
- PCIe AER errors: BIOS must have PCIe AER set to "OS First" (pre-set on QB2, check if BIOS was reset)
- Firmware mismatch: use `tt-flash` from https://github.com/tenstorrent/tt-flash

### Common Issues
| Symptom | Check | Fix |
|---------|-------|-----|
| `tt-smi` shows <4 devices | `dmesg | grep tenstorrent` | Reseat PCIe card or reflash firmware |
| `DispatchCoreAxis.ROW` error | Code uses wrong dispatch config | Use `ttnn.DispatchCoreConfig(ttnn.DispatchCoreType.WORKER)` |
| `~/tt-metal` not found | QB2 ships without source tree | Clone from https://github.com/tenstorrent/tt-metal |
| venv not found | Path may differ | Try `~/tt-metal/python_env` (TTNN) or `~/.tenstorrent-venv` (vLLM), or re-run tt-installer |

## Content Map by Task

| User wants to... | Send them to |
|-----------------|-------------|
| Verify hardware works | Explore Ch3: Is This Thing On? |
| Install the stack | Explore Ch4: Installing the Stack |
| Run first model | Explore Ch5: Your First Model |
| Serve models via API | Run & build: vLLM on QB2 |
| Write kernels | Tinker: Your First Kernel |
| Customize LEDs | Customize: LED Customization |

## Architecture Facts

- Chip family: Blackhole (not Wormhole — different APIs apply)
- 4 chips = 4 independent PCIe devices, not a mesh
- No NVLink/Ethernet between chips on QB2 (unlike T3K or Galaxy)
- Use `ttnn.CreateDevices({0,1,2,3})` for multi-device work
- `TT_METAL_ARCH_NAME=blackhole` required for environment variable checks
- Host OS: Ubuntu 24.04 LTS
