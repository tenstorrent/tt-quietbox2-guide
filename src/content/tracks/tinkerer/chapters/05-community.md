---
title: Community & Contribution
currentChapter: 05-community
permalink: /tinkerer/05-community/
---
{% set persona = personas | findPersona(personaId) %}

# Community & Contribution

The hardware is interesting alone. It becomes more interesting when someone else's kernel runs on it, or when your demo helps someone else understand what's possible.

This chapter is about where to find those people and how to add to what they're building.

## tt-awesome

The community catalog lives at [tenstorrent.github.io/tt-awesome](https://tenstorrent.github.io/tt-awesome/). Models, demos, integrations, experiments — contributed by people who picked up the same hardware you have and built something worth sharing. Browse it before building. Someone may have already done the hard part, and their version might be better than yours would be.

Adding a project is a pull request to [github.com/tenstorrent/tt-awesome](https://github.com/tenstorrent/tt-awesome). The bar is low: working code, a README, and a description that tells someone why they'd want to run it.

## GitHub

All of Tenstorrent's core repositories are public: [github.com/tenstorrent](https://github.com/tenstorrent).

Useful starting points:

- **tt-metal** — the core compute stack; file bugs for driver issues, TTNN problems, compilation failures
- **tt-smi** — hardware monitoring; file bugs for incorrect readings, missing devices, command errors
- **tt-toplike** — the TUI visualizer; file bugs for crashes, rendering issues, wrong telemetry
- **tt-animatediff** — community-ready video generation library: [github.com/tenstorrent/tt-animatediff](https://github.com/tenstorrent/tt-animatediff), v0.1.0

When filing a bug, include `tt-smi -s` output and your Ubuntu/kernel versions. A reproducer is worth ten paragraphs of description.

## Discord

The Tenstorrent Discord is the fastest path to a human answer. Find the link at [tenstorrent.com/community](https://tenstorrent.com/community). The community includes Tenstorrent engineers, researchers running production workloads, and people who are a week into their first QB2, exactly where you were recently.

The channels worth knowing: `#hardware-support` for driver and chip questions, `#tt-metal` for software stack questions, `#show-and-tell` for demos. Show your tt-toplike screenshots there. People appreciate them.

## Contribution Ideas

**Add a demo to tt-awesome.** If you've got something running on your QB2 that took more than an hour to figure out, it's worth sharing. A Jupyter notebook demonstrating a novel TTNN op, a generative art setup using tt-local-generator, a custom LED monitoring script — these are all valid contributions.

**Share a VHS recording.** A terminal recording of your demo is worth more than a static screenshot. [VHS](https://github.com/charmbracelet/vhs) renders `.tape` files into `.gif` or `.mp4`. Record your tt-toplike flow mode demo, your first 70B query, your LED script responding to thermal changes. Share to Discord or embed in a tt-awesome entry.

**Write a lesson.** The [tt-vscode-toolkit lessons](https://docs.tenstorrent.com/tt-vscode-toolkit/) are written by people who built things and wanted to teach them. If you've worked through a non-trivial workflow on QB2, the lesson format is a good home for it.

**File a bug.** When something breaks and you fix it, the issue report benefits the next person. Document the exact error message, the kernel version, the fix. The [break-and-fix patterns](/tinkerer/04-break-and-fix/) in this guide grew from exactly that kind of contribution.

:::callout type="tip"
The most useful bug reports include a `tt-smi -s` JSON snapshot, the full error output, and the exact sequence of commands that triggered the issue. Reproducers matter more than explanations.
:::

## Where to Go from Here

You've tinkered. You've broken things and fixed them. You've shown demos that stopped people mid-conversation. The next layer is in the Builder/Hacker track, where the interesting question shifts from "what can this machine do?" to "what can I build on it?"

<div style="display:flex;gap:16px;flex-wrap:wrap;margin-top:2em;">
  <a href="/first-timer/" style="flex:1;min-width:200px;padding:16px;background:var(--bg1);border-radius:8px;text-decoration:none;border-left:3px solid var(--teal);">
    <div style="font-size:10px;letter-spacing:1.5px;text-transform:uppercase;color:var(--muted);margin-bottom:6px;">Review</div>
    <div style="color:var(--teal);font-weight:700;">First Timer Track</div>
    <div style="font-size:12px;color:var(--text2);margin-top:4px;">Revisit the fundamentals with fresh eyes.</div>
  </a>
  <a href="/builder-hacker/" style="flex:1;min-width:200px;padding:16px;background:var(--bg1);border-radius:8px;text-decoration:none;border-left:3px solid var(--pink);">
    <div style="font-size:10px;letter-spacing:1.5px;text-transform:uppercase;color:var(--muted);margin-bottom:6px;">Go Deeper</div>
    <div style="color:var(--pink);font-weight:700;">Builder/Hacker Track</div>
    <div style="font-size:12px;color:var(--text2);margin-top:4px;">Custom kernels, inference pipelines, production deployments.</div>
  </a>
</div>

---

The QB2 becomes more interesting the more people are working on it together. The hardware is the same machine in every office. The software, the experiments, the failures-turned-blog-posts, the demos running on Discord at midnight — those are what actually make a platform. You're part of that now. Build something.
