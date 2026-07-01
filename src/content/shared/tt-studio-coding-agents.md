## Point Claude Code or OpenCode at your QB2

As of **tt-studio v2.8.0**, your QB2 can be the backend for a coding agent. Deploy a model, and tt-studio exposes it through a built-in [LiteLLM](https://github.com/BerriAI/litellm) gateway that speaks two protocols at once:

- an **Anthropic** surface (`http://<qb2-host>:4000`) that [Claude Code](https://docs.claude.com/en/docs/claude-code) talks to natively, and
- an **OpenAI-compatible** surface (`http://<qb2-host>:4000/v1`) for [OpenCode](https://opencode.ai/) and any other OpenAI client.

No cloud, no per-token bill — the agent runs against the model on your own four Blackhole chips.

**First, deploy an eligible model.** Coding agents need native tool-calling, so the gateway only exposes models that support it:

- `Qwen3-32B` (pre-cached on your QB2 — nothing to download)
- `Llama-3.1-8B-Instruct`
- `Llama-3.3-70B-Instruct`

Deploy one from tt-studio's **Deploy Model** dropdown, the same way you'd deploy any model.

**Then open the Coding Agents page** in tt-studio's left nav. It detects your deployed models and hands you copy-paste snippets with your host, gateway key, and model name already filled in — so the reliable path is to copy from that page. The blocks below show the shape of what you'll get.

### Claude Code

Export the gateway as Claude Code's endpoint, then launch `claude`:

```bash
export ANTHROPIC_BASE_URL=http://<qb2-host>:4000
export ANTHROPIC_AUTH_TOKEN=<gateway-key>       # tt-studio's LiteLLM master key
export ANTHROPIC_MODEL=Qwen3-32B
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
claude
```

`CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1` lets Claude Code's `/model` picker list whatever you have deployed. The gateway key is the `LITELLM_MASTER_KEY` that `run.py` generates for you — the Coding Agents page shows the live value.

### OpenCode

OpenCode reads a provider block from `~/.config/opencode/opencode.json`. The page generates a one-liner that merges a `tt-studio` provider into that file and launches OpenCode against your model; the provider it writes looks like this:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "tt-studio": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "TT-Studio",
      "options": {
        "baseURL": "http://<qb2-host>:4000/v1",
        "apiKey": "<gateway-key>"
      },
      "models": { "Qwen3-32B": { "name": "Qwen3-32B" } }
    }
  }
}
```

Then run it against the provider-qualified model name:

```bash
opencode --model tt-studio/Qwen3-32B
```

### Confirm the gateway is up

The OpenAI surface answers a plain curl, which is the fastest way to prove the endpoint before you point an agent at it:

```bash
curl http://<qb2-host>:4000/v1/chat/completions \
  -H "Authorization: Bearer <gateway-key>" \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen3-32B", "messages": [{"role": "user", "content": "Write hello world in Python"}]}'
```

:::callout type="tip"
**Thinking models stay quiet.** Qwen3-32B is a reasoning model, so the gateway also exposes a `Qwen3-32B-thinking` variant. For the plain name, v2.8.0 **hides the `<think>` tokens from the agent** — you get clean tool calls and answers instead of a wall of chain-of-thought. Pick the `-thinking` variant when you actually want to see the reasoning.
:::

:::callout type="warn"
The gateway listens on port **4000**. Working from your laptop over SSH? Forward it alongside the UI:

```bash
ssh -L 3000:localhost:3000 -L 4000:localhost:4000 user@qb2-hostname
```

Then `<qb2-host>` in the snippets above is just `localhost`. As with the inference server, the gateway trusts its key but has no other auth — keep it on your LAN or behind the tunnel, not on the public internet.
:::
