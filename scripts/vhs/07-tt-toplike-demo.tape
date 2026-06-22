# VHS tape — tt-toplike hardware monitor demo
# Record with: vhs scripts/vhs/07-tt-toplike-demo.tape

Output src/assets/video/07-tt-toplike-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 560
Set Theme "Catppuccin Mocha"

Type "# tt-toplike — real-time hardware monitor for Blackhole chips"
Sleep 400ms
Enter
Sleep 200ms

Type "which tt-toplike && tt-toplike --version"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# Check all four chips at a glance with snapshot mode:"
Sleep 400ms
Enter
Sleep 200ms

Type "tt-smi -s | python3 -m json.tool | grep -E 'board_type|aiclk|power' | head -12"
Sleep 400ms
Enter
Sleep 1500ms

Type ""
Sleep 300ms
Enter

Type "# tt-toplike --mode arcade shows live chip activity as ASCII art"
Sleep 400ms
Enter
Sleep 200ms

Type "# (run it yourself — it's interactive, can't record live TUI here)"
Sleep 400ms
Enter
Sleep 400ms

Type "# But we can see the modes available:"
Sleep 400ms
Enter
Sleep 200ms

Type "tt-toplike --help 2>&1 | head -20"
Sleep 400ms
Enter
Sleep 1000ms
