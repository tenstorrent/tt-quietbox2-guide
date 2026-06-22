# VHS tape — LED customization: tt-smi telemetry for LED scripting
# Record with: vhs scripts/vhs/10-led-telemetry-demo.tape
# Shows the tt-smi data the LED monitor script reads

Output src/assets/video/10-led-telemetry-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 560
Set Theme "Catppuccin Mocha"

Type "# The LED monitor script reads tt-smi -s every 2 seconds"
Sleep 400ms
Enter
Sleep 200ms

Type "# Let's see the telemetry fields it drives LEDs from:"
Sleep 400ms
Enter
Sleep 200ms

Type "tt-smi -s | python3 -m json.tool | grep -E 'asic_temp|power|aiclk' | head -12"
Sleep 400ms
Enter
Sleep 1500ms

Type ""
Sleep 300ms
Enter

Type "# Per-chip telemetry — temperature, power, and clock"
Sleep 400ms
Enter
Sleep 200ms

Type "tt-smi -s | python3 -m json.tool | grep -A2 'chip_telemetry' | head -16"
Sleep 400ms
Enter
Sleep 1500ms

Type ""
Sleep 300ms
Enter

Type "# LED commands come from: tt-smi --help | grep -i led"
Sleep 400ms
Enter
Sleep 200ms

Type "tt-smi --help 2>&1 | grep -i 'led\|light\|indicator' || echo 'LED commands depend on firmware version'"
Sleep 400ms
Enter
Sleep 1000ms

Type "# Check firmware version per chip"
Sleep 400ms
Enter
Sleep 200ms

Type "tt-smi -s | python3 -m json.tool | grep 'fw_version' | head -4"
Sleep 400ms
Enter
Sleep 1200ms
