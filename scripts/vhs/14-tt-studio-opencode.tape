# VHS tape — tt-studio v2.8.0: OpenCode against a local model on your QB2
# Record ON the QB2 with: vhs scripts/vhs/14-tt-studio-opencode.tape
#
# PREREQUISITES (same as the Claude Code tape, 13-...):
#   1. tt-studio running with an eligible model DEPLOYED (Qwen3-32B).
#   2. LiteLLM gateway healthy on :4000.
#   3. Export the gateway key without printing it, so it never lands in the GIF:
#        export LITELLM_MASTER_KEY=$(grep -E '^LITELLM_MASTER_KEY=' ~/tt-studio/.env | cut -d= -f2-)
#   4. `opencode` installed and on PATH.
#
# NOTE: OpenCode has no model discovery, so its config must list the model
# explicitly. The snippet below merges a `tt-studio` provider into
# ~/.config/opencode/opencode.json (creating it if absent), then launches
# OpenCode against the provider-qualified model name.

Output src/assets/video/14-tt-studio-opencode.gif

Set Shell "bash"
Set FontSize 13
Set Width 1100
Set Height 660
Set Theme "Catppuccin Mocha"

Type "# tt-studio v2.8.0 — run OpenCode against a model on your OWN chips"
Sleep 500ms
Enter
Sleep 300ms

Type "# 1) Register tt-studio as an OpenCode provider (OpenAI surface on :4000/v1)"
Sleep 400ms
Enter
Sleep 200ms

Type "python3 - <<'PY'"
Sleep 150ms
Enter
Type "import json, os, pathlib"
Sleep 100ms
Enter
Type "p = pathlib.Path.home() / '.config/opencode/opencode.json'"
Sleep 100ms
Enter
Type "cfg = json.loads(p.read_text()) if p.exists() else {}"
Sleep 100ms
Enter
Type "cfg.setdefault('provider', {})['tt-studio'] = {"
Sleep 100ms
Enter
Type "    'npm': '@ai-sdk/openai-compatible', 'name': 'TT-Studio',"
Sleep 100ms
Enter
Type "    'options': {'baseURL': 'http://localhost:4000/v1', 'apiKey': os.environ['LITELLM_MASTER_KEY']},"
Sleep 100ms
Enter
Type "    'models': {'Qwen3-32B': {'name': 'Qwen3-32B'}},"
Sleep 100ms
Enter
Type "}"
Sleep 100ms
Enter
Type "p.parent.mkdir(parents=True, exist_ok=True); p.write_text(json.dumps(cfg, indent=2) + '\\n')"
Sleep 100ms
Enter
Type "print(f'Updated {p}')"
Sleep 100ms
Enter
Type "PY"
Sleep 300ms
Enter
Sleep 1500ms

Type ""
Enter
Type "# 2) Launch OpenCode against your QB2-hosted model"
Sleep 400ms
Enter
Sleep 200ms

Type "opencode --model tt-studio/Qwen3-32B"
Sleep 300ms
Enter
# Let OpenCode start and show the tt-studio provider / model is selected.
Sleep 5s

# OPTIONAL money shot — uncomment to type a prompt and capture a live answer.
# Type "Write a Python function that reverses a string."
# Sleep 500ms
# Enter
# Sleep 10s

# Exit OpenCode cleanly (adjust if your build uses a different quit key).
Ctrl+C
Sleep 400ms
Ctrl+C
Sleep 1s
