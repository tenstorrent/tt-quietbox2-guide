## Installing the Tenstorrent Software Stack

> On a Quietbox 2, the stack is pre-installed. This section is for installing on other systems, or reinstalling after a factory reset.

The fastest path is the [tt-installer](https://github.com/tenstorrent/tt-installer) script. It handles drivers, firmware, containers, and Python environments in one pass.

**Prerequisites:** Ubuntu 22.04, internet connection, administrator access.

```bash
sudo apt update && sudo apt install -y curl jq
/bin/bash -c "$(curl -fsSL https://github.com/tenstorrent/tt-installer/releases/latest/download/install.sh)"
```

The installer will prompt you to select which components to install. For a QB2, select all defaults.

After installation, reboot:

```bash
sudo reboot
```

<!-- VIDEO: VHS recording of tt-installer running, selecting defaults, and completing. Script: scripts/vhs/04-tt-installer-demo.tape -->
