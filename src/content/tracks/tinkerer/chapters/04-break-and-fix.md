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
4. Reload the driver: `sudo modprobe -r tenstorrent && sudo modprobe tenstorrent`
5. Reboot: `sudo reboot`
6. Post to the [Tenstorrent Discord](https://tenstorrent.com/community) with `tt-smi -s` output

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

### 3. "No Devices Found" After a Kernel Upgrade

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

### 4. Model Download Corrupted Mid-Way

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

### 5. OOM During Inference

**Symptom:** Python process crashes with out-of-memory error during model load or inference. The model may be too large for the chip DRAM, or you're only using one chip for a model that needs four.

**Fix:**

```bash
# Verify you're using all four chips for large models
python3 -m vllm.entrypoints.openai.api_server \
  --model ~/models/Llama-3.1-70B-Instruct \
  --num_gpus 4 \           # this is required for 70B
  --port 8000

# For a smaller model that fits on fewer chips
python3 -m vllm.entrypoints.openai.api_server \
  --model ~/models/Qwen3-0.6B \
  --num_gpus 1 \
  --port 8000
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

### 6. Docker or tt-inference-server Won't Start

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

### 7. tt-toplike Crashes at Startup

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

If `tt-smi -s` works but tt-toplike still fails, update to the latest version:

```bash
sudo apt install --reinstall tt-toplike
```

If `apt` can't find the package, the Tenstorrent PPA may need to be re-added — see [docs.tenstorrent.com](https://docs.tenstorrent.com/getting-started/installation).

{% tensixviz "blackhole", [
  {"step": "highlight", "cores": [[1,1],[2,1],[3,1],[4,1],[5,1],[6,1],[7,1],[9,1],[10,1],[11,1],[12,1],[13,1],[14,1],[15,1],[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[7,2],[9,2],[10,2],[11,2],[12,2],[13,2],[14,2],[15,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3],[9,3],[10,3],[11,3],[12,3],[13,3],[14,3],[15,3],[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4],[9,4],[10,4],[11,4],[12,4],[13,4],[14,4],[15,4],[1,5],[2,5],[3,5],[4,5],[5,5],[6,5],[7,5],[9,5],[10,5],[11,5],[12,5],[13,5],[14,5],[15,5],[1,6],[2,6],[3,6],[4,6],[5,6],[6,6],[7,6],[9,6],[10,6],[11,6],[12,6],[13,6],[14,6],[15,6],[1,7],[2,7],[3,7],[4,7],[5,7],[6,7],[7,7],[9,7],[10,7],[11,7],[12,7],[13,7],[14,7],[15,7],[1,8],[2,8],[3,8],[4,8],[5,8],[6,8],[7,8],[9,8],[10,8],[11,8],[12,8],[13,8],[14,8],[15,8],[1,9],[2,9],[3,9],[4,9],[5,9],[6,9],[7,9],[9,9],[10,9],[11,9],[12,9],[13,9],[14,9],[15,9],[1,10],[2,10],[3,10],[4,10],[5,10],[6,10],[7,10],[9,10],[10,10],[11,10],[12,10],[13,10],[14,10],[15,10]], "color": "tensixActive", "label": "Chips 0, 1, 2 active", "ms": 700},
  {"step": "pause", "ms": 500},
  {"step": "highlight", "cores": [[8,1],[8,2],[8,3],[8,4],[8,5],[8,6],[8,7],[8,8],[8,9],[8,10]], "color": "pcie", "label": "Chip 3 PCIe column — not responding (driver not loaded)", "ms": 700},
  {"step": "pause", "ms": 1000},
  {"step": "clear"}
] %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">A chip going dark in diagnostics. Usually a driver reload brings it back.</p>

:::callout type="deep-dive"
The `tenstorrent` kernel module is a loadable driver. If it was loaded for kernel `6.x.y` and you're now on `6.x.z`, it may need to be rebuilt or reinstalled. `dmesg | grep tenstorrent` is your friend here — it shows exactly why the module failed to load.
:::

---

**Next:** [Community & Contribution →](/tinkerer/05-community/)
