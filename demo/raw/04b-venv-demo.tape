# VHS tape — Python environment navigation demo
# Record with: vhs demo/raw/04b-venv-demo.tape
#
# Shows the thing that actually confuses people: there is no TTNN venv on the
# host. `import ttnn` only works inside the tt-metalium container.

Output demo/assets/04b-venv-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 560
Set Theme "Catppuccin Mocha"

Type "# On the host: which Python is active, and what's in it?"
Sleep 400ms
Enter
Sleep 200ms

Type "which python3"
Sleep 400ms
Enter
Sleep 800ms

Type "echo $VIRTUAL_ENV"
Sleep 400ms
Enter
Sleep 600ms

Type "# The tooling venv — tt-smi and tt-flash. No ttnn:"
Sleep 400ms
Enter
Sleep 200ms

Type "python3 -c 'import ttnn' || echo '(expected — TTNN is not on the host)'"
Sleep 400ms
Enter
Sleep 1500ms

Type ""
Sleep 300ms
Enter

Type "# TTNN lives in the TT-Metalium container. tt-metalium is the door:"
Sleep 400ms
Enter
Sleep 200ms

Type "tt-metalium -c 'which python3; python3 -c \"import ttnn; print(ttnn.__file__)\"'"
Sleep 400ms
Enter
Sleep 5000ms

Type "# /opt/venv/bin/python3 — inside the container, nothing to activate"
Sleep 400ms
Enter
Sleep 500ms

Type ""
Sleep 300ms
Enter

Type "# Check disk space for model downloads"
Sleep 400ms
Enter
Sleep 200ms

Type "df -h ~/models"
Sleep 400ms
Enter
Sleep 1000ms
