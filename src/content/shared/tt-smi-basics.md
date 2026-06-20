## Reading Your Hardware with tt-smi

`tt-smi` is the Tenstorrent System Management Interface — your window into what the hardware is actually doing. Run it in snapshot mode to get clean JSON output:

```bash
tt-smi -s
```

You'll see something like:

```json
{
  "device_info": [
    { "board_type": "BLACKHOLE", "pcie_speed": "GEN4", "temperature": { "asic": 45.2 } }
  ]
}
```

Four entries means four chips, all alive. If you see fewer, check `dmesg | grep tenstorrent` for PCIe errors.

<!-- VIDEO: VHS recording of tt-smi -s output on a live QB2, with all four chips visible. Script: scripts/vhs/03-tt-smi-demo.tape -->
