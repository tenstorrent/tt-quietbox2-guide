## tt-studio

[tt-studio](https://github.com/tenstorrent/tt-studio) is a web interface for running models on QB2 without writing a line of code. It handles model selection, container lifecycle, and inference end-to-end — open a browser, pick a model, get tokens back. It's the **lowest-effort path to your first token on a QB2.**

Start it with the pre-installed wrapper command:

```bash
tt-studio
```

Then open `http://localhost:3000` in your browser, pick a model from the Deploy Model dropdown, and click Run. **On a QB2, Qwen3-32B is already there with its weights pre-cached** — its first deploy skips the multi-GB download and is ready in a few minutes. Other models download on first use; after that, every run loads fast from the on-disk cache. (tt-studio v2.8.0 also fixed the cold first-chat delay after an idle model, so that first token comes back quickly.)

<div class="callout callout--info">
<span class="callout-icon illustrated-only">ℹ</span>
<strong>What the wrapper does:</strong> <code>tt-studio</code> is a convenience command the QB2 ships. Under the hood it launches the same stack you'd get by cloning the repo and running <code>python3 run.py</code> — that sets up the submodule and <code>.env</code>, prompts for your Hugging Face token, selects the right Docker overlays for your hardware, and brings up the Django + React app plus the model containers, then serves the UI at <code>localhost:3000</code>. On any other machine, that clone-and-<code>run.py</code> flow is how you'd start it.
</div>

**What's happening under the hood:** tt-studio is a UI sitting on top of [tt-inference-server](https://github.com/tenstorrent/tt-inference-server). When you select a model and click Run, tt-studio spins up a Docker container running the TT fork of vLLM on port 8000. Your browser talks to tt-studio; tt-studio talks to that container. [tt-local-generator](https://docs.tenstorrent.com/tt-local-generator) routes through the same container — both are UIs sitting on top of tt-inference-server, just with different front ends.

To access tt-studio from your laptop while the QB2 is on your network, forward the port over SSH:

```bash
ssh -L 3000:localhost:3000 user@qb2-hostname
```

Then open `http://localhost:3000` on your local machine as if you were sitting in front of the QB2.

For a deeper look at how the inference server is wired up, the [tt-vscode-toolkit lesson on tt-inference-server](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-inference-server/) walks through the architecture interactively — Docker flags, model download, port mapping, and what logs to watch on first boot.

<div class="callout callout--info">
<span class="callout-icon illustrated-only">ℹ</span>
<strong>Two UIs, one server:</strong> tt-studio and tt-local-generator are both front ends for tt-inference-server. You can switch between them freely — they talk to the same running container on port 8000.
</div>

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">🤖</span>
<strong>New in v2.8.0 — your QB2 as a coding backend:</strong> tt-studio can now serve a deployed model to <strong>Claude Code and OpenCode</strong> through a built-in gateway, so a coding agent runs against your own chips instead of a cloud API. It also added text-to-video (WAN) and image (Flux) generation. See <a href="/ml-practitioner/03-vllm-on-qb2/">Serving Models on QB2</a> for the coding-agent setup.
</div>

<figure class="video-demo">
<img src="/assets/video/12-tt-studio-demo.gif" alt="tt-studio on PATH, startup command, SSH port-forward instructions, --help output" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">tt-studio is a single command — starts a web UI at localhost:3000, accessible via SSH tunnel from your laptop</figcaption>
</figure>
