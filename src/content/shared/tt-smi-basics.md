## Reading Your Hardware with tt-smi

`tt-smi` is the Tenstorrent System Management Interface. Your window into the chips. Run it in snapshot mode to get JSON instead of the interactive TUI:

```bash
tt-smi -s
```

A healthy QB2 returns four entries — one per Blackhole chip:

```json
{
  "device_info": [
    {
      "board_type": "BLACKHOLE",
      "board_id": "AA-BHXY-0001",
      "pcie_speed": "GEN4",
      "pcie_width": "x16",
      "temperature": { "asic": 44.1, "inlet": 31.0 },
      "voltage": { "core": 0.85 },
      "power": { "total": 42.0 }
    }
  ]
}
```

Four entries in `device_info` means four chips, all alive. Check it directly:

```bash
tt-smi -s | python3 -m json.tool | grep board_type
```

You should see `"BLACKHOLE"` printed four times.

<div class="callout callout--tip">
<span class="callout-icon illustrated-only">🌡️</span>
Idle temperatures of 35–55°C are normal. Under full inference load, Blackhole chips run 70–85°C. The QB2 cooling system is sized for this. Hot chips doing real work is a good sign.
</div>

<figure class="video-demo">
<img src="/assets/video/03-tt-smi-demo.gif" alt="tt-smi -s showing four Blackhole P300c chips on a QB2" loading="lazy" style="width:100%;border-radius:var(--radius);border:1px solid var(--bg2);">
<figcaption style="font-size:12px;color:var(--muted);text-align:center;margin-top:6px;">tt-smi -s on a live QB2 — four P300c chips, JSON snapshot mode</figcaption>
</figure>
