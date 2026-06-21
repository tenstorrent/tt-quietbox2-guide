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

<!-- VIDEO: VHS recording of tt-smi -s on a live QB2, all four chips visible, JSON formatted. Script: scripts/vhs/03-tt-smi-demo.tape -->
