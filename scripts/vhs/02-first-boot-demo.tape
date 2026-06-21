# VHS tape for first boot walkthrough
# Record with: vhs scripts/vhs/02-first-boot-demo.tape
# NOTE: This is a window environment demo — record manually.
# This script shows the terminal portion only (after opening a terminal).

Output assets/video/02-first-boot-demo.gif

Set Shell "bash"
Set FontSize 14
Set Width 900
Set Height 500
Set Theme "Catppuccin Mocha"

Type "# Check internet connectivity"
Sleep 500ms
Enter
Sleep 300ms

Type "ping -c 3 google.com"
Sleep 500ms
Enter
Sleep 4s

Type "# Update package lists (first-time setup)"
Sleep 500ms
Enter
Sleep 300ms

Type "sudo apt update"
Sleep 500ms
Enter
Sleep 3s
# Sudo prompt requires manual interaction — pause here if recording live
