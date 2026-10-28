---
title: Install and Upgrade with tt
currentChapter: 04-installing-the-stack
permalink: /first-timer/04-installing-the-stack/
---
{% set persona = personas | findPersona(personaId) %}

# Install and Upgrade with `tt`

`tt` is the Tenstorrent command line. It is the single tool you use to install the software
stack, keep it current, look at your hardware, serve models and connect apps to them. Under
the hood it runs [`tt-installer`](https://github.com/tenstorrent/tt-installer), `tt-smi`,
`tt-flash`, `tt-inference-server` and `tt-studio` for you, each at a version Tenstorrent has
tested together.

A QB2 ships with the software already installed, so this chapter is mostly about **upgrading**.
The same two commands install everything on a fresh Ubuntu machine.

## See What You Have

```bash
tt --version
tt device status
```

If you get `tt: command not found`, `~/.local/bin` is not on your `PATH` in this shell. Run
`uv tool update-shell` (or add `export PATH="$HOME/.local/bin:$PATH"` to `~/.bashrc`) and open a
new terminal.

`tt device status` lists one row per chip. A QB2 has four, on two p300 boards:

```
                 Tenstorrent devices (driver: TT-KMD 2.11.0)
┏━━━┳━━━━━━━┳━━━━━━━━━━━━━━┳━━━━━━━━━┳━━━━━━━━┳━━━━━━━━━━━━┳━━━━━━━━━┳━━━━━━┓
┃ # ┃ Board ┃ Bus ID       ┃ Temp    ┃ Power  ┃ AIClk      ┃ Voltage ┃ DRAM ┃
┡━━━╇━━━━━━━╇━━━━━━━━━━━━━━╇━━━━━━━━━╇━━━━━━━━╇━━━━━━━━━━━━╇━━━━━━━━━╇━━━━━━┩
│ 0 │ p300c │ 0000:01:00.0 │ 55.0 °C │ 74.0 W │ 1337.0 MHz │ 0.81 V  │ True │
│ 1 │ p300c │ 0000:02:00.0 │ 59.9 °C │ 49.0 W │ 1343.0 MHz │ 0.82 V  │ True │
│ 2 │ p300c │ 0000:03:00.0 │ 45.9 °C │ 13.0 W │ 800.0 MHz  │ 0.73 V  │ True │
│ 3 │ p300c │ 0000:04:00.0 │ 47.9 °C │ 18.0 W │ 800.0 MHz  │ 0.73 V  │ True │
└───┴───────┴──────────────┴─────────┴────────┴────────────┴─────────┴──────┘
```

In that capture, chips 0 and 1 were running a model (high power, 1.3 GHz clock) and chips 2 and
3 were idle (800 MHz). The clock column is the quickest way to see which chips are in use.

## Preview an Upgrade

Tenstorrent publishes a **golden set**: the versions of the kernel driver, firmware, HugePages
setup, `tt-smi`, `tt-flash`, `tt-inference-server` and `tt-studio` that have been tested
together. `tt update` moves your machine onto it. Preview first. This changes nothing:

```bash
tt update --dry-run
```

```
  Update plan (goldens: bundled supplement.toml + golden.json v3.0.0 (cached))
┏━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━┓
┃ component       ┃ kind     ┃ installed       ┃ golden           ┃ action     ┃
┡━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━┩
│ tt-flash        │ uv-tool  │ 4.0.0           │ 4.0.0            │ up-to-date │
│ tt-inference-s… │ git-venv │ v0.25.0         │ v0.25.0          │ up-to-date │
│ tt-model        │ uv-tool  │ a7aa9cefdd3086… │ a7aa9cefdd3086b… │ up-to-date │
│ tt-smi          │ uv-tool  │ 6.6.0           │ 6.6.0            │ up-to-date │
│ tt-studio       │ git-venv │ —               │ v2.12.0          │ optional   │
│ system-stack    │ system   │ —               │ hugepages 1.4.1, │ converge   │
│                 │          │                 │ kmd 2.11.0, ...  │            │
└─────────────────┴──────────┴─────────────────┴──────────────────┴────────────┘
```

Read the `action` column:

| Action | Meaning |
|---|---|
| `up-to-date` | Nothing to do. |
| `install` / `update` | `tt update` will install or upgrade it. |
| `optional` | Fetched the first time a command needs it (`tt-studio` here). Add `--include-lazy` to fetch it now. |
| `converge` | The system layer (driver, firmware, HugePages) is checked and brought to the golden versions by `tt-installer`. |

## Upgrade

```bash
tt update
```

`tt update` runs in three phases: it checks the golden manifest, installs or upgrades the
tools into isolated environments under `~/.local/share/tenstorrent/`, and then downloads the
matching `tt-installer` release and runs it. The last phase uses `sudo`, so it asks for your
password. It also asks before flashing firmware, because flashing resets the devices. Stop any
model you are serving first (`tt model ps` shows what is running).

Upgrade the `tt` command itself separately:

```bash
tt self update --check    # is there a newer release?
tt self update
```

On the QB2 used to test this guide, `tt self update --check` reported
`tt 1.2.1 is available (you have 1.2.0)`. `tt update` brings the system and its tools onto the
golden set, and `tt self update` upgrades `tt`. Run both when you want to be current.

:::callout type="warn"
**Reboot after a first install, or if the driver changed.** `tt update` never reboots for you.
If it installed the kernel driver or changed the HugePages configuration, run `sudo reboot`
before you serve anything. On a first install it also adds you to the `docker` group, which
takes effect at your next login.
:::

:::callout type="tip"
`tt update` ignores older copies of tools that a previous `tt-installer` run left in
`~/.local/lib/` (for example `tt-inference-server` and `tt-studio`) and warns you about them. It
manages its own pinned copies under `~/.local/share/tenstorrent/tools/`. The warning prints the
`rm -rf` commands that reclaim the space.
:::

## Installing on a Fresh Machine

You need Ubuntu 22.04 or 24.04, `sudo`, and a network connection. Install `uv`, then `tt`:

```bash
sudo apt update && sudo apt install -y python3 python3-venv python3-pip git curl ca-certificates
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install tenstorrent
uv tool update-shell        # then open a new terminal
tt update
```

The PyPI package is named **`tenstorrent`**. The unrelated `tt-cli` package on PyPI is a
time tracker. `tt update` installs the kernel driver, firmware tooling and HugePages
configuration as root, so reboot afterwards.

## Using `tt-installer` Directly

`tt update` runs [`tt-installer`](https://github.com/tenstorrent/tt-installer) for you, and
for almost everyone that is the right way to use it. `tt update <VERSION>` runs a specific
installer release instead (and implies `--force`, which allows downgrades). The installer's own
options, and the manual path it replaces, are covered in
[Installing by hand](/lessons/tt-installer-by-hand/).

## Check Your Work

```bash
tt --version
tt update --dry-run      # every row should say up-to-date
tt device status         # four rows, all DRAM True
tt model list            # models for your hardware
```

If `tt device status` shows fewer than four rows, go back to
[Is This Thing On?](/first-timer/03-is-this-thing-on/) for the diagnosis steps.

---

**Next:** [Serve a Model →](/first-timer/05-your-first-model/)
