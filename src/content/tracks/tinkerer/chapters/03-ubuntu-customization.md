---
title: Ubuntu Customization
currentChapter: 03-ubuntu-customization
permalink: /tinkerer/03-ubuntu-customization/
---
{% set persona = personas | findPersona(personaId) %}

# Ubuntu Customization

The QB2 ships with Ubuntu 24.04 LTS and its stock GNOME desktop — the same experience every Ubuntu user gets. It's functional. It's also waiting for your preferences. This chapter is about making the machine yours without breaking what Tenstorrent set up.

The rule throughout: don't touch the tt-metal environments. Customize everything else freely.

## Quick Orientation

Ubuntu 24.04 uses `apt` as its system package manager, with the GNOME desktop on top. Three package systems coexist:

```bash
apt         # system packages — drivers, libraries, system tools
snap        # containerized apps — VS Code, browser
flatpak     # alternative sandbox format (install if needed)
```

Check available storage before installing anything heavy:

```bash
ncdu ~/
```

Install `ncdu` first if it isn't present: `sudo apt install ncdu`. It's a terminal disk usage navigator. Run it before downloading model weights too — Llama-3.1-70B is 140 GB. Surprises are unpleasant.

:::callout type="warn"
Do not run `sudo apt upgrade` without checking tt-metal kernel compatibility first. Tenstorrent drivers are kernel-version-sensitive. An automatic kernel upgrade can make your chips temporarily invisible until you reload the driver. Check the [tt-metal release notes](https://github.com/tenstorrent/tt-metal) for the current supported kernel range before any major upgrade.
:::

## Desktop

Ubuntu's GNOME desktop is what greets you on first boot. Two tools make it yours without fighting it:

**GNOME Tweaks** — fonts, window-button layout, animations, startup apps:
```bash
sudo apt install gnome-tweaks
```

**Extension Manager** — browse and install GNOME Shell extensions (dash-to-dock, system monitors, clipboard history):
```bash
sudo apt install gnome-shell-extension-manager
```

Most desktop settings live in `dconf`; script them with `gsettings`:
```bash
gsettings set org.gnome.desktop.interface color-scheme prefer-dark   # dark mode
gsettings set org.gnome.desktop.interface clock-show-seconds true
```

GNOME on Ubuntu 24.04 runs on **Wayland** by default — `echo $XDG_SESSION_TYPE` confirms it. That matters when you pick a terminal below.

:::callout type="tip"
**Prefer KDE?** GNOME is the default everyone gets, but it's only a default — you can run KDE Plasma instead if that's more your taste (it's where this guide's author does most of their own work):

```bash
sudo apt install kde-plasma-desktop
```

It installs alongside GNOME; pick the session from the gear menu on the login screen. More knobs, heavier footprint, entirely optional.
:::

## Terminal

Ubuntu's GNOME desktop ships **GNOME Terminal** by default. It's perfectly good. If you want more, a few favorites:

**Kitty** — GPU-accelerated, fast, tabs + splits built in:
```bash
sudo apt install kitty
```

**Foot** — minimal native Wayland terminal, fastest startup:
```bash
sudo apt install foot
```

**Alacritty** — cross-platform, GPU-rendered, config-file-driven:
```bash
sudo apt install alacritty
```

Any of these pairs well with the rest of this setup.

## Shell

The system shell is bash. Two popular upgrades:

**zsh + starship prompt** — zsh is feature-rich; starship is a fast, cross-shell prompt that shows git status, Python venv, and more:

```bash
sudo apt install zsh
chsh -s $(which zsh)   # set zsh as your login shell

# Install starship (Rust binary, no system package needed)
curl -sS https://starship.rs/install.sh | sh

# Add to your ~/.zshrc:
echo 'eval "$(starship init zsh)"' >> ~/.zshrc
```

**fish** — if you want a shell that just works out of the box with autosuggestions and syntax highlighting:

```bash
sudo apt install fish
chsh -s $(which fish)
```

:::callout type="tip"
Log out and back in after `chsh` for the new shell to take effect in all sessions.
:::

## Useful CLI Tools

These are collectively small downloads, collectively large quality-of-life gains:

```bash
sudo apt install \
  htop \       # interactive process monitor
  ncdu \       # disk usage navigator
  bat \        # cat with syntax highlighting
  ripgrep \    # blazing grep replacement (rg)
  fd-find \    # fast find replacement (fd)
  fzf \        # fuzzy finder — attach to shell history, file browsing
  jq \         # JSON processor — useful for tt-smi -s output
  tmux         # terminal multiplexer — see below
```

`fzf` in particular integrates with shell history (`Ctrl-R`) and file search (`Ctrl-T`) to make terminal navigation dramatically faster. Add these lines to your `.bashrc` or `.zshrc` after installing:

```bash
eval "$(fzf --bash)"    # bash
# or
eval "$(fzf --zsh)"     # zsh
```

## tmux for Multi-Session Work

When you're downloading a 140 GB model in one session, monitoring chips in another, and editing code in a third, tmux prevents terminal chaos. It also keeps processes running if your SSH connection or terminal emulator drops.

```bash
# Install
sudo apt install tmux

# Start a new named session
tmux new -s qb2

# Attach to an existing session
tmux attach -t qb2

# Key bindings (default prefix is Ctrl-b):
#   Ctrl-b c     new window
#   Ctrl-b %     vertical split
#   Ctrl-b "     horizontal split
#   Ctrl-b d     detach (session keeps running)
#   Ctrl-b [     scroll mode (q to exit)
```

A minimal `~/.tmux.conf` to add mouse support and increase scrollback:

```bash
cat >> ~/.tmux.conf << 'EOF'
set -g mouse on
set -g history-limit 50000
set -g default-terminal "tmux-256color"
EOF
```

## Python Environment Management

Ubuntu 24.04's system Python is externally-managed. `pip install` at the system level will refuse or break things. This is correct behavior. Don't fight it.

For managing Python versions and creating isolated envs outside the tt-metal stack, use `uv` — it's fast, correct, and doesn't require a conda installation:

```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create a project-local Python 3.11 env
uv venv --python 3.11 .venv
source .venv/bin/activate

# Install packages into it
uv pip install numpy requests
```

Alternatively, `pyenv` for managing multiple Python versions:

```bash
curl https://pyenv.run | bash
# Add to shell init (follow the printed instructions)
pyenv install 3.11.9
pyenv virtualenv 3.11.9 myproject
pyenv activate myproject
```

Keep these entirely separate from `~/tt-metal/python_env/` and `~/.tenstorrent-venv/`. Those are managed environments. Don't pip-install into them manually.

## VS Code

```bash
sudo snap install code --classic
```

Or download the `.deb` from [code.visualstudio.com](https://code.visualstudio.com/) for a non-snap install if you prefer:

```bash
sudo dpkg -i code_*.deb
```

Once VS Code is installed, get the Tenstorrent extension from the marketplace. Search for "tt-vscode-toolkit" in the Extensions panel, or install from the command line:

```bash
code --install-extension tenstorrent.tt-vscode-toolkit
```

The extension adds tt-metal project support, TTNN kernel highlighting, chip status indicators in the status bar, and guided lessons — including the QB2 video generation walkthrough.

## Useful Aliases

Add these to `~/.bashrc` or `~/.zshrc` to cut down repetitive typing:

```bash
# Tenstorrent environment shortcuts
alias ttenv='source ~/tt-metal/python_env/bin/activate'
alias ttvllm='source ~/.tenstorrent-venv/bin/activate'

# Readable tt-smi JSON output
alias ttsmi='tt-smi -s | python3 -m json.tool'

# Watch chip state every 2 seconds
alias ttwatch='watch -n2 "tt-smi -s | python3 -m json.tool"'

# Quick disk check
alias diskcheck='ncdu ~/ --exclude ~/models'
```

Source the file to pick up changes immediately:

```bash
source ~/.bashrc
```

---

**Next:** [Breaking & Fixing Things →](/tinkerer/04-break-and-fix/)
