# VHS tape — first TTNN kernel: elementwise add on Blackhole
# Record with: vhs scripts/vhs/11-first-kernel-demo.tape
# Uses /tmp/vhs-ttnn-add.py (pre-written helper script)

Output src/assets/video/11-first-kernel-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 560
Set Theme "Catppuccin Mocha"

Type "# Activate the TTNN venv"
Sleep 400ms
Enter
Sleep 200ms

Type "source ~/tt-metal/python_env/bin/activate"
Sleep 400ms
Enter
Sleep 1200ms

Type "# Show the script: open device, create tensors, add, read back"
Sleep 400ms
Enter
Sleep 200ms

Type "cat /tmp/vhs-ttnn-add.py"
Sleep 400ms
Enter
Sleep 800ms

Type ""
Sleep 300ms
Enter

Type "# Run it — device open handshake first, then tile dispatch"
Sleep 400ms
Enter
Sleep 200ms

Type "python3 /tmp/vhs-ttnn-add.py 2>&1 | grep -v '^2026' | grep -v 'warning' | grep -v 'info'"
Sleep 500ms
Enter
Sleep 5000ms

Type ""
Sleep 300ms
Enter

Type "# Result back from chip — bfloat16, shape (32, 32)"
Sleep 400ms
Enter
Sleep 400ms

Type "deactivate"
Sleep 400ms
Enter
Sleep 600ms
