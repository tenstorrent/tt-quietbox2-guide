---
title: Launch Software
currentChapter: 06-launch-software
permalink: /first-timer/06-launch-software/
---
{% set persona = personas | findPersona(personaId) %}

# Launch Software

An API endpoint is the foundation. `tt launch` connects a ready-made application to the model
you are already serving, so you can use it without copying a URL into a settings page. You do
not tell the app where the model is: `tt` asks every server it started what it serves
(`GET /v1/models`) and configures the client from the answer.

Keep the model from the last chapter running, and see what you can connect:

```bash
tt launch list
```

```
┏━━━━━━━━━━━━━┳━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ client      ┃ kind        ┃ model          ┃ status         ┃ configures                           ┃
┡━━━━━━━━━━━━━╇━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━╇━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┩
│ opencode    │ terminal    │ tool calling   │ needs opencode │ ~/.config/opencode/opencode.json     │
│ pi          │ terminal    │ tool calling   │ needs pi       │ ~/.pi/agent/models.json              │
│ aider       │ terminal    │ tool calling   │ needs aider    │ environment (this run only)          │
│ qwencode    │ terminal    │ tool calling   │ ready          │ command-line arguments (this run…)   │
│ hermes      │ terminal    │ tool calling   │ ready          │ environment (this run only)          │
│ openwebui   │ web service │ any chat model │ stopped        │ container tt-open-webui              │
│ anythingllm │ web service │ any chat model │ ready          │ container tt-anythingllm             │
└─────────────┴─────────────┴────────────────┴────────────────┴──────────────────────────────────────┘
```

There are two kinds of client, and the difference is who installs them:

* **Web UIs** (Open WebUI, AnythingLLM). `tt` pulls and runs these in a container for you, after
  asking once. You only need Docker.
* **Terminal coding agents** (OpenCode, pi, Aider, Qwen Code, Hermes Agent). You install the
  agent. `tt launch` writes the small config it needs to reach your model and hands your terminal
  to it. These need a model that supports **tool calling**; `tt` checks, and stops with a
  suggestion if the model cannot.

The `status` column says what is missing: `needs opencode` means the agent is not installed,
`ready` means it can launch now, and `stopped` is a web UI container that exists and is not
running.

## A Chat Window in Your Browser

```bash
tt launch openwebui --dry-run     # show what would happen, change nothing
tt launch openwebui
```

The dry run prints what `tt` found and what it will do:

```
┌───────────────────────┬───────────────────────────────────────────────────────────┐
│ model                 │ meta-llama/Llama-3.1-8B-Instruct  (Llama-3.1-8B-Instruct) │
│ endpoint              │ http://127.0.0.1:20000/v1                                 │
│ tool-call parser      │ llama3_json                                               │
│ container             │ tt-open-webui (stopped)                                   │
│ image                 │ ghcr.io/open-webui/open-webui:main                        │
│ endpoint in container │ http://host.docker.internal:20000/v1                      │
│ open                  │ http://localhost:3000                                     │
└───────────────────────┴───────────────────────────────────────────────────────────┘
```

The first time, `tt` asks before it pulls the image (a few GB) and runs it as `tt-open-webui`.
It waits until the page answers and prints `tt-open-webui is ready at http://localhost:3000`.
Open that address in a browser. The container is configured with your endpoint
(`OPENAI_API_BASE_URL=http://host.docker.internal:20000/v1`), so its model list comes from your server.

If two models are being served, say which one: `tt launch openwebui --model Qwen3-32B`.
Web UIs start on port 3000, or the next free port above it; `--web-port 3080` asks for another.
When you are done:

```bash
tt launch stop openwebui      # stops the container, keeps your chats and settings
```

:::callout type="warn"
**Open WebUI starts with sign-in turned off** (`WEBUI_AUTH=False`), and anyone who can reach
port 3000 can read your chats and use the model. To chat from a laptop, tunnel the port and
keep it private:
`ssh -L 3000:localhost:3000 <you>@<your-QB2-address>`, then browse to `http://localhost:3000`.
A tunnel does not close the port on the QB2 itself, so use this only on a network you trust
or behind a firewall.
:::

## A Coding Agent in Your Terminal

Terminal agents work on your files, so they need a model that can call tools. Qwen3-32B can, with
one caveat:

:::callout type="warn"
**Qwen3-32B thinks first, and that can drop tool calls.** With thinking on, a reasoning model
sometimes ends a turn without making the tool call the agent asked for. In a test on the cloud
Qwen3-32B deployment, 8 of 20 runs did this (tt-inference-server issue
[#4386](https://github.com/tenstorrent/tt-inference-server/issues/4386), still open when we
checked). We have not verified how `tt launch` clients behave against a local Qwen3-32B. If an
agent stalls or answers without acting, send `chat_template_kwargs: {"enable_thinking": false}`
with the request if your client lets you add request fields, or serve a model without a
reasoning mode, such as `Llama-3.1-8B-Instruct`.
:::
**Faster agent models come from the community catalog.** The fastest tool-calling models
on a QB2 are mixture-of-experts coders with 3B parameters active per token, published as
community bundles: `raahemnabeel/qwen3-coder-30b-a3b` and `raahemnabeel/qwen3-coder-next`,
both with the `qwen3_coder` tool parser and no thinking mode. Measured on 2026-10-30 on one
P300 board: 80 tok/s and 107 tok/s on a real prompt, against about 8 seconds a response for
Qwen3-32B. Serve one with `tt serve raahemnabeel/qwen3-coder-30b-a3b --profile p300x2` (see
[The Model Zoo](/ml-practitioner/02-model-zoo/) for the warning that applies to every bundle).
`tt launch` finds it the same way. It prints `not in the model catalog` and shows
`tool-call parser —` because it has no catalog row to check; the bundle's card and
`tt serve <bundle> --dry-run` show the parser is set. We ran `tt launch qwencode --dry-run`
and a smolagents task against Qwen3-Coder-Next this way; the task was answered in one 2 s step.

Install one agent, then launch it. Qwen Code and Hermes Agent were `ready` in the listing above:

```bash
tt launch qwencode --dry-run
```

```
┌──────────────────┬───────────────────────────────────────────────────────────┐
│ model            │ meta-llama/Llama-3.1-8B-Instruct  (Llama-3.1-8B-Instruct) │
│ endpoint         │ http://127.0.0.1:20000/v1                                 │
│ tool-call parser │ llama3_json                                               │
└──────────────────┴───────────────────────────────────────────────────────────┘

commands:
qwen --auth-type openai --openai-api-key tt-local --openai-base-url http://127.0.0.1:20000/v1 --model meta-llama/Llama-3.1-8B-Instruct
```

The dry run shows the exact command `tt launch` runs: your agent, pointed at your endpoint, with
no cloud account. Run it without `--dry-run` to start the agent.

| Client | Install it first | What `tt launch` writes |
|---|---|---|
| `opencode` | [opencode.ai/docs](https://opencode.ai/docs/) | A `tenstorrent` provider in `~/.config/opencode/opencode.json` |
| `pi` | [github.com/earendil-works/pi](https://github.com/earendil-works/pi) | A `tenstorrent` provider in `~/.pi/agent/models.json` |
| `aider` | [aider.chat/docs/install](https://aider.chat/docs/install.html) | Nothing on disk (environment variables, this run only) |
| `qwencode` | Node.js 22+, then `npm install -g @qwen-code/qwen-code` | Nothing on disk (command-line arguments) |
| `hermes` | [hermes-agent.nousresearch.com/docs](https://hermes-agent.nousresearch.com/docs/) | Nothing on disk (environment). `--web` opens its browser dashboard |

`tt` shows what it will change and asks before writing a config file. `tt launch disconnect
opencode` removes what it wrote.

### Claude Code with Tenstorrent skills

The development version of `tt` (after release 1.2.1) adds `tt agent`, which sets up Claude Code
with the plugins from the [tenstorrent/skills](https://github.com/tenstorrent/skills)
marketplace for what you are doing today (`deploy`, `bringup` or `develop`) and starts it.
Preview with `tt agent deploy --dry-run`. Check `tt --help` for an `agent` entry to see whether
your release has it.

## Prefer Point and Click? TT-Studio

[TT-Studio](https://github.com/tenstorrent/tt-studio) serves the model and provides its own web
interface. You start it with `tt serve --studio`, not `tt launch`:

```bash
tt model stop Qwen3-32B        # TT-Studio takes the chips and port 3000 for itself
tt serve Qwen3-32B --studio
```

On first use `tt` fetches the latest TT-Studio release, and TT-Studio asks you to accept its
terms. It prints a `TT Studio is ready` box with its address, `http://localhost:3000`. Stopping
the model with `tt model stop Qwen3-32B` also takes TT-Studio's services down and keeps your
settings and chat history. Start TT-Studio *before* any `tt launch` web UI, since both want port
3000 and only the web UIs move when it is taken.

## Check Your Work

```bash
tt model ps               # your model is healthy
tt launch list            # your chosen client is ready or connected
tt launch stop openwebui  # clean up the web UI when you are done
tt model stop Qwen3-32B   # and the model
```

---

**Next:** [What Comes Next →](/first-timer/07-what-comes-next/)
