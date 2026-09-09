# VHS tape - first TTNN kernel: elementwise add on Blackhole
# Record with: vhs demo/raw/11-first-kernel-demo.tape
#
# Recorded inside tenstorrent/qb2-env:latest with hardware passed through (see
# 04-tt-installer-demo.tape's note). The script matches
# builder-hacker/02-first-kernel.md exactly. torch is bootstrapped into the
# container's /opt/venv in a hidden step first - confirmed live this session
# that the real tt-metalium container ships no torch and no pip (only
# uv/ensurepip); showing that ~2-minute install would make for a bad demo, so
# it's pre-warmed here the same way the guide's own "write it yourself" framing
# treats one-time setup versus the payoff.
#
# IMPORTANT: the script calls ttnn.open_device(), which exclusively locks the
# chip at the driver level. Passing the whole /dev/tenstorrent directory lets
# it collide with any OTHER lease-holder's chip 0 and crash with a UMD/driver
# stack trace. Pass only your gozer-leased device nodes explicitly (map
# leased PCI bus IDs to /dev/tenstorrent/N via `tt-smi -s`'s device order,
# which matches by-index) -- update the --device flags below to match
# whatever chips you actually hold before recording.

Output demo/assets/11-first-kernel-demo.gif

Set Shell "bash"
Set FontSize 13
Set Width 900
Set Height 560
Set Theme "Catppuccin Mocha"

Hide
Type "docker run --rm -it --device /dev/tenstorrent/2 --device /dev/tenstorrent/3 -v /dev/hugepages-1G:/dev/hugepages-1G tenstorrent/qb2-env:latest bash"
Enter
Sleep 3000ms
Type "cat > ~/vhs-ttnn-add.py << 'PYEOF'"
Enter
Type "import ttnn, torch"
Enter
Type ""
Enter
Type "# 1. Open the chip -- handshake through PCIe column 8"
Enter
Type "device = ttnn.open_device(device_id=0)"
Enter
Type ""
Enter
Type "# 2. Create two tensors on the host"
Enter
Type "a = torch.randn(32, 32)"
Enter
Type "b = torch.randn(32, 32)"
Enter
Type ""
Enter
Type "# 3. Move both to the chip (DMA transfer to DRAM)"
Enter
Type "a_tt = ttnn.from_torch(a, dtype=ttnn.bfloat16, layout=ttnn.TILE_LAYOUT, device=device)"
Enter
Type "b_tt = ttnn.from_torch(b, dtype=ttnn.bfloat16, layout=ttnn.TILE_LAYOUT, device=device)"
Enter
Type ""
Enter
Type "# 4. Run the elementwise add kernel"
Enter
Type "c_tt = ttnn.add(a_tt, b_tt)"
Enter
Type ""
Enter
Type "# 5. Pull the result back to host RAM"
Enter
Type "c = ttnn.to_torch(c_tt)"
Enter
Type ""
Enter
Type "# 6. Close the device -- flushes all pending work and releases the chip"
Enter
Type "ttnn.close_device(device)"
Enter
Type ""
Enter
Type "print('Result shape:', c.shape)"
Enter
Type "PYEOF"
Enter
Sleep 500ms
Type "tt-metalium -c 'uv pip install --python /opt/venv/bin/python3 torch --index-url https://download.pytorch.org/whl/cpu -q'"
Enter
Sleep 150000ms
Type "clear"
Enter
Sleep 500ms
Show

Type "# Show the script: open device, create tensors, add, read back"
Sleep 400ms
Enter
Sleep 200ms

Type "cat ~/vhs-ttnn-add.py"
Sleep 400ms
Enter
Sleep 800ms

Type ""
Sleep 300ms
Enter

Type "# TTNN lives in the TT-Metalium container - run it in there"
Sleep 400ms
Enter
Sleep 200ms

Type `tt-metalium -c 'echo $TT_METAL_ARCH_NAME; python3 ~/vhs-ttnn-add.py 2>&1 | grep -v -E "^2026|warning|info"'`
Sleep 500ms
Enter
Sleep 6000ms

Type ""
Sleep 300ms
Enter

Type "# Result back from chip - bfloat16, shape (32, 32)"
Sleep 400ms
Enter
Sleep 400ms
