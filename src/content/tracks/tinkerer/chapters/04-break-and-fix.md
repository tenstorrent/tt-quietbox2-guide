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

**Cause:** Installing into system Python, or into a tt-metal venv that shouldn't be modified.

**Fix:**

```bash
# Identify which pip you used
which pip   # or: which pip3

# If it was system pip, uninstall the conflicting package
pip uninstall <package-name>

# If you modified a tt-metal venv, recreate it:
# First, note the requirements file for that venv, then:
rm -rf ~/tt-metal/python_env
# Re-run the tt-metal environment setup script
# (check ~/tt-metal/README.md for the exact command)
```

Going forward, always activate a project-specific venv before installing packages. Never use `pip install --break-system-packages` unless you have a specific reason.

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

# If missing, reinstall the tt-metal driver package
sudo apt install --reinstall tt-firmware   # adjust package name as needed
# or re-run the tt-installer if you used that for initial setup

# Reload the driver
sudo modprobe tenstorrent

# Verify
tt-smi -s
```

If `sudo modprobe tenstorrent` fails with "module not found", the driver isn't built for the current kernel. You need to either roll back the kernel or rebuild the driver. Check the [tt-metal GitHub](https://github.com/tenstorrent/tt-metal) for the currently supported kernel range.

### 5. Model Download Corrupted Mid-Way

**Symptom:** Model fails to load. Error messages about unexpected EOF or missing shards.

**Fix:**

```bash
# The Hugging Face CLI supports resumable downloads
huggingface-cli download <model-id> \
  --local-dir ~/models/<model-name> \
  --resume-download

# Example for Llama-3.1-8B:
huggingface-cli download meta-llama/Llama-3.1-8B-Instruct \
  --local-dir ~/models/Llama-3.1-8B-Instruct \
  --resume-download
```

If the download is severely corrupted, delete the partial directory and start fresh:

```bash
rm -rf ~/models/<model-name>
huggingface-cli download <model-id> --local-dir ~/models/<model-name>
```

### 6. OOM During Inference

**Symptom:** Python process crashes with out-of-memory error during model load or inference. The model may be too large for the chip DRAM, or you're only using one chip for a model that needs four.

**Fix:**

```bash
# Chips are chosen by the mesh shape — there is no --num_gpus or
# --tensor-parallel-size on this platform.

# All four chips, needed for a 70B
export MESH_DEVICE=P300x2
export HF_MODEL=~/models/Llama-3.1-70B-Instruct
vllm serve ~/models/Llama-3.1-70B-Instruct --port 8000

# A single card (two chips) for something smaller
export MESH_DEVICE=P300
export HF_MODEL=~/models/Llama-3.1-8B-Instruct
vllm serve ~/models/Llama-3.1-8B-Instruct --port 8000
```

Also check that no other process is holding chip memory:

```bash
tt-smi -s | python3 -c "
import json, sys
d = json.load(sys.stdin)
for chip in d.get('device_info', []):
    print(chip.get('board_id', '?'), '— mem used:', chip.get('dram_usage', '?'))
"
```

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

# No PPA on this machine? Install the .deb from GitHub releases instead:
# https://github.com/tenstorrent/tt-toplike/releases
sudo dpkg -i tt-toplike_*.deb
# Or: cargo install tt-toplike --force
```

:::callout type="deep-dive"
The `tenstorrent` kernel module is a loadable driver. If it was loaded for kernel `6.x.y` and you're now on `6.x.z`, it may need to be rebuilt or reinstalled. `dmesg | grep tenstorrent` is your friend here — it shows exactly why the module failed to load.
:::

---

**Next:** [Community & Contribution →](/tinkerer/05-community/)
