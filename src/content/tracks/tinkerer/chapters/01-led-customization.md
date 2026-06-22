---
title: LED Customization
currentChapter: 01-led-customization
permalink: /tinkerer/01-led-customization/
---
{% set persona = personas | findPersona(personaId) %}

# LED Customization

Four chips on your desk. Each one has indicators, tiny tells of internal state. By default they sit there doing their jobs in silence, lights blinking at whatever the firmware thinks is worth reporting. You can change that.

This chapter is about making the QB2 communicate on your terms, using `tt-smi` to query chip state and steer the indicators toward something more informative, more decorative, or more satisfying. The machine becomes a physical dashboard.

## tt-qb-lights: RGB That Responds to Your Hardware

If your QB2 is in a case with addressable RGB — or if you have a motherboard like the ASRock B850M-C with onboard RGB — there's a ready-made solution that does this properly: **[tt-qb-lights](https://github.com/tsingletaryTT/tt-qb-lights)**, a Rust systemd service built by Taylor Singletary specifically for Tenstorrent hardware.

Rather than calling `tt-smi` on a loop, it reads directly from `/sys/class/hwmon/blackhole-pci-*` — the same kernel interface `lm-sensors` uses — so it's low overhead and doesn't depend on any Tenstorrent CLI tools being in your PATH. It talks to [OpenRGB](https://gitlab.com/CalcProgrammer1/OpenRGB) over TCP (port 6742), so any RGB device OpenRGB supports becomes a live hardware dashboard.

**What it does:**

- Smooth color gradients driven by ASIC temperature — cool teal at idle, cycling through your chosen palette as the chips heat up
- Power-based brightness: dims to ~30% when idle, climbs to full brightness under load
- Warning pulse: lights pulse when temperature crosses a configurable threshold (default 70°C)
- Six built-in color schemes including *QuietBox Sunset* (inspired by the QB2 wallpaper), *TT Dark*, and *Tenstorrent Branding* (official teal → pink → gold → red)
- Live-editable config at `~/.config/tt-qb-lights/config.toml` — change schemes and restart, no rebuild needed

**Quick setup:**

```bash
# Clone and build
git clone https://github.com/tsingletaryTT/tt-qb-lights ~/code/tt-qb-lights
cd ~/code/tt-qb-lights

# Automated installer — checks prerequisites, builds, guides you through setup
./install.sh

# Or manually:
cargo build --release

# Test without touching your lights
./target/release/tt-qb-lights --single-shot   # prints sensor readings
./target/release/tt-qb-lights --dry-run --debug  # shows color decisions

# Initialize your config
./target/release/tt-qb-lights --init
# Then edit: nano ~/.config/tt-qb-lights/config.toml
```

Requires: Rust 1.70+, OpenRGB installed and running with its SDK server enabled, Tenstorrent drivers loaded (so `sensors | grep blackhole` shows devices).

:::callout type="tip"
`./install.sh` handles the full prerequisites check — Rust, OpenRGB, lm-sensors, build tools — and asks before installing anything. Use it on a fresh machine rather than running the steps manually.
:::

The service file handles startup ordering so OpenRGB starts before `tt-qb-lights`:

```bash
sudo systemctl enable openrgb
sudo systemctl enable tt-qb-lights
sudo systemctl start tt-qb-lights
journalctl -u tt-qb-lights -f   # watch it go
```

Full source, architecture notes, and troubleshooting: [github.com/tsingletaryTT/tt-qb-lights](https://github.com/tsingletaryTT/tt-qb-lights)

---

## Discover Your LED Options

`tt-smi` ships with a `--help` flag that reveals everything the current firmware supports. The LED interface can evolve across firmware versions, so this is the canonical starting point:

```bash
tt-smi --help | grep -i led
```

Run that first. Jot down the commands and flags it lists. Then explore the full help to understand flag ordering:

```bash
tt-smi --help
```

The general shape of LED commands is `tt-smi --set-led <device_id> <state>` or similar. Firmware determines the exact vocabulary. The pattern is consistent: device ID, action, optional parameter.

:::callout type="tip"
Run `tt-smi -s` to get a JSON snapshot of all chip state before you start scripting. This gives you the live field names you'll be parsing.
:::

## What tt-smi -s Gives You

Every 1-second pulse of `tt-smi -s` returns a JSON document with per-chip entries. The fields that matter for LED-driving logic:

- `temperature` — ASIC die temperature in Celsius
- `current` — current draw in amps
- `power` — power consumption in watts
- `voltage` — chip supply voltage
- `aiclk` — AI clock frequency (higher when actively computing)
- `arc_fw_version` — firmware version (important for knowing what LED commands are available)

A chip sitting idle has low `aiclk`. A chip running inference has elevated `aiclk` and rising `temperature`. Those two signals alone let you build a three-state indicator: idle, working, hot.

## A Monitoring Script

This script reads `tt-smi -s` every two seconds and calls LED commands based on chip temperature. Adjust the temperature thresholds and LED command syntax to match your firmware's actual interface (discovered via `tt-smi --help`):

```python
#!/usr/bin/env python3
"""
QB2 LED monitor — drives chip indicators from tt-smi telemetry.
Reads chip temperature every 2s and sets LED state accordingly.

Temperature thresholds:
  < 60°C  → steady green (idle / normal)
  60-80°C → pulsing amber (active inference)
  > 80°C  → rapid blink red (thermal throttle zone)

LED command syntax comes from: tt-smi --help | grep -i led
Adjust LED_CMD_* below to match your firmware's actual syntax.
"""

import subprocess
import json
import time
import sys

# ── LED command templates ─────────────────────────────────────────────────────
# Fill these in from `tt-smi --help` output on your system.
# Typical shapes: tt-smi --set-led <id> on/off  OR  tt-smi led <id> <state>
LED_CMD_COOL   = "tt-smi --set-led {device_id} on"       # steady
LED_CMD_ACTIVE = "tt-smi --set-led {device_id} blink"    # slow blink
LED_CMD_HOT    = "tt-smi --set-led {device_id} blink-fast"  # fast blink

TEMP_ACTIVE_THRESHOLD = 60.0   # °C — above this = chip is working
TEMP_HOT_THRESHOLD    = 80.0   # °C — above this = thermal warning
POLL_INTERVAL_SEC     = 2.0

def get_chip_state():
    """Return list of per-chip dicts from tt-smi -s JSON output."""
    result = subprocess.run(
        ["tt-smi", "-s"],
        capture_output=True, text=True, timeout=5
    )
    if result.returncode != 0:
        return []
    try:
        data = json.loads(result.stdout)
        # tt-smi -s returns a dict with a "device_info" list (or similar)
        # Field name may vary — inspect tt-smi -s output on your machine
        return data.get("device_info", data.get("devices", []))
    except (json.JSONDecodeError, AttributeError):
        return []

def set_led(device_id: int, mode: str):
    """Drive a chip LED. mode is one of: cool, active, hot."""
    cmd_template = {
        "cool":   LED_CMD_COOL,
        "active": LED_CMD_ACTIVE,
        "hot":    LED_CMD_HOT,
    }.get(mode, LED_CMD_COOL)
    cmd = cmd_template.format(device_id=device_id)
    subprocess.run(cmd.split(), capture_output=True)

def classify(chip: dict) -> str:
    """Decide LED mode from chip telemetry dict."""
    temp = float(chip.get("temperature", 0.0))
    if temp > TEMP_HOT_THRESHOLD:
        return "hot"
    if temp > TEMP_ACTIVE_THRESHOLD:
        return "active"
    return "cool"

def main():
    print("QB2 LED monitor starting. Ctrl-C to stop.")
    prev_modes = {}
    while True:
        chips = get_chip_state()
        if not chips:
            print("  [warn] No chip data from tt-smi — is the driver loaded?",
                  file=sys.stderr)
        for i, chip in enumerate(chips):
            mode = classify(chip)
            if prev_modes.get(i) != mode:
                set_led(i, mode)
                temp = chip.get("temperature", "?")
                print(f"  chip {i}: {mode} (temp={temp}°C)")
                prev_modes[i] = mode
        time.sleep(POLL_INTERVAL_SEC)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nStopped.")
```

Save this as `~/scripts/qb2-led-monitor.py` and mark it executable:

```bash
mkdir -p ~/scripts
chmod +x ~/scripts/qb2-led-monitor.py
```

Test it in your terminal while running a model in another session. You should see mode changes printed as the chips heat up.

## Running at Boot as a User Service

Once the script works manually, make it automatic. A systemd user service starts with your login and restarts if it crashes:

```bash
mkdir -p ~/.config/systemd/user
```

Create `~/.config/systemd/user/qb2-led-monitor.service`:

```ini
[Unit]
Description=QB2 LED Monitor
After=default.target

[Service]
ExecStart=/usr/bin/python3 /home/%i/scripts/qb2-led-monitor.py
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
```

Enable and start it:

```bash
# Enable lingering so user services survive logout
loginctl enable-linger $USER

# Reload systemd and start the service
systemctl --user daemon-reload
systemctl --user enable qb2-led-monitor.service
systemctl --user start qb2-led-monitor.service

# Check it's running
systemctl --user status qb2-led-monitor.service
journalctl --user -u qb2-led-monitor.service -f
```

The LEDs will now respond to chip state automatically, every time you log in.

{% tensixviz "blackhole", [
  {"step": "highlight", "cores": [[1,1],[2,1],[3,1],[4,1],[5,1],[6,1],[7,1],[9,1],[10,1],[11,1],[12,1],[13,1],[14,1],[15,1],[1,2],[2,2],[3,2],[4,2],[5,2],[6,2],[7,2],[9,2],[10,2],[11,2],[12,2],[13,2],[14,2],[15,2],[1,3],[2,3],[3,3],[4,3],[5,3],[6,3],[7,3],[9,3],[10,3],[11,3],[12,3],[13,3],[14,3],[15,3]], "color": "green", "label": "Cool cores — below 60°C, steady indicator", "ms": 700},
  {"step": "pause", "ms": 700},
  {"step": "highlight", "cores": [[1,4],[2,4],[3,4],[4,4],[5,4],[6,4],[7,4],[9,4],[10,4],[11,4],[12,4],[13,4],[14,4],[15,4],[1,5],[2,5],[3,5],[4,5],[5,5],[6,5],[7,5],[9,5],[10,5],[11,5],[12,5],[13,5],[14,5],[15,5],[1,6],[2,6],[3,6],[4,6],[5,6],[6,6],[7,6],[9,6],[10,6],[11,6],[12,6],[13,6],[14,6],[15,6]], "color": "gold", "label": "Active cores — 60-80°C, slow pulse", "ms": 700},
  {"step": "pause", "ms": 700},
  {"step": "highlight", "cores": [[1,7],[2,7],[3,7],[4,7],[5,7],[6,7],[7,7],[9,7],[10,7],[11,7],[12,7],[13,7],[14,7],[15,7],[1,8],[2,8],[3,8],[4,8],[5,8],[6,8],[7,8],[9,8],[10,8],[11,8],[12,8],[13,8],[14,8],[15,8]], "color": "pink", "label": "Warm cores — above 80°C, rapid blink warning", "ms": 700},
  {"step": "pause", "ms": 1000},
  {"step": "clear"}
] %}

<p class="illustrated-only" style="font-size:12px;color:var(--muted);text-align:center;margin-top:-8px;">Heat map across one Blackhole chip. Your LED script mirrors this in physical hardware.</p>

:::callout type="tip"
The `classify()` function in the script is the right place to add more nuance — voltage spike detection, fan speed crossings, or any other field from `tt-smi -s`. The monitor loop doesn't care what you feed it.
:::

<figure class="video-demo">
<img src="/assets/video/10-led-telemetry-demo.gif" alt="tt-smi -s showing per-chip temperature, power, clock, and firmware version on a QB2" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">The telemetry fields your LED script reads — temperature, power, aiclk, firmware version per chip</figcaption>
</figure>

---

**Next:** [Fun Demos →](/tinkerer/02-fun-demos/)
