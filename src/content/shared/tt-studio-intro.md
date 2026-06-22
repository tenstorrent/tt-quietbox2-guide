## tt-studio

[tt-studio](https://github.com/tenstorrent/tt-studio) is a web interface for running models on QB2 without writing a line of code. It handles model selection, container lifecycle, and inference end-to-end — open a browser, pick a model, get tokens back.

Start it with a single command on the QB2:

```bash
tt-studio
```

Then open `http://localhost:7860` in your browser. Select a model from the library, adjust parameters if you want, and click Run. The first launch for any model compiles weights for Blackhole — that takes a few minutes. Subsequent runs skip compilation and load fast from the on-disk cache.

**What's happening under the hood:** tt-studio is a UI sitting on top of [tt-inference-server](https://github.com/tenstorrent/tt-inference-server). When you select a model and click Run, tt-studio spins up a Docker container running the TT fork of vLLM on port 8000. Your browser talks to tt-studio; tt-studio talks to that container. [tt-local-generator](https://docs.tenstorrent.com/tt-local-generator) routes through the same container — both are UIs sitting on top of tt-inference-server, just with different front ends.

To access tt-studio from your laptop while the QB2 is on your network, forward the port over SSH:

```bash
ssh -L 7860:localhost:7860 user@qb2-hostname
```

Then open `http://localhost:7860` on your local machine as if you were sitting in front of the QB2.

For a deeper look at how the inference server is wired up, the [tt-vscode-toolkit lesson on tt-inference-server](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/tt-inference-server/) walks through the architecture interactively — Docker flags, model download, port mapping, and what logs to watch on first boot.

<div class="callout callout--info">
<span class="callout-icon illustrated-only">ℹ</span>
<strong>Two UIs, one server:</strong> tt-studio and tt-local-generator are both front ends for tt-inference-server. You can switch between them freely — they talk to the same running container on port 8000.
</div>

<figure class="video-demo">
<img src="/assets/video/12-tt-studio-demo.gif" alt="tt-studio on PATH, startup command, SSH port-forward instructions, --help output" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">tt-studio is a single command — starts a web UI at localhost:7860, accessible via SSH tunnel from your laptop</figcaption>
</figure>
