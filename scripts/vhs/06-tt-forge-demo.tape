# VHS tape — TT-Forge: environment and compile pattern demo
# Record with: vhs scripts/vhs/06-tt-forge-demo.tape

Output src/assets/video/06-tt-forge-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 560
Set Theme "Catppuccin Mocha"

Type "# TT-Forge: compile PyTorch models to Tenstorrent silicon"
Sleep 500ms
Enter
Sleep 300ms

Type "# Activate the forge venv (Python 3.12)"
Sleep 500ms
Enter
Sleep 200ms

Type "# source ~/tt-forge-venv/bin/activate"
Sleep 400ms
Enter
Sleep 500ms

Type ""
Sleep 300ms
Enter

Type "# The full compile-and-run pattern:"
Sleep 500ms
Enter
Sleep 300ms

Type "cat /tmp/vhs-forge-pattern.py"
Sleep 400ms
Enter
Sleep 1000ms

Type ""
Sleep 300ms
Enter

Type "# Hardware ready — four Blackhole chips:"
Sleep 500ms
Enter
Sleep 200ms

Type "tt-smi -s | python3 -m json.tool | grep board_type"
Sleep 400ms
Enter
Sleep 2000ms

Type "# p300c x4 — the forge compilation target"
Sleep 400ms
Enter
Sleep 800ms

Type ""
Sleep 300ms
Enter

Type "# Check chip clocks and temperatures"
Sleep 400ms
Enter
Sleep 200ms

Type "tt-smi -s | python3 -m json.tool | grep -E 'aiclk|temperature' | head -8"
Sleep 400ms
Enter
Sleep 2000ms
