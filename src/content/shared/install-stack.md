## Installing the Tenstorrent Software Stack

On a QB2 from Tenstorrent, the stack is already there. This section is for installing on a fresh Ubuntu system, or understanding what the installer put where.

**Prerequisites:** Ubuntu 24.04 LTS (or 22.04), internet connection, `sudo` access.

```bash
sudo apt update && sudo apt install -y curl jq
/bin/bash -c "$(curl -fsSL https://github.com/tenstorrent/tt-installer/releases/latest/download/install.sh)"
```

The installer handles drivers, firmware, kernel modules, and all three Python environments. Accept the defaults — they're right for a QB2.

After it finishes, reboot:

```bash
sudo reboot
```

### What tt-installer creates

| Path | What it is |
|------|-----------|
| `~/tt-metal/python_env/` | TTNN / Direct API venv |
| `~/tt-metal/build/python_env_vllm/` | vLLM inference server venv |
| `/opt/venv-forge` (symlinked as `~/tt-forge-venv/`) | TT-Forge / TT-XLA / JAX venv |
| `/usr/bin/tt-smi` | Hardware monitoring CLI |
| `~/tt-scratchpad/` | Working directory (created by VS Code extension, or make it yourself: `mkdir -p ~/tt-scratchpad`) |

The `~/tt-metal/` directory exists but contains **only the compiled environments** — not the tt-metal source code. That's intentional. You don't need the source to run models or use the APIs.

<!-- VIDEO: VHS recording of tt-installer running, selecting defaults, and completing. Script: scripts/vhs/04-tt-installer-demo.tape -->
