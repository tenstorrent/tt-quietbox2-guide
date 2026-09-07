---
title: Breaking & Fixing Things
currentChapter: 04-break-and-fix
permalink: /tinkerer/04-break-and-fix/
---
{% set persona = personas | findPersona(personaId) %}

# Breaking & Fixing Things

The QB2 is a workstation, not a cloud VM with a reset button in a web console. Software changes are reversible. Hardware is physically robust. The worst case scenario for almost everything in this chapter is a few minutes of diagnostic work and a single command.

This philosophy matters. It means you should experiment freely. Break things. Learn the recovery pattern. The machine can take it.

:::callout type="tip"
`tt-smi` is the first diagnostic for anything chip-related. Before filing a bug or posting to Discord, run `tt-smi -s` and include the JSON output. It answers half the questions before they're asked.
:::

## The Recovery Ladder

Before reaching for dramatic solutions, follow this order:

1. Run the failing command again (transient errors happen)
2. Check the relevant log: `journalctl`, `docker logs`, or the service's own log file
3. Restart the failing service: `systemctl restart <name>` or `docker restart <container>`
4. Reset the boards: `tt-smi -r` — clears a stuck Ethernet fabric or ARC state without a full
   reboot. Cheaper than reloading the driver, and it's the fix for the suspend/resume pattern
   below, so reach for it before step 5.
5. Reload the driver: `sudo modprobe -r tenstorrent && sudo modprobe tenstorrent`
6. Reboot: `sudo reboot`
7. Post to the [Tenstorrent Discord](https://tenstorrent.com/community) with `tt-smi -s` output

The vast majority of issues resolve at step 1, 2, or 3.

---

## Common Breakage Patterns

### 1. pip install in the Wrong Environment

**Symptom:** Something installed correctly but broke an import in tt-metal, or `pip install` warned about an externally-managed environment.

**Cause:** Installing into system Python, or into `~/.tenstorrent-venv` — which your QB2 activates at login, so a `pip install` typed without thinking lands there and can drag `tt-smi` down with it.

**Fix:**

```bash
# Identify which pip you used, and which environment is active
which pip           # or: which pip3
echo "$VIRTUAL_ENV"

# If it was system pip, uninstall the conflicting package
pip uninstall <package-name>

# If you damaged the tooling venv, rebuild it — it only ever held two tools,
# so this is cheap. Deactivate first, or you'll be deleting the venv you're in.
deactivate 2>/dev/null
rm -rf ~/.tenstorrent-venv
python3 -m venv ~/.tenstorrent-venv
source ~/.tenstorrent-venv/bin/activate
pip install tt-smi tt-flash
```

TTNN is not at risk from any of this: it lives inside the `tt-metalium` container image, not in a
venv you can pip into. If TTNN itself misbehaves, the reset is `docker pull` on the Metalium
image, not a venv rebuild.

Going forward, give every project its own venv — or install CLIs with `uv tool` / `pipx`, which
does that for you. Never use `pip install --break-system-packages` unless you have a specific
reason.

### 2. conda Conflict with tt-metal

**Symptom:** Conda activated, model fails to load, TTNN throws import errors about library version mismatches.

**Cause:** Conda replaces system libraries in `PATH`, breaking tt-metal's pinned dependencies.

**Fix:**

```bash
# Deactivate conda
conda deactivate

# Remove conda from PATH for this session
unset CONDA_DEFAULT_ENV

# Long-term: add this to your .bashrc AFTER the conda init block
# to prevent auto-activation:
conda config --set auto_activate_base false
```

Keep tt-metal environments and conda environments in separate shell sessions. They do not coexist gracefully.

### 3. Ethernet Fabric Stuck After Suspend/Resume

**Symptom:** After suspending and resuming the QB2 — or stopping and starting a serving
container without a device reset in between — the next model load or serve attempt fails with
something like:

```
Device 0 ... ethernet core ... Try resetting the board
```

**Cause:** Suspend/resume leaves the on-die Ethernet fabric that links the four chips in a stuck
state. The chips themselves are fine; it's the chip-to-chip links (the same ones AllReduce uses
for tensor-parallel) that didn't come back up cleanly. A container stop→start without a device
reset in between can trigger the same thing.

**Fix:**

```bash
# Reset the boards BEFORE every (re)start after a suspend/resume — don't wait
# for the error to show up
tt-smi -r

# Then bring the server/container back up as usual
```

If the fault recurs even after `tt-smi -r`, a full reboot (`sudo reboot`) is the durable fix —
it's the only thing that reliably clears the fabric for good.

:::callout type="tip"
Right after `tt-smi -r`, running `tt-smi -s` immediately can transiently fail or print stale
output — even though the reset actually took. Give it a few seconds and re-run `tt-smi -s`
before concluding the reset didn't work.
:::

### 4. "No Devices Found" After a Kernel Upgrade

**Symptom:** `tt-smi` returns no devices. `lsmod | grep tenstorrent` shows nothing.

**Cause:** A kernel upgrade installed a new kernel without re-building or loading the Tenstorrent driver for it.

**Fix:**

```bash
# Check if the driver module exists for the current kernel
ls /lib/modules/$(uname -r)/extra/ | grep tenstorrent

# If missing, reinstall the kernel driver package (this is the actual
# package name — "tt-firmware" doesn't exist)
sudo apt install --reinstall tenstorrent-dkms
# or re-run the tt-installer if you used that for initial setup

# Reload the driver
sudo modprobe tenstorrent

# Verify
tt-smi -s
```

If `sudo modprobe tenstorrent` fails with "module not found", the driver isn't built for the current kernel. You need to either roll back the kernel or rebuild the driver. Check the [tt-metal GitHub](https://github.com/tenstorrent/tt-metal) for the currently supported kernel range.

### 5. Model Download Corrupted Midway

**Symptom:** Model fails to load. Error messages about unexpected EOF or missing shards.

**Fix:**

```bash
# hf (not huggingface-cli) — the CLI this guide standardizes on; it resumes
# partial downloads automatically, no flag needed
hf download <model-id> --local-dir ~/models/<model-name>

# Example for Llama-3.1-8B:
hf download meta-llama/Llama-3.1-8B-Instruct \
  --local-dir ~/models/Llama-3.1-8B-Instruct
```

If the download is severely corrupted, delete the partial directory and start fresh:

```bash
rm -rf ~/models/<model-name>
hf download <model-id> --local-dir ~/models/<model-name>
```

### 6. OOM During Inference

**Symptom:** Python process crashes with out-of-memory error during model load or inference. The model may be too large for the chip DRAM, or you're only using one chip for a model that needs four.

**Fix:**

Chips are chosen by the **mesh shape** — there is no `--num_gpus` or `--tensor-parallel-size` on
this platform. The simplest way to get the mesh right is to let `tt-inference-server` derive it
from the model's spec:

```bash
# All four chips, needed for a 70B
python3 ~/.local/lib/tt-inference-server/run.py \
  --model Llama-3.1-70B-Instruct \
  --workflow server --tt-device p300x2 --docker-server
```

If you're driving `vllm serve` yourself (see [vLLM on QB2](/ml-practitioner/03-vllm-on-qb2/) for
how to get a vLLM that can — it is not installed on the host), the mesh is an environment
variable instead:

```bash
export TT_METAL_ARCH_NAME=blackhole
export MESH_DEVICE=P300x2            # all four chips
export HF_MODEL=~/models/Llama-3.1-70B-Instruct
vllm serve "$HF_MODEL" --port 8000
```

:::callout type="warn"
**Reaching for the two-chip mesh to save capacity is a trap.** `MESH_DEVICE=P300` (one card, two
chips) has failed fabric bring-up reproducibly on our hardware — `Fabric Router Sync: Timeout
after 10000 ms ... Ethernet handshake likely failed` — while one chip (`P150`) and all four
(`P300x2`) both come up fine. If you're narrowing the mesh to fit a smaller model, go to `P150`
rather than `P300`.
:::

Also check that DRAM on every chip is actually up (`tt-smi -s` doesn't report a per-chip usage figure, only link health — `board_id` and `dram_status` live under the nested `board_info` object, not at the top level):

```bash
tt-smi -s | python3 -c "
import json, sys
d = json.load(sys.stdin)
for chip in d.get('device_info', []):
    bi = chip.get('board_info', {})
    print(bi.get('board_id', '?'), '— DRAM up:', bi.get('dram_status', '?'))
"
```

If a process is still holding chip memory, `fuser /dev/tenstorrent/*` (or checking for orphaned Python/docker processes) will find it — a stuck reservation, not something `tt-smi -s` surfaces directly.

### 7. Docker or tt-inference-server Won't Start

**Symptom:** `docker ps` hangs or errors; tt-inference-server container fails to launch.

**Fix:**

```bash
# Check if Docker daemon is running
systemctl status docker

# Start it if not
sudo systemctl start docker

# Check running containers
docker ps -a

# View logs from the last failed container
docker logs $(docker ps -a -q --filter "status=exited" | head -1)

# Hard-restart a specific container
docker stop <container-name> && docker start <container-name>

# If the container is corrupted, remove and repull
docker rm <container-name>
docker pull <image-name>
# Then re-run the server start command
```

### 8. tt-toplike Crashes at Startup

**Symptom:** `tt-toplike` exits immediately or produces a panic/error message.

**Cause:** Almost always a driver issue — tt-toplike can't see the chips.

**Fix:**

```bash
# Verify chips are visible first
tt-smi -s

# If tt-smi also fails, reload the driver
sudo modprobe -r tenstorrent
sudo modprobe tenstorrent
tt-smi -s   # should now show four devices

# Then retry
tt-toplike --mode normal
```

If `tt-smi -s` works but `tt-toplike` still fails, reinstall it:

```bash
# tt-toplike is in the Tenstorrent apt PPA (set up by tt-installer):
sudo apt update && sudo apt install --reinstall tt-toplike

# apt says the repository isn't signed? See pattern 9 below.

# No repository on this machine? Install the .deb from GitHub releases instead:
# https://github.com/tenstorrent/tt-toplike/releases
sudo dpkg -i tt-toplike_*.deb
# Or: cargo install tt-toplike --force
```

:::callout type="deep-dive"
The `tenstorrent` kernel module is a loadable driver. If it was loaded for kernel `6.x.y` and you're now on `6.x.z`, it may need to be rebuilt or reinstalled. `dmesg | grep tenstorrent` is your friend here — it shows exactly why the module failed to load.
:::

### 9. apt Won't Install Tenstorrent Packages ("repository is not signed")

**Symptom:** `sudo apt update` or `sudo apt install tt-smi` (or `tt-toplike`, `tenstorrent-dkms`, `tt-flash`, …) fails with one of:

```
E: The repository 'https://ppa.tenstorrent.com/ubuntu noble InRelease' is not signed.
W: GPG error: https://ppa.tenstorrent.com/ubuntu noble InRelease: ... NO_PUBKEY ...
N: Updating from such a repository can't be done securely, and is therefore disabled by default.
```

**Cause:** The repository line in `/etc/apt/sources.list.d/tenstorrent.list` is pinned to a key at `/etc/apt/keyrings/tt-pkg-key.asc`, and that file is missing, empty, or unreadable. apt won't touch a repository it can't verify, so *nothing* from Tenstorrent installs until the key is back. Usually this means the repository was added by hand and the key step was skipped — or the download was intercepted and left a zero-byte file behind.

**Fix:**

```bash
sudo mkdir -p /etc/apt/keyrings
sudo chmod 755 /etc/apt/keyrings
sudo curl -fsSL -o /etc/apt/keyrings/tt-pkg-key.asc https://ppa.tenstorrent.com/tt-pkg-key.asc

# Confirm before retrying: a PGP block, non-zero size, mode 644
head -1 /etc/apt/keyrings/tt-pkg-key.asc
ls -l /etc/apt/keyrings/tt-pkg-key.asc

sudo apt-get update
```

Still broken? Work down this list:

| What you see | Why | Fix |
|---|---|---|
| Key file is 0 bytes, or starts with `<html` | A proxy or captive portal answered instead of the server | `sudo -E curl ...` — plain `sudo` drops your `HTTPS_PROXY` |
| `Could not open file ... Permission denied` | `_apt` can't read the key | `sudo chmod 644 /etc/apt/keyrings/tt-pkg-key.asc` |
| Still "not signed" after re-downloading | `signed-by=` path and the actual filename disagree (`.gpg` vs `.asc`, different name) | `cat /etc/apt/sources.list.d/tenstorrent.list` and make them match |
| `404` fetching `InRelease` | Wrong release codename in the repository line | `. /etc/os-release && echo "$VERSION_CODENAME"` — must match |
| Warning persists alongside a working key | Stale legacy `apt-key` entry | `sudo apt-key del <keyid>`; `signed-by=` is the supported mechanism now |

The full setup — repository line, key, and the Debian/Fedora variants — is in [Installing the Stack](/first-timer/04-installing-the-stack/#the-tenstorrent-apt-repository-and-its-signing-key).

---

**Next:** [Community & Contribution →](/tinkerer/05-community/)
