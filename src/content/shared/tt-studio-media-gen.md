## Beyond text: video and image generation

The QB2 isn't only a text box. **tt-studio v2.8.0** adds two generative-media families to the same deploy-and-run flow:

- **WAN** — text-to-video. Describe a scene, get a short generated clip.
- **Flux** — text-to-image. A high-quality diffusion image generator.

They deploy exactly like the language models: open tt-studio at `localhost:3000`, pick the model from the **Deploy Model** dropdown, and click Run. tt-studio spins up the right container on your Blackhole chips and gives you a prompt box — no pipeline code, no separate install.

:::callout type="tip"
**Which UI for media?** tt-studio now handles video and image generation in the browser. [tt-local-generator](https://docs.tenstorrent.com/tt-local-generator) is the GTK4 desktop app for the same job — both sit on top of tt-inference-server, so pick whichever fits how you like to work. For a guided walkthrough of video specifically, see the [QB2 Video Generation lesson](https://docs.tenstorrent.com/tt-vscode-toolkit/lessons/qb2-video-generation/).
:::

These are heavier than an 8B chat model — a text-to-video diffusion run leans on more of the board than a single-chip LLM. If a deploy is slow to go green the first time, that's compilation and weight loading; subsequent runs load from the on-disk cache.
