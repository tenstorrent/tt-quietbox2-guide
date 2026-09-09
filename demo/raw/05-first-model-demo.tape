# VHS tape - first model run: TTNN device open + model files
# Record with: vhs demo/raw/05-first-model-demo.tape
#
# Recorded inside tenstorrent/qb2-env:latest with hardware passed through (see
# 04-tt-installer-demo.tape's note). ~/models is bind-mounted to a host
# directory pre-populated with a real `hf download Qwen/Qwen3-0.6B` so the
# "already downloaded" framing is genuinely true, not staged - confirmed live
# this session that a real download is exactly one model.safetensors file.
# The device-open script is written into the container's $HOME via a hidden
# heredoc before the visible recording starts (matches the guide's own
# "write it yourself" framing - see shared/run-first-model.md).
#
# IMPORTANT: this calls ttnn.open_device(), which exclusively locks the chip
# at the driver level. Passing the whole /dev/tenstorrent directory lets it
# collide with any OTHER lease-holder's chip 0 and crash with a UMD/driver
# stack trace. Pass only your gozer-leased device nodes explicitly (map
# leased PCI bus IDs to /dev/tenstorrent/N via `tt-smi -s`'s device order,
# which matches by-index) -- update the --device flags below to match
# whatever chips you actually hold before recording.

Output demo/assets/05-first-model-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 560
Set Theme "Catppuccin Mocha"

Hide
Type "docker run --rm -it --device /dev/tenstorrent/2 --device /dev/tenstorrent/3 -v /dev/hugepages-1G:/dev/hugepages-1G -v /tmp/claude-1000/-home-ttuser-code-qb2-guide/255c2b33-5099-4393-a2e4-acdcbca3eb50/scratchpad/qb2vhs-models:/home/ttuser/models tenstorrent/qb2-env:latest bash"
Enter
Sleep 3000ms
Type "cat > ~/vhs-open-device.py << 'PYEOF'"
Enter
Type "import ttnn"
Enter
Type "device = ttnn.open_device(device_id=0)"
Enter
Type "print('Device open:', device)"
Enter
Type "ttnn.close_device(device)"
Enter
Type "print('Done.')"
Enter
Type "PYEOF"
Enter
Sleep 500ms
Type "clear"
Enter
Sleep 500ms
Show

Type "# Step 1: enter the TTNN environment - a container, not a venv"
Sleep 400ms
Enter
Sleep 200ms

Type "# Step 2: open device 0 from inside it - the hardware handshake"
Sleep 400ms
Enter
Sleep 200ms

Type "tt-metalium -c 'python3 ~/vhs-open-device.py'"
Sleep 500ms
Enter
Sleep 6000ms

Type "# Device open: MeshDevice - chip 0 is alive"
Sleep 400ms
Enter
Sleep 500ms

Type ""
Sleep 300ms
Enter

Type "# Step 3: Qwen3-0.6B is already downloaded (on the host - ~/ is shared)"
Sleep 400ms
Enter
Sleep 200ms

Type "ls ~/models/Qwen3-0.6B/"
Sleep 400ms
Enter
Sleep 800ms

Type "# model.safetensors - the weights are here"
Sleep 400ms
Enter
Sleep 500ms

Type ""
Sleep 300ms
Enter

Type "# Step 4: to download a model yourself (install the hf CLI first):"
Sleep 400ms
Enter
Sleep 200ms

Type "# uv tool install huggingface_hub"
Sleep 400ms
Enter
Sleep 300ms

Type "# hf download Qwen/Qwen3-0.6B --local-dir ~/models/Qwen3-0.6B"
Sleep 400ms
Enter
Sleep 600ms

Type "df -h ~/models"
Sleep 400ms
Enter
Sleep 800ms
