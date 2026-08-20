## Installing the Tenstorrent Software Stack

On a QB2 from Tenstorrent, the stack is already there. This section is for installing on a fresh Ubuntu system, or understanding what the installer put where.

**Prerequisites:** Ubuntu 24.04 LTS (or 22.04), internet connection, `sudo` access.

```bash
sudo apt update && sudo apt install -y curl jq
/bin/bash -c "$(curl -fsSL https://tenstorrent.ai/install.sh)"
```

The installer handles drivers, firmware, kernel modules, and all three Python environments. Accept the defaults — they're right for a QB2.

After it finishes, reboot:

```bash
sudo reboot
```

### The Tenstorrent apt repository (and its signing key)

Most of what the installer puts on the machine — the `tenstorrent-dkms` kernel driver, `tt-smi`, `tt-flash`, `tt-topology`, `tt-toplike`, `tt-metalium`, `tt-nn`, `sfpi` — comes from Tenstorrent's own apt repository. Two things have to be in place for that: the repository line, **and** the key apt uses to verify it. Miss the key and apt refuses the repository outright.

`tt-installer` sets both up. These are the commands it runs, if you'd rather add the repository without the full installer, or need to repair it:

```bash
# 1. Keyring directory
sudo mkdir -p /etc/apt/keyrings
sudo chmod 755 /etc/apt/keyrings
# 2. The signing key — this is the step that gets skipped
sudo curl -fsSL -o /etc/apt/keyrings/tt-pkg-key.asc https://ppa.tenstorrent.com/tt-pkg-key.asc
# 3. The repository, pinned to that key ($VERSION_CODENAME is your release, e.g. noble)
. /etc/os-release
echo "deb [signed-by=/etc/apt/keyrings/tt-pkg-key.asc] https://ppa.tenstorrent.com/ubuntu/ $VERSION_CODENAME main" | sudo tee /etc/apt/sources.list.d/tenstorrent.list
# 4. Refresh
sudo apt-get update
```

On Debian, swap `/ubuntu/` for `/debian/`. On Fedora, write `/etc/yum.repos.d/tenstorrent.repo` with `gpgkey=https://ppa.tenstorrent.com/tt-pkg-key.asc` — dnf fetches the key from the URL, so there's no keyring file to manage.

Check it took:

```bash
head -1 /etc/apt/keyrings/tt-pkg-key.asc   # -----BEGIN PGP PUBLIC KEY BLOCK-----
cat /etc/apt/sources.list.d/tenstorrent.list
apt-cache policy tt-smi                    # should resolve to ppa.tenstorrent.com
```

:::callout type="warn"
If `apt update` says **"The repository ... is not signed"** or reports **`NO_PUBKEY`**, the key at `/etc/apt/keyrings/tt-pkg-key.asc` is missing, empty, or unreadable — re-run step 2 above and `sudo apt-get update`. [Breaking & Fixing Things](/tinkerer/04-break-and-fix/) has the full diagnostic.
:::

### What ends up on your QB2

| Path | What it is |
|------|-----------|
| `~/tt-metal/python_env/` | TTNN / Direct API venv (pre-installed on QB2) |
| `~/.tenstorrent-venv/` | Main Python environment with vLLM and other tools |
| `~/.local/bin/tt-forge` | Optional Forge container wrapper — *only if you opted in; for most users Forge installs as a pip wheel instead* |
| `~/.local/bin/tt-smi` | Hardware monitoring CLI (on PATH) |
| `~/models/` | Model weights storage (create it: `mkdir -p ~/models`) |
| `/etc/apt/keyrings/tt-pkg-key.asc` | Signing key for the Tenstorrent apt repository |
| `/etc/apt/sources.list.d/tenstorrent.list` | The repository line, pinned to that key via `signed-by=` |

As of `tt-installer` **v3.2.0**, Docker is the default container runtime (Podman is still supported — pass `--install-container-runtime=podman`). The Metalium container installs by default. **Forge** installs as a pip wheel into the main venv (`~/.tenstorrent-venv/`) unless you pass `--forge-container`, in which case a container image is pulled and the `tt-forge` wrapper script lands at `~/.local/bin/tt-forge`.

<figure class="video-demo">
<img src="/assets/video/04-tt-installer-demo.gif" alt="tt-installer post-install state showing venvs, tt-smi, and hf on PATH" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--border);" />
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">After tt-installer and reboot — venvs, tt-smi, and hf are ready</figcaption>
</figure>
