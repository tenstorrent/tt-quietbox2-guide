# VHS tape — tt-studio v2.8.0: Claude Code against a local model on your QB2
# Record ON the QB2 with: vhs scripts/vhs/13-tt-studio-coding-agents.tape
#
# PREREQUISITES (do these first, in the shell you record from):
#   1. tt-studio running, with an eligible model DEPLOYED (Qwen3-32B is
#      pre-cached — deploy it from the Deploy Model dropdown).
#   2. The LiteLLM gateway healthy on :4000 (check the Coding Agents page).
#   3. Export the gateway key WITHOUT printing it, so it never lands in the GIF:
#        export LITELLM_MASTER_KEY=$(grep -E '^LITELLM_MASTER_KEY=' ~/tt-studio/.env | cut -d= -f2-)
#      (or copy it from the Coding Agents page). The tape references the
#      variable, never the literal key.
#   4. `claude` (Claude Code) installed and on PATH.

Output src/assets/video/13-tt-studio-coding-agents.gif

Set Shell "bash"
Set FontSize 13
Set Width 1100
Set Height 660
Set Theme "Catppuccin Mocha"

Type "# tt-studio v2.8.0 — run Claude Code against a model on your OWN chips"
Sleep 500ms
Enter
Sleep 300ms

Type "# 1) Point Claude Code at tt-studio's Anthropic gateway on :4000"
Sleep 400ms
Enter
Sleep 200ms

Type "export ANTHROPIC_BASE_URL=http://localhost:4000"
Sleep 300ms
Enter
Type 'export ANTHROPIC_AUTH_TOKEN="$LITELLM_MASTER_KEY"   # from tt-studio .env; never printed'
Sleep 300ms
Enter
Type "export ANTHROPIC_MODEL=Qwen3-32B"
Sleep 300ms
Enter
Type "export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1"
Sleep 300ms
Enter
Sleep 500ms

Type ""
Enter
Type "# 2) Prove the endpoint answers — a real request to Qwen3-32B on QB2:"
Sleep 400ms
Enter
Sleep 200ms

Type "curl -s http://localhost:4000/v1/chat/completions \"
Sleep 150ms
Enter
Type '  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \'
Sleep 150ms
Enter
Type '  -H "Content-Type: application/json" \'
Sleep 150ms
Enter
Type "  -d '{\"model\":\"Qwen3-32B\",\"messages\":[{\"role\":\"user\",\"content\":\"Write hello world in Python\"}]}' \"
Sleep 150ms
Enter
Type "  | python3 -c \"import sys,json; print(json.load(sys.stdin)['choices'][0]['message']['content'])\""
Sleep 300ms
Enter
# Give the model time to respond (first token can be a few seconds after idle).
Sleep 6s

Type ""
Enter
Type "# 3) Launch Claude Code — it's now backed by your QB2, no cloud API"
Sleep 400ms
Enter
Sleep 200ms

Type "claude"
Sleep 300ms
Enter
# Let Claude Code start and show it's talking to the local model.
# (If a trust/folder prompt appears, extend this Sleep or pre-accept before recording.)
Sleep 5s

# OPTIONAL money shot — uncomment to type a prompt and capture a live answer.
# Adjust the response Sleep to your model's latency.
# Type "Explain what a QB2 is in one sentence."
# Sleep 500ms
# Enter
# Sleep 10s

# Exit Claude Code cleanly.
Ctrl+C
Sleep 400ms
Ctrl+C
Sleep 1s
