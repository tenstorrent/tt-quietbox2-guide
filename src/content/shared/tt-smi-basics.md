## Reading Your Hardware with tt-smi

`tt-smi` is the Tenstorrent System Management Interface. Your window into the chips. Run it in snapshot mode to get JSON instead of the interactive TUI:

```bash
tt-smi -s
```

A healthy QB2 returns four entries — one per Blackhole chip. The real shape is nested, not flat — `board_info` and `telemetry` are their own sub-objects:

```json
{
  "device_info": [
    {
      "board_info": {
        "bus_id": "0000:01:00.0",
        "board_type": "p300c",
        "board_id": "0000046131924062",
        "dram_status": true,
        "pcie_speed": 4,
        "pcie_width": "4"
      },
      "telemetry": {
        "voltage": "0.72",
        "current": "23.0",
        "power": "16.0",
        "aiclk": "800",
        "asic_temperature": "40.3"
      },
      "firmwares": {
        "fw_bundle_version": "19.13.1.0"
      }
    }
  ]
}
```

`board_type` is the board SKU (`p300c` on a QB2), not a chip-family string — Blackhole doesn't appear literally anywhere in the output. Four entries in `device_info` means four chips, all alive. Check it directly:

```bash
tt-smi -s | python3 -m json.tool | grep board_type
```

You should see `"p300c"` printed four times.

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">🌡️</span>
Idle temperatures of 35–55°C are normal. Under full inference load, Blackhole chips run 70–85°C. The QB2 cooling system is sized for this. Hot chips doing real work is a good sign.
</div>

<figure class="video-demo">
<img src="/assets/video/03-tt-smi-demo.gif" alt="tt-smi -s showing four Blackhole chips on a QB2" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">tt-smi -s on a live QB2 — four Blackhole chips, JSON snapshot mode</figcaption>
</figure>
