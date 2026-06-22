# VHS tape — first boot: terminal basics on a live QB2
# Record with: vhs scripts/vhs/02-first-boot-demo.tape

Output src/assets/video/02-first-boot-demo.gif

Set Shell "bash"
Set FontSize 14
Set Width 900
Set Height 500
Set Theme "Catppuccin Mocha"

Type "# Welcome to the QB2 terminal — let's orient"
Sleep 400ms
Enter
Sleep 200ms

Type "uname -a"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# Check internet connectivity"
Sleep 400ms
Enter
Sleep 200ms

Type "ping -c 3 8.8.8.8"
Sleep 400ms
Enter
Sleep 4500ms

Type ""
Sleep 300ms
Enter

Type "# Check disk space — models take a lot"
Sleep 400ms
Enter
Sleep 200ms

Type "df -h ~ | head -2"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# Your home directory structure after tt-installer"
Sleep 400ms
Enter
Sleep 200ms

Type "ls ~/"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# tt-smi is on PATH — hardware is live"
Sleep 400ms
Enter
Sleep 200ms

Type "which tt-smi && tt-smi --version"
Sleep 400ms
Enter
Sleep 800ms
