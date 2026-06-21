# VHS tape — post-tt-installer state inspection
# Record with: vhs scripts/vhs/04-tt-installer-demo.tape
#
# Audience: viewer has just run tt-installer and rebooted.
# This tape shows what got installed — not the installer prompts themselves
# (which are interactive and can't be scripted).
#
# Run inside the tenstorrent/qb2-env container or on a real QB2.

Output assets/video/04-tt-installer-demo.gif

Set Shell "bash"
Set FontSize 14
Set Width 900
Set Height 600
Set Theme "Catppuccin Mocha"

Type "# After tt-installer + reboot, here's what's waiting"
Sleep 500ms
Enter
Sleep 300ms

Type "# The three Python environments tt-installer created:"
Sleep 500ms
Enter
Sleep 200ms

Type "ls ~/tt-metal/python_env/lib/ | grep python"
Sleep 400ms
Enter
Sleep 800ms

Type "ls ~/tt-metal/build/python_env_vllm/lib/ | grep python"
Sleep 400ms
Enter
Sleep 800ms

Type "ls ~/tt-forge-venv/lib/ | grep python"
Sleep 400ms
Enter
Sleep 800ms

Type ""
Sleep 300ms
Enter

Type "# tt-smi and hf are on PATH without activating anything"
Sleep 500ms
Enter
Sleep 200ms

Type "which tt-smi"
Sleep 400ms
Enter
Sleep 600ms

Type "which hf"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# Verify the chips are visible"
Sleep 500ms
Enter
Sleep 200ms

Type "tt-smi -s | python3 -m json.tool | grep -E 'board_type|device_id' | head -8"
Sleep 500ms
Enter
Sleep 2000ms

Type ""
Sleep 300ms
Enter

Type "# tt-inference-server is pre-cloned and ready"
Sleep 500ms
Enter
Sleep 200ms

Type "ls ~/.local/lib/tt-inference-server/"
Sleep 400ms
Enter
Sleep 800ms

Type ""
Sleep 300ms
Enter

Type "# Models directory is empty — nothing downloaded yet"
Sleep 500ms
Enter
Sleep 200ms

Type "ls ~/models/"
Sleep 400ms
Enter
Sleep 800ms

Type "df -h ~"
Sleep 400ms
Enter
Sleep 800ms
