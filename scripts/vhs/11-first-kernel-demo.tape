# VHS tape — first TTNN kernel: elementwise add on Blackhole
# Record with: vhs scripts/vhs/11-first-kernel-demo.tape
#
# Helper script must live under $HOME, not /tmp: the tt-metalium container
# mounts only your home directory. Pre-write ~/vhs-ttnn-add.py before recording.

Output src/assets/video/11-first-kernel-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 560
Set Theme "Catppuccin Mocha"

Type "# Show the script: open device, create tensors, add, read back"
Sleep 400ms
Enter
Sleep 200ms

Type "cat ~/vhs-ttnn-add.py"
Sleep 400ms
Enter
Sleep 800ms

Type ""
Sleep 300ms
Enter

Type "# TTNN lives in the TT-Metalium container — run it in there"
Sleep 400ms
Enter
Sleep 200ms

Type "tt-metalium -c 'echo $TT_METAL_ARCH_NAME; python3 ~/vhs-ttnn-add.py 2>&1 | grep -v -E \"^2026|warning|info\"'"
Sleep 500ms
Enter
Sleep 6000ms

Type ""
Sleep 300ms
Enter

Type "# Result back from chip — bfloat16, shape (32, 32)"
Sleep 400ms
Enter
Sleep 400ms
