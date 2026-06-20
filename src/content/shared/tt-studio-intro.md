## tt-studio

[tt-studio](https://github.com/tenstorrent/tt-studio) is a web UI for running models on Tenstorrent hardware without writing code. It handles model downloading, container management, and inference in a browser interface.

To start tt-studio:

```bash
tt-studio
```

Open `http://localhost:7860` in your browser. Select a model, click Run, and wait. The first run downloads the model weights — subsequent runs are fast.

For a list of supported models, visit the [tt-awesome model catalog](https://tenstorrent.github.io/tt-awesome/).
