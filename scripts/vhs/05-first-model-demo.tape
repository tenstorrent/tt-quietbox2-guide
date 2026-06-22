# VHS tape — first model run: TTNN device open + model files
# Record with: vhs scripts/vhs/05-first-model-demo.tape

Output src/assets/video/05-first-model-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 560
Set Theme "Catppuccin Mocha"

Type "# Step 1: activate the TTNN environment"
Sleep 400ms
Enter
Sleep 200ms

Type "source ~/tt-metal/python_env/bin/activate"
Sleep 400ms
Enter
Sleep 1200ms

Type "# Step 2: open device 0 — the hardware handshake"
Sleep 400ms
Enter
Sleep 200ms

Type "python3 /tmp/vhs-open-device.py"
Sleep 500ms
Enter
Sleep 5000ms

Type "# Device open: MeshDevice — chip 0 is alive"
Sleep 400ms
Enter
Sleep 500ms

Type "deactivate"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# Step 3: Qwen3-0.6B is already downloaded"
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

Type "# Step 4: to download a model yourself:"
Sleep 400ms
Enter
Sleep 200ms

Type "# hf download Qwen/Qwen3-0.6B --local-dir ~/models/Qwen3-0.6B"
Sleep 400ms
Enter
Sleep 600ms

Type "df -h ~/models"
Sleep 400ms
Enter
Sleep 800ms
