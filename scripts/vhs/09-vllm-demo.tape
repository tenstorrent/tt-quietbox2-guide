# VHS tape — serving a model on QB2
# Record with: vhs scripts/vhs/09-vllm-demo.tape
#
# Rewritten: there is no vLLM venv on a QB2. vLLM ships inside the container
# that tt-inference-server's run.py launches, so that is what this shows.

Output src/assets/video/09-vllm-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 600
Set Theme "Catppuccin Mocha"

Type "# vLLM is not installed on the host — it runs in a container"
Sleep 400ms
Enter
Sleep 200ms

Type "python3 -c 'import vllm' || echo '(expected — vLLM is not on the host)'"
Sleep 400ms
Enter
Sleep 1500ms

Type ""
Sleep 300ms
Enter

Type "# The launcher that starts it is preinstalled:"
Sleep 400ms
Enter
Sleep 200ms

Type "ls ~/.local/lib/tt-inference-server/run.py"
Sleep 400ms
Enter
Sleep 800ms

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

Type "# --tt-device p300x2 is the whole box: two P300 boards, four chips"
Sleep 400ms
Enter
Sleep 200ms

Type "# (shown — needs weights and an idle machine to actually run)"
Sleep 400ms
Enter
Sleep 200ms

Type "# python3 ~/.local/lib/tt-inference-server/run.py \\"
Sleep 400ms
Enter
Sleep 200ms

Type "#   --model Llama-3.1-8B-Instruct --workflow server \\"
Sleep 400ms
Enter
Sleep 200ms

Type "#   --tt-device p300x2 --docker-server"
Sleep 400ms
Enter
Sleep 800ms

Type ""
Sleep 300ms
Enter

Type "# --print-docker-cmd shows the docker run it would issue"
Sleep 400ms
Enter
Sleep 1000ms
