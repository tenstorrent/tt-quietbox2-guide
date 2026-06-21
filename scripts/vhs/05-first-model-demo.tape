# VHS tape for first model / TTNN device verification
# Record with: vhs scripts/vhs/05-first-model-demo.tape

Output assets/video/05-first-model-demo.gif

Set Shell "bash"
Set FontSize 14
Set Width 900
Set Height 500
Set Theme "Catppuccin Mocha"

Type "source ~/tt-metal/python_env/bin/activate"
Sleep 500ms
Enter
Sleep 1s

Type "python3 -c \""
Sleep 200ms
Type "import ttnn; "
Type "device = ttnn.open_device(device_id=0); "
Type "print('Device open:', device); "
Type "ttnn.close_device(device); "
Type "print('Done.')\""
Sleep 500ms
Enter
Sleep 4s

Type "# If you see 'Device open:' without errors, you're ready"
Sleep 500ms
Enter
