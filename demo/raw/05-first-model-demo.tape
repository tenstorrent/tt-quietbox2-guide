# VHS tape — first model run: TTNN device open + model files
# Record with: vhs demo/raw/05-first-model-demo.tape
#
# Helper script must live under $HOME, not /tmp: the tt-metalium container
# mounts only your home directory, so a script in /tmp is invisible inside it.
# Pre-write ~/vhs-open-device.py before recording.

Output demo/assets/05-first-model-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 560
Set Theme "Catppuccin Mocha"

Type "# Step 1: enter the TTNN environment — a container, not a venv"
Sleep 400ms
Enter
Sleep 200ms

Type "# Step 2: open device 0 from inside it — the hardware handshake"
Sleep 400ms
Enter
Sleep 200ms

Type "tt-metalium -c 'python3 ~/vhs-open-device.py'"
Sleep 500ms
Enter
Sleep 6000ms

Type "# Device open: MeshDevice — chip 0 is alive"
Sleep 400ms
Enter
Sleep 500ms

Type ""
Sleep 300ms
Enter

Type "# Step 3: Qwen3-0.6B is already downloaded (on the host — ~/ is shared)"
Sleep 400ms
Enter
Sleep 200ms

Type "ls ~/models/Qwen3-0.6B/"
Sleep 400ms
Enter
Sleep 800ms

Type "# model.safetensors — the weights are here"
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
