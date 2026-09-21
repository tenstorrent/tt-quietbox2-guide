---
title: One CLI to Run It
currentChapter: 06-using-tt-cli
permalink: /first-timer/06-using-tt-cli/
---
{% set persona = personas | findPersona(personaId) %}

# One CLI to Run It

Everything so far — `tt-smi`, `tt-installer`, `tt-metalium`, `tt-inference-server`, `tt-studio` — is a separate tool with its own flags and its own mental model. [`tt-cli`](https://github.com/tenstorrent/tt-cli) (the `tt` command) is Tenstorrent's answer to that sprawl: one entry point that either does the thing itself or delegates to the tool that already does.

<div class="callout callout--warn">
<span class="callout-icon illustrated-only">⚠️</span>
<strong>Don't confuse this with the <code>tt</code> you may already have.</strong> Some Tenstorrent images and lesson environments ship a different <code>tt</code> — a remote "operator" CLI for pairing with and controlling boxes over the network (subcommands like <code>discover</code>, <code>pair</code>, <code>run --host</code>). If <code>tt --help</code> shows those instead of <code>device</code>/<code>model</code>/<code>serve</code>/<code>update</code>, something earlier on your <code>PATH</code> is shadowing the CLI this chapter describes — see <strong>A naming collision to watch for</strong> below.
</div>

## Installing it

`tt-cli` is a Python package (`tenstorrent` on PyPI), and it wants to live in its own isolated environment so it can safely update itself later:

```bash
uv tool install tenstorrent
uv tool update-shell   # makes sure ~/.local/bin is on PATH
tt --help
```

No `uv`? A QB2 that's already run `tt-installer` has it at `~/.local/bin/uv` (the installer's `--use-uv` python path pulls it in as a side effect), so this is usually already true on a real box. On a fresh Ubuntu machine, get it first:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

`pipx install tenstorrent` or a plain venv + `pip install tenstorrent` both work too — see [DEVELOPERS.md](https://github.com/tenstorrent/tt-cli/blob/main/docs/DEVELOPERS.md#other-ways-to-install-tt-cli) for the full list. Whatever you pick, keep `tt-cli` in a venv with nothing else in it — that isolation is what lets `tt self update` upgrade it in place later instead of refusing.

### A naming collision to watch for

Verified on the `tenstorrent/qb2-env` container image used to test this chapter: it also ships a *different* tool at `/usr/bin/tt` — an "Operator CLI for tt-station" (network pairing: `discover`, `pair`, `run --host`, …), unrelated to the CLI this chapter covers. `uv tool install` puts its own shim at `~/.local/bin/tt`, and on a normal interactive shell `~/.local/bin` comes before `/usr/bin` in `PATH`, so the install "just works" — but a non-login shell (a plain `docker run <image> bash -c '...'`, some CI runners) skips `~/.profile` entirely and can leave `/usr/bin/tt` shadowing the one you just installed. Check with `which -a tt` if `tt --help` ever looks unfamiliar; the fix is either a login shell (`bash -l`) or making sure `~/.local/bin` is first on `PATH`.

## Upgrading the stack

`tt update` is the one command that replaces "check tt-smi's changelog, check tt-installer's changelog, remember which `.deb` versions are compatible with which firmware." It converges your system onto a single tested **golden set** — one pinned version per component (firmware, kernel driver, `tt-smi`, `tt-flash`, and more), published and CI-validated by [tt-sw-manifest](https://github.com/tenstorrent/tt-sw-manifest):

```bash
tt update --dry-run   # show the plan, change nothing
tt update             # apply it (prompts before anything that resets a device)
```

`--dry-run` prints a table like this (captured on a real QB2 board):

```
  Update plan (goldens: bundled supplement.toml + golden.json v1.0.0 (cached))
┏━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━┓
┃ component           ┃ kind     ┃ installed ┃ golden               ┃ action   ┃
┡━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━┩
│ tt-flash            │ uv-tool  │ —         │ 3.10.0               │ install  │
│ tt-smi              │ uv-tool  │ —         │ 6.1.0                │ install  │
│ system-stack        │ system   │ —         │ firmware 19.13.1,    │ converge │
│                     │          │           │ kmd 2.10.0, …        │          │
└─────────────────────┴──────────┴───────────┴──────────────────────┴──────────┘
```

`tt-flash`/`tt-smi` are pulled in as their own isolated `uv`-managed tools under `~/.local/share/tenstorrent/` — separate from whatever's already in `~/.tenstorrent-venv`, so the two can't conflict. The `system-stack` row is where `tt update` hands off to `tt-installer` (which needs `sudo`) to converge drivers, firmware, and the rest of the apt-delivered pieces.

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">✅</span>
<strong>Not run nested in a container.</strong> The <code>system-stack</code> row reloads the kernel driver and can install/enable Docker via systemd — real host-level operations. Run <code>tt update</code> on the machine itself, not inside a <code>docker run</code> shell (which typically has no systemd/PID 1 to hand the install off to, and would fail partway through anyway). The <code>tt-cli</code>-managed tool rows (<code>tt-flash</code>, <code>tt-smi</code>) install fine either way.
</div>

### Firmware will not be downgraded by accident

This is the part worth trusting rather than guessing about, so here's what's actually in the source (`tt-cli`'s `commands/update.py` / `backends/installer.py`, current as of `v1.0.1`):

* Plain `tt update` — no `--force`, no version argument — passes `--update-firmware=on` to `tt-installer`. That flag hands the per-device version check to `tt-flash`, which **flashes only devices whose running firmware is older than the golden bundle.** A device already at or ahead of golden is left alone.
* `--force` is what opts into a downgrade — it's the flag whose help text literally says "even when that means a downgrade." Passing an explicit `tt update <version>` (an older installer release) implies `--force` too, "since an explicit version means you know what you're doing."
* Confirmed on a real board during testing: this box's firmware (`19.15.0.0`) was already newer than this golden release's pinned target (`19.13.1`). A plain `tt update --yes` printed the standard "could not confirm current firmware, continue?" prompt (because `tt-smi` wasn't installed *yet* at plan time) but — per the source path above — would not have flashed anything once it got there, since `is_any_fw_semver_higher` only trips the reset warning when the **target** is newer than what's installed.

So: **the happy path already avoids what you're worried about.** Just run `tt update` without `--force` and without naming an older version, and firmware only ever moves forward.

## Validating it worked

```bash
tt device status      # per-board temp, power, clock — a one-line-per-chip tt-smi summary
tt device info         # firmware bundle versions, PCI info, per device
tt model list          # the model catalog, filtered to what this box's hardware can run
tt self update --check # confirms tt itself is current
```

`tt device status` on a two-chip P300 board looks like this:

```
                Tenstorrent devices (driver: TT-KMD 2.11.0)
┏━━━┳━━━━━━━┳━━━━━━━━━━━━━━┳━━━━━━━━━┳━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━┳━━━━━━┓
┃ # ┃ Board ┃ Bus ID       ┃ Temp    ┃ Power  ┃ AIClk     ┃ Voltage ┃ DRAM ┃
┡━━━╇━━━━━━━╇━━━━━━━━━━━━━━╇━━━━━━━━━╇━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━╇━━━━━━┩
│ 0 │ p300c │ 0000:01:00.0 │ 41.2 °C │ 17.0 W │ 800.0 MHz │ 0.72 V  │ True │
│ 1 │ p300c │ 0000:02:00.0 │ 43.6 °C │ 13.0 W │ 800.0 MHz │ 0.73 V  │ True │
└───┴───────┴──────────────┴─────────┴────────┴───────────┴─────────┴──────┘
```

If `tt device status` complains that `tt-smi` isn't installed, that's normal on a box that has never run `tt update` yet through `tt-cli` — it manages its own pinned copy separately from anything already in `~/.tenstorrent-venv`. Run `tt update` once and the error goes away.

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">📎</span>
As of <code>v1.0.1</code>, <code>tt model list</code> takes <code>--community</code> (Hugging Face community bundles) and filters like <code>--type</code>/<code>--hw</code>/<code>--cached</code> — the README's older <code>--catalog</code> flag isn't there; the catalog is just the default when you don't pass <code>--community</code>.
</div>

## Serving a model the short way

Once `tt update` has converged the system stack, the rest of the workflow you saw in [Your First Model](/first-timer/05-your-first-model/) collapses into two commands:

```bash
tt serve Qwen3-32B --port 8000     # in one terminal
tt launch openwebui                 # in another — auto-discovers what's being served
```

`tt model info Qwen3-32B` already reports `cached yes` on a box with the pre-cached weights from [Your First Model](/first-timer/05-your-first-model/) — `tt serve` finds them the same way `tt-inference-server`'s `run.py` does, no re-download. (Qwen3-0.6B, the small model used for the direct TTNN device handshake in that chapter, isn't in the catalog `tt serve` draws from — same restriction as `run.py`, not a `tt-cli` limitation.)

`tt model ps` shows what's running and where; `tt model stop Qwen3-32B` stops it. This is the same `tt-inference-server` underneath — `tt-cli` is just giving it one consistent front door alongside device management and updates.

---

**Next:** [What Comes Next →](/first-timer/07-what-comes-next/)
