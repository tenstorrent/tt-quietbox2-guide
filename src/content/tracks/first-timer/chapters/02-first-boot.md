---
title: First Boot
currentChapter: 02-first-boot
permalink: /first-timer/02-first-boot/
---
{% set persona = personas | findPersona(personaId) %}

# First Boot

Power on. Ubuntu loads. A login screen appears.

The default credentials depend on how your QB2 was provisioned — check the card that came in the box, or contact your admin. Once you're in, open a terminal. Everything from here happens in a terminal.

## Finding a Terminal

If you're looking at the GNOME desktop:

- Press `Ctrl+Alt+T` — this usually opens a terminal
- Or right-click the desktop and choose "Open Terminal"
- Or press the Super key, type "terminal", press Enter

Once a terminal is open, you're in the right place.

## First Things First

Check that you're connected to the internet:

```bash
ping -c 3 google.com
```

If that fails, check your network cable or Wi-Fi settings via `Settings → Network`.

Update the system package list — do this once after first boot:

```bash
sudo apt update
```

You'll be prompted for your password. This doesn't install anything, just refreshes the list of available updates.

## A Note on Ubuntu 24.04

The QB2 ships with Ubuntu 24.04 LTS (Long Term Support). If this is your first time with Ubuntu:

- The package manager is `apt` — you install things with `sudo apt install <name>`
- Files are case-sensitive: `Model.py` and `model.py` are different files
- Your home directory is `~` (short for `/home/yourusername`)
- `sudo` runs commands as administrator — use it only when asked

You don't need to know much more than that to follow this guide.

<div class="video-placeholder illustrated-only">
  <strong>Coming soon: First boot walkthrough</strong>
  Terminal basics, finding your home directory, checking internet.
  <!-- VIDEO: VHS recording of first boot sequence: login, terminal open, ping test, apt update. Script: scripts/vhs/02-first-boot-demo.tape -->
</div>

---

**Next:** [Is This Thing On? →](/first-timer/03-is-this-thing-on/)
