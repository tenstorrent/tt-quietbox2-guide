# VHS tape — tt-studio: startup and port-forwarding instructions
# Record with: vhs scripts/vhs/12-tt-studio-demo.tape

Output src/assets/video/12-tt-studio-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 520
Set Theme "Catppuccin Mocha"

Type "# tt-studio: web UI for model serving — no code required"
Sleep 400ms
Enter
Sleep 200ms

Type "which tt-studio"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# Launch it with a single command:"
Sleep 400ms
Enter
Sleep 200ms

Type "# tt-studio   (wrapper for: git clone + python3 run.py — opens http://localhost:3000)"
Sleep 400ms
Enter
Sleep 400ms

Type ""
Sleep 300ms
Enter

Type "# To access from your laptop over SSH, forward the port:"
Sleep 400ms
Enter
Sleep 200ms

Type "# ssh -L 3000:localhost:3000 -L 4000:localhost:4000 ttuser@qb2-hostname"
Sleep 400ms
Enter
Sleep 500ms

Type ""
Sleep 300ms
Enter

Type "# Then open http://localhost:3000 on your laptop"
Sleep 400ms
Enter
Sleep 400ms

Type ""
Sleep 300ms
Enter

Type "# tt-studio --help shows what flags are available"
Sleep 400ms
Enter
Sleep 200ms

Type "tt-studio --help 2>&1 | head -12"
Sleep 400ms
Enter
Sleep 1000ms
