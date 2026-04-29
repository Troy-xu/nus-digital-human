#!/bin/bash
set -e
export PATH=/root/.local/bin:$PATH
: "${GITHUB_TOKEN:?Set GITHUB_TOKEN env var first}"; export GITHUB_TOKEN
: "${GROQ_API_KEY:?Set GROQ_API_KEY env var first}"; export GROQ_API_KEY

LOG_DIR=/var/log/nus-digital-human
mkdir -p "$LOG_DIR"

ADH=/root/work/awesome-digital-human-live2d

echo "=== Rebuilding frontend (revert to Recorder + /asr/file flow) ==="
cd "$ADH/web"
pnpm run build 2>&1 | tail -10

echo "=== Killing both services ==="
pkill -f "uv run python main.py" 2>/dev/null || true
pkill -f "next start" 2>/dev/null || true
sleep 1

echo "=== Starting backend (with Whisper ASR engine loaded) ==="
cd "$ADH"
setsid nohup env GITHUB_TOKEN="$GITHUB_TOKEN" GROQ_API_KEY="$GROQ_API_KEY" \
    uv run python main.py \
    < /dev/null > "$LOG_DIR/backend.log" 2>&1 &
disown $! 2>/dev/null || true

for i in {1..30}; do
    if curl -s -o /dev/null --max-time 1 http://127.0.0.1:8002/docs; then
        echo "Backend ready after ${i}s"; break
    fi; sleep 1
done

echo "=== Verify Whisper engine is registered ==="
curl -s http://127.0.0.1:8002/adh/asr/v0/engine | head -1

echo "=== Starting frontend ==="
cd "$ADH/web"
setsid nohup pnpm exec next start -H 0.0.0.0 -p 3000 \
    < /dev/null > "$LOG_DIR/frontend.log" 2>&1 &
disown $! 2>/dev/null || true

for i in {1..30}; do
    if curl -s -o /dev/null --max-time 1 http://127.0.0.1:3000/sentio; then
        echo "Frontend ready after ${i}s"; break
    fi; sleep 1
done

echo
echo "============================================"
echo "  Done. Whisper ASR engine is loaded."
echo "  But you still need to paste your Groq key:"
echo "  Edit scripts/start_all.sh and replace"
echo "    PASTE_YOUR_GROQ_KEY_HERE"
echo "  with your actual key from console.groq.com/keys."
echo "============================================"
