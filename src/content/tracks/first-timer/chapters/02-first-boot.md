---
title: First Boot
currentChapter: 02-first-boot
permalink: /first-timer/02-first-boot/
---
{% set persona = personas | findPersona(personaId) %}

# First Boot

Power on. Ubuntu loads. You log in. Now what?

Everything from here happens in a terminal. That's the command line — a text window where you type instructions and the machine responds. On a QB2, the terminal is your instrument panel. Learning its three or four most-used commands will get you surprisingly far.

## Finding a Terminal

If you're looking at the GNOME desktop:

- Press `Ctrl+Alt+T` — opens a terminal on most Ubuntu setups
- Or press the Super key (Windows key), type `terminal`, press Enter
- Or right-click the desktop and choose "Open Terminal"

Once a terminal window is open, you're in the right place. It shows a prompt ending in `$` — everything you type goes after that.

## The Three Commands You Need Right Now

**Check disk space first.** Models are large. This is non-negotiable to understand before you do anything else:

```bash
df -h ~
```

This shows your home directory's disk usage. The `Size` column is total, `Avail` is what's free. You need room — at minimum 3 GB for a small model (Qwen3-0.6B), 20+ GB for anything like Llama-3.1-8B. If you're under 5 GB free, stop here and figure out where the space went before continuing.

**Check internet connectivity:**

```bash
ping -c 3 google.com
```

If this fails, check your network cable or go to Settings → Network. Everything else in this guide requires internet access for model downloads.

**Update the package list** (do this once after first boot):

```bash
sudo apt update
```

`sudo` means "run as administrator." Ubuntu will ask for your password. This doesn't install or change anything — it just refreshes the list of what's available. You'll see a lot of text scroll by. That's normal.

<figure class="video-demo">
<img src="/assets/video/02-first-boot-demo.gif" alt="QB2 first boot terminal: uname, ping, df, home directory, tt-smi version" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">Live QB2 — Ubuntu 24.04, internet up, disk space, tt-smi on PATH</figcaption>
</figure>

## Ubuntu: What You Should Know

The QB2 runs Ubuntu 24.04 LTS. If this is your first time with it:

- Package manager is `apt` — install things with `sudo apt install <name>`
- Files are case-sensitive: `Model.py` and `model.py` are different files
- Your home directory is `~` — short for `/home/yourusername`
- `sudo` runs a command as administrator — use it only when a command tells you to

## Python: A Field Guide to the Confusion

This is where new Linux users often hit a wall. Ubuntu ships with its own Python. The Tenstorrent software has its own Python environments. These are separate and don't mix. Here's the landscape:

### What exists on your system

| Name | Location | What it is |
|------|----------|-----------|
| System Python | `/usr/bin/python3` | Ubuntu's built-in Python — **don't pip install here** |
| TTNN venv | `~/tt-metal/python_env/` | Pre-built environment for TTNN and the Direct API |
| vLLM venv | `~/tt-metal/build/python_env_vllm/` | Pre-built environment for serving models |
| TT-Forge venv | `~/tt-forge-venv/` → `/opt/venv-forge` | For TT-Forge and JAX (symlink) |

### Why does this matter?

Ubuntu 24.04 enforces what's called **externally-managed Python** — the system Python is protected. If you try to `pip install` something directly, Ubuntu will refuse with an error about breaking system packages. This is intentional. It protects you.

The right move is always: activate the correct venv, then install inside it. The Tenstorrent venvs already have everything you need for this guide, so you won't need to install much.

### What `which python3` tells you

Before running any Python code, check which Python is active:

```bash
which python3
```

If you see `/usr/bin/python3` — you're using the system Python. Tenstorrent imports will fail.

If you see something like `/home/yourname/tt-metal/python_env/bin/python3` — you're inside the right venv. Go ahead.

### pip, pyenv, uv — a brief map

You may encounter other Python tools in documentation or online:

- **`pip`** — Python package installer. Works inside a venv. Fine to use there.
- **`pyenv`** — manages multiple Python versions (3.10, 3.11, etc.). The QB2 doesn't need it — the venvs handle version isolation.
- **`virtualenv` / `python -m venv`** — creates isolated environments. The Tenstorrent venvs were built this way.
- **`uv`** — a fast, modern alternative to pip and virtualenv. Works, but the QB2 docs and this guide use standard venv activation.

For this guide: ignore pyenv, ignore uv. Activate the venv Tenstorrent provides. That's all you need.

<img src="/assets/illustrations/python-env-map.svg" alt="Map of Python environments on the QB2: system Python, TTNN venv, vLLM venv, Forge venv" class="spot-illustration" style="max-width:100%;"/>

### Activating and deactivating

```bash
# Activate the TTNN environment
source ~/tt-metal/python_env/bin/activate

# Your prompt now shows (python_env) — you're inside
# Deactivate when done
deactivate
```

The `(python_env)` prefix in your prompt is the signal. When it's there, Python calls and imports go to the right place. When it's not, they don't.

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">💡</span>
The QB2 may have pre-activation scripts in <code>/etc/profile.d/</code> that activate an environment automatically at login. Run <code>which python3</code> before sourcing any venv to see what's already active — activating on top of an active venv is messy.
</div>

---

**Next:** [Is This Thing On? →](/first-timer/03-is-this-thing-on/)
