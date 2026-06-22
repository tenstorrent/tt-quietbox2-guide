# VHS tape for tt-smi demo
# Record with: vhs scripts/vhs/03-tt-smi-demo.tape

Output src/assets/video/03-tt-smi-demo.gif

Set Shell "bash"
Set FontSize 14
Set Width 900
Set Height 500
Set Theme "Catppuccin Mocha"

Type "# tt-smi is on PATH via ~/.local/bin — no activation needed"
Sleep 500ms
Enter
Sleep 300ms

Type "which tt-smi"
Sleep 400ms
Enter
Sleep 600ms

Type "# Check that all four Blackhole chips are visible"
Sleep 500ms
Enter
Sleep 200ms

Type "tt-smi -s | python3 -m json.tool | grep board_type"
Sleep 500ms
Enter
Sleep 2000ms

Type "# Four p300c entries — healthy QB2"
Sleep 500ms
Enter
Sleep 300ms

Type "tt-smi -s | python3 -m json.tool | grep -E 'aiclk|temperature|power' | head -8"
Sleep 500ms
Enter
Sleep 2000ms

Type "# aiclk in MHz, temperature in Celsius, power in Watts"
Sleep 500ms
Enter
Sleep 1000ms
