# VHS tape — vLLM on QB2 demo
# Record with: vhs scripts/vhs/09-vllm-demo.tape

Output src/assets/video/09-vllm-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 560
Set Theme "Catppuccin Mocha"

Type "# vLLM runs in a dedicated venv on a QB2"
Sleep 400ms
Enter
Sleep 200ms

Type "# The TTNN venv: ~/tt-metal/python_env/"
Sleep 400ms
Enter
Sleep 200ms

Type "# The vLLM venv: ~/tt-metal/build/python_env_vllm/ (created by tt-installer)"
Sleep 400ms
Enter
Sleep 400ms

Type ""
Sleep 300ms
Enter

Type "# Activate the TTNN venv — confirm hardware access"
Sleep 400ms
Enter
Sleep 200ms

Type "source ~/tt-metal/python_env/bin/activate"
Sleep 400ms
Enter
Sleep 1000ms

Type "which python3"
Sleep 400ms
Enter
Sleep 600ms

Type ""
Sleep 300ms
Enter

Type "# tt-smi confirms hardware is ready before serving"
Sleep 400ms
Enter
Sleep 200ms

Type "tt-smi -s | python3 -m json.tool | grep board_type"
Sleep 400ms
Enter
Sleep 1500ms

Type "# Four p300c chips — ready to serve a multi-chip model"
Sleep 400ms
Enter
Sleep 500ms

Type ""
Sleep 300ms
Enter

Type "# The vLLM serve command (shown — requires model weights to run)"
Sleep 400ms
Enter
Sleep 200ms

Type "# vllm serve ~/models/Llama-3.1-8B-Instruct --port 8000"
Sleep 400ms
Enter
Sleep 500ms

Type ""
Sleep 300ms
Enter

Type "deactivate"
Sleep 400ms
Enter
Sleep 600ms
