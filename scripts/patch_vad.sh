#!/bin/bash
# Patch ChatVadInput's useMicVAD config: stricter thresholds + echo cancellation.
set -e

python3 << 'PYEOF'
from pathlib import Path
p = Path("/root/work/awesome-digital-human-live2d/web/app/(products)/sentio/components/chatbot/input.tsx")
src = p.read_text()

if "positiveSpeechThreshold" in src:
    print("Already patched, skipping")
    raise SystemExit(0)

old = """    const vad = useMicVAD({
        baseAssetPath: getSrcPath("vad/"),
        onnxWASMBasePath: getSrcPath("vad/"),
        // model: "v5",
        onSpeechStart: () => {"""

new = """    const vad = useMicVAD({
        baseAssetPath: getSrcPath("vad/"),
        onnxWASMBasePath: getSrcPath("vad/"),
        // model: "v5",
        // Stricter thresholds + browser-level audio processing to suppress
        // background noise / breathing / typing from triggering ASR turns.
        positiveSpeechThreshold: 0.85,
        negativeSpeechThreshold: 0.6,
        minSpeechFrames: 5,
        redemptionFrames: 12,
        additionalAudioConstraints: {
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
        },
        onSpeechStart: () => {"""

if old not in src:
    raise SystemExit("ERROR: target useMicVAD block not found verbatim")

p.write_text(src.replace(old, new, 1))
print("Patched useMicVAD block")
PYEOF

echo "--- verify ---"
grep -A 1 "positiveSpeechThreshold\|additionalAudioConstraints" /root/work/awesome-digital-human-live2d/web/app/\(products\)/sentio/components/chatbot/input.tsx | head -10
