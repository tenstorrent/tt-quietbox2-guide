# VHS tape — tt-studio v2.8.0: OpenCode against a local model on your QB2
# Record ON the QB2 with: vhs scripts/vhs/14-tt-studio-opencode.tape
#
# PREREQUISITES (same as the Claude Code tape, 13-...):
#   1. tt-studio running with an eligible model DEPLOYED (Qwen3-32B).
#   2. LiteLLM gateway healthy on :4000.
#   3. Export the gateway key without printing it, so it never lands in the GIF:
#        export LITELLM_MASTER_KEY=$(grep -E '^LITELLM_MASTER_KEY=' ~/.local/lib/tt-studio/.env | cut -d= -f2-)
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
Set TypingSpeed 15ms

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
Type "p.parent.mkdir(parents=True, exist_ok=True); p.write_text(json.dumps(cfg, indent=2))"
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
Type "# 2) Ask it something. Bare 'opencode' opens the full TUI;"
Sleep 300ms
Enter
Type "#    'opencode run' is one-shot — great for a quick demo (and for GIFs:"
Sleep 300ms
Enter
Type "#    the TUI uses the alternate screen, which most recorders can't capture)."
Sleep 400ms
Enter
Sleep 200ms

Type "# Run in a scratch dir so OpenCode doesn't index a big project (much faster):"
Sleep 300ms
Enter
Type "mkdir -p /tmp/oc-demo && cd /tmp/oc-demo"
Sleep 300ms
Enter
Sleep 500ms

# "Perl poetry" is the classic art of real, runnable Perl that reads as verse
# (see perlmonks.org/?node_id=1111395) — so the prompt asks for valid Perl, not prose.
Type `opencode run -m tt-studio/Qwen3-32B 'Write "Perl poetry" the classic way — a few lines of real, syntactically valid Perl (use strict optional) that runs yet reads as a poem — about a CGI script that dreamed of becoming an LLM. Output only the Perl, in one short code block.'`
Sleep 500ms
Enter
# opencode shows a "build" spinner while Qwen3-32B works, then prints the poem
# to stdout. Give it room to finish (a few lines take ~10-20s incl. startup).
Sleep 26s
