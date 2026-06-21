# VHS tape — first model run: TTNN handshake + hf download + vLLM serve
# Record with: vhs scripts/vhs/05-first-model-demo.tape

Output assets/video/05-first-model-demo.gif

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

Type "python3 -c \""
Sleep 200ms
Type "import ttnn; "
Type "d = ttnn.open_device(device_id=0); "
Type "print('Device open:', d); "
Type "ttnn.close_device(d); "
Type "print('Done.')\""
Sleep 500ms
Enter
Sleep 4000ms

Type "# 'Device open:' means chip 0 is alive"
Sleep 400ms
Enter
Sleep 300ms
Type "deactivate"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# Step 3: check disk space before downloading"
Sleep 400ms
Enter
Sleep 200ms

Type "df -h ~/models"
Sleep 400ms
Enter
Sleep 800ms

Type ""
Sleep 300ms
Enter

Type "# Step 4: download Qwen3-0.6B (1.5 GB, no token required)"
Sleep 400ms
Enter
Sleep 200ms

Type "source ~/tt-metal/python_env/bin/activate"
Sleep 300ms
Enter
Sleep 800ms

Type "hf download Qwen/Qwen3-0.6B --local-dir ~/models/Qwen3-0.6B"
Sleep 500ms
Enter
Sleep 5000ms
# Download takes time — record manually for the full download progress

Type "ls ~/models/Qwen3-0.6B/"
Sleep 400ms
Enter
Sleep 800ms

Type "deactivate"
Sleep 400ms
Enter
Sleep 400ms
