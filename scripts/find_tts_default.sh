#!/bin/bash
echo "=== TTS-related lines in store/sentio.ts ==="
grep -nE 'tts|Tts|voice|Voice' /root/work/awesome-digital-human-live2d/web/lib/store/sentio.ts | head -40
echo
echo "=== TTS-related lines in lib/constants.ts ==="
grep -nE 'tts|Tts|TTS|voice|VOICE|Voice' /root/work/awesome-digital-human-live2d/web/lib/constants.ts | head -20
echo
echo "=== TTS settings component (might init defaults) ==="
ls /root/work/awesome-digital-human-live2d/web/app/\(products\)/sentio/components/settings/
