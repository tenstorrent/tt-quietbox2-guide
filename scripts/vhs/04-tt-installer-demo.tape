# VHS tape for tt-installer demo
# Record with: vhs scripts/vhs/04-tt-installer-demo.tape
# NOTE: This requires a fresh Ubuntu 24.04 system — record on a VM

Output assets/video/04-tt-installer-demo.gif

Set Shell "bash"
Set FontSize 14
Set Width 900
Set Height 600
Set Theme "Catppuccin Mocha"

Type "# Install prerequisites"
Sleep 500ms
Enter
Sleep 300ms

Type "sudo apt update && sudo apt install -y curl jq"
Sleep 500ms
Enter
Sleep 3s

Type "# Run the tt-installer"
Sleep 500ms
Enter
Sleep 300ms

Type '/bin/bash -c "$(curl -fsSL https://github.com/tenstorrent/tt-installer/releases/latest/download/install.sh)"'
Sleep 500ms
Enter
Sleep 2s
# At this point a human must interact with the installer prompts
# Record manually from here
