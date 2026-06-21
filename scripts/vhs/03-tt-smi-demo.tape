# VHS tape for tt-smi demo
# Record with: vhs scripts/vhs/03-tt-smi-demo.tape
# Install VHS: https://github.com/charmbracelet/vhs

Output assets/video/03-tt-smi-demo.gif

Set Shell "bash"
Set FontSize 14
Set Width 900
Set Height 500
Set Theme "Catppuccin Mocha"

Type "# Check that all four Blackhole chips are visible"
Sleep 500ms
Enter
Sleep 300ms

Type "tt-smi -s"
Sleep 500ms
Enter
Sleep 2s

Type "# Four entries in device_info = healthy QB2"
Sleep 500ms
Enter
Sleep 300ms

Type "tt-smi -s | python3 -m json.tool | grep board_type"
Sleep 500ms
Enter
Sleep 1s
