#!/bin/bash
# Switch EdgeTTS default voice from zh-CN-XiaoxiaoNeural to en-US-AvaMultilingualNeural.
# Multilingual voices auto-detect English / Chinese / etc per utterance.
set -e
F=/root/work/awesome-digital-human-live2d/configs/engines/tts/edgeAPI.yaml

python3 << 'PYEOF'
from pathlib import Path
p = Path("/root/work/awesome-digital-human-live2d/configs/engines/tts/edgeAPI.yaml")
src = p.read_text()
old = 'default: "zh-CN-XiaoxiaoNeural"'
new = 'default: "en-US-AvaMultilingualNeural"'
if new in src:
    print("Already patched")
elif old in src:
    p.write_text(src.replace(old, new, 1))
    print("Patched.")
else:
    raise SystemExit("ERROR: target line not found")
PYEOF

echo "--- verify ---"
grep -B 1 -A 1 'name: "voice"' "$F" | head -10
