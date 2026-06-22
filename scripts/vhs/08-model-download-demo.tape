# VHS tape — model download and verification demo
# Record with: vhs scripts/vhs/08-model-download-demo.tape

Output src/assets/video/08-model-download-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 560
Set Theme "Catppuccin Mocha"

Type "# Models live in ~/models/ — let's see what's already downloaded"
Sleep 400ms
Enter
Sleep 200ms

Type "ls ~/models/Qwen3-0.6B/"
Sleep 400ms
Enter
Sleep 800ms

Type "# model.safetensors is the weights — one shard for a 0.6B model"
Sleep 400ms
Enter
Sleep 400ms

Type ""
Sleep 300ms
Enter

Type "# hf is the HuggingFace CLI — for downloading models"
Sleep 400ms
Enter
Sleep 200ms

Type "hf version"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# Download syntax: hf download <org>/<model> --local-dir ~/models/<name>"
Sleep 400ms
Enter
Sleep 200ms

Type "# Example (not running — Qwen3 is already here):"
Sleep 400ms
Enter
Sleep 200ms

Type "# hf download Qwen/Qwen3-0.6B --local-dir ~/models/Qwen3-0.6B"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# Check disk usage — models add up fast"
Sleep 400ms
Enter
Sleep 200ms

Type "du -sh ~/models/Qwen3-0.6B"
Sleep 400ms
Enter
Sleep 800ms

Type "df -h ~ | tail -1"
Sleep 400ms
Enter
Sleep 800ms
