# VHS tape - post-tt-installer state inspection
# Record with: vhs demo/raw/04-tt-installer-demo.tape
#
# The point of this one is to show what the installer ACTUALLY leaves behind:
# one venv holding the hardware tools, plus container wrappers. Deliberately does
# not claim `hf` is present - it isn't installed by tt-installer.
#
# Recorded inside tenstorrent/qb2-env:latest (the corrected Dockerfile.qb2 image,
# factory-layout-accurate) with real hardware passed through - this box's own
# host ~/.tenstorrent-venv has accumulated dev-tool pollution over time and would
# show something a factory QB2 never has. The Hide block below enters that
# container invisibly so the recording opens straight into a factory-accurate
# shell, exactly like a real QB2 would.

Output demo/assets/04-tt-installer-demo.gif

Set Shell "bash"
Set FontSize 14
Set Width 900
Set Height 600
Set Theme "Catppuccin Mocha"

Hide
Type "docker run --rm -it --device /dev/tenstorrent -v /dev/hugepages-1G:/dev/hugepages-1G tenstorrent/qb2-env:latest bash -l"
Enter
Sleep 3000ms
Type "clear"
Enter
Sleep 500ms
Show

Type "# After tt-installer + reboot, here's what's waiting for you"
Sleep 500ms
Enter
Sleep 300ms

Type "which tt-smi && tt-smi --version"
Sleep 400ms
Enter
Sleep 1000ms

Type ""
Sleep 300ms
Enter

Type "# The one venv it creates - hardware tooling only"
Sleep 500ms
Enter
Sleep 200ms

Type "ls ~/.tenstorrent-venv/bin/ | grep -E 'tt-|python'"
Sleep 400ms
Enter
Sleep 1000ms

Type ""
Sleep 300ms
Enter

Type "# TTNN and vLLM are not here - they're containers, reached by these wrappers:"
Sleep 500ms
Enter
Sleep 200ms

Type "ls ~/.local/bin/ | grep -E 'tt-metalium|tt-studio|tt-forge'"
Sleep 400ms
Enter
Sleep 1000ms

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

Type "# Models directory - the hf CLI is NOT preinstalled; install it separately"
Sleep 500ms
Enter
Sleep 200ms

Type "ls ~/models/ 2>/dev/null | head -5 || echo '(empty - uv tool install huggingface_hub first)'"
Sleep 400ms
Enter
Sleep 1000ms

Type "df -h ~"
Sleep 400ms
Enter
Sleep 800ms
