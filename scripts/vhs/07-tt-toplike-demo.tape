# VHS tape — tt-toplike TUI demo
# Records the live tt-toplike TUI running against QB2 hardware.
# Record with: vhs scripts/vhs/07-tt-toplike-demo.tape

Output src/assets/video/07-tt-toplike-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 1000
Set Height 600
Set Theme "Catppuccin Mocha"

# Brief lead-in so viewers know what they're about to see
Type "# tt-toplike — real-time Blackhole hardware monitor"
Sleep 500ms
Enter
Sleep 300ms

Type "tt-toplike"
Sleep 400ms
Enter

# Let the TUI initialize and render the first few frames
Sleep 3s

# Pause on the default view so the layout is readable
Sleep 2s

# Press 'f' to switch to flow mode (NOC particle visualization)
Type "f"
Sleep 3s

# Press 'a' to switch to arcade mode
Type "a"
Sleep 3s

# Back to default view
Type "d"
Sleep 2s

# Quit
Type "q"
Sleep 500ms
