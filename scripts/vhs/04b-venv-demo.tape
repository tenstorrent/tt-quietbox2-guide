# VHS tape — Python environment navigation demo
# Record with: vhs scripts/vhs/04b-venv-demo.tape
# Shows: which python3 before/after activation, the three Tenstorrent venvs

Output assets/video/04b-venv-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 520
Set Theme "Catppuccin Mocha"

Type "# Check which Python is active before activating anything"
Sleep 400ms
Enter
Sleep 200ms

Type "which python3"
Sleep 400ms
Enter
Sleep 800ms

Type "# /usr/bin/python3 — that's the system Python. Don't pip install here."
Sleep 400ms
Enter
Sleep 300ms

Type "echo $VIRTUAL_ENV"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# Activate the TTNN environment"
Sleep 400ms
Enter
Sleep 200ms

Type "source ~/tt-metal/python_env/bin/activate"
Sleep 400ms
Enter
Sleep 1200ms

Type "which python3"
Sleep 400ms
Enter
Sleep 800ms

Type "# ~/tt-metal/python_env/bin/python3 — the TTNN venv"
Sleep 400ms
Enter
Sleep 300ms

Type "python3 -c \"import ttnn; print('ttnn', ttnn.__version__)\""
Sleep 400ms
Enter
Sleep 2000ms

Type "deactivate"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# Switch to the vLLM environment"
Sleep 400ms
Enter
Sleep 200ms

Type "source ~/tt-metal/build/python_env_vllm/bin/activate"
Sleep 400ms
Enter
Sleep 1200ms


Type "which python3"
Sleep 400ms
Enter
Sleep 800ms

Type "python3 -c \"import vllm; print('vllm ready')\""
Sleep 400ms
Enter
Sleep 1500ms

Type "deactivate"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# Check disk space before any model downloads"
Sleep 400ms
Enter
Sleep 200ms

Type "df -h ~/models"
Sleep 400ms
Enter
Sleep 1000ms
