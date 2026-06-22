# VHS tape — post-tt-installer state inspection
# Record with: vhs scripts/vhs/04-tt-installer-demo.tape

Output src/assets/video/04-tt-installer-demo.gif

Set Shell "bash"
Set FontSize 14
Set Width 900
Set Height 600
Set Theme "Catppuccin Mocha"

Type "# After tt-installer + reboot, here's what's waiting for you"
Sleep 500ms
Enter
Sleep 300ms

Type "# tt-smi and hf are on PATH via ~/.local/bin — no activation needed"
Sleep 500ms
Enter
Sleep 200ms

Type "which tt-smi && tt-smi --version"
Sleep 400ms
Enter
Sleep 1000ms

Type "which hf"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# The TTNN venv tt-installer created:"
Sleep 500ms
Enter
Sleep 200ms

Type "ls ~/tt-metal/python_env/lib/ | grep python"
Sleep 400ms
Enter
Sleep 800ms

Type ""
Sleep 300ms
Enter

Type "# Verify the chips are visible"
Sleep 500ms
Enter
Sleep 200ms

Type "tt-smi -s | python3 -m json.tool | grep board_type"
Sleep 500ms
Enter
Sleep 2000ms

Type ""
Sleep 300ms
Enter

Type "# Models directory — empty, waiting for hf download"
Sleep 500ms
Enter
Sleep 200ms

Type "ls ~/models/ 2>/dev/null | head -5 || echo '(empty — ready for hf download)'"
Sleep 400ms
Enter
Sleep 1000ms

Type "df -h ~"
Sleep 400ms
Enter
Sleep 800ms
