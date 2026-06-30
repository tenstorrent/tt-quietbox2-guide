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

### What ends up on your QB2

| Path | What it is |
|------|-----------|
| `~/tt-metal/python_env/` | TTNN / Direct API venv (pre-installed on QB2) |
| `~/.tenstorrent-venv/` | Main Python environment with vLLM and other tools |
| `~/.local/bin/tt-forge` | Optional Forge container wrapper — *only if you opted in; for most users Forge installs as a pip wheel instead* |
| `~/.local/bin/tt-smi` | Hardware monitoring CLI (on PATH) |
| `~/models/` | Model weights storage (create it: `mkdir -p ~/models`) |

As of `tt-installer` **v3.2.0**, Docker is the default container runtime (Podman is still supported — pass `--install-container-runtime=podman`). The Metalium container installs by default. **Forge is not installed by default** — the TT-Forge docs install it as a pip wheel (`pip install pjrt-plugin-tt …` then `tt-forge-install`); tt-installer's `--install-forge-container` is an optional convenience, not the recommended path. See the [TT-Forge chapter](/ml-practitioner/06-tt-forge/) for the full install. On a QB2 that shipped from Tenstorrent, the TTNN venv at `~/tt-metal/python_env/` is pre-built. The `~/tt-metal/` directory contains compiled environments — not the tt-metal source code.

<figure class="video-demo">
<img src="/assets/video/04-tt-installer-demo.gif" alt="tt-installer post-install state showing venvs, tt-smi, and hf on PATH" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">After tt-installer and reboot — venvs, tt-smi, and hf are ready</figcaption>
</figure>
