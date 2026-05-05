#!/bin/bash
set -e
python3 << 'PYEOF'
from pathlib import Path
p = Path("/root/work/awesome-digital-human-live2d/web/app/(products)/sentio/components/chatbot/input.tsx")
src = p.read_text()

old = """        additionalAudioConstraints: {
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
        },"""

new = """        additionalAudioConstraints: ({
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
        } as any),"""

if "as any" in src:
    print("Already patched")
elif old not in src:
    raise SystemExit("ERROR: block not found")
else:
    p.write_text(src.replace(old, new, 1))
    print("Cast applied")
PYEOF

grep "as any" /root/work/awesome-digital-human-live2d/web/app/\(products\)/sentio/components/chatbot/input.tsx | head -2
