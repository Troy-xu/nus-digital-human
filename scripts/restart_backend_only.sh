#!/bin/bash
set -e
export PATH=/root/.local/bin:$PATH
: "${GITHUB_TOKEN:?Set GITHUB_TOKEN env var first}"
: "${GROQ_API_KEY:?Set GROQ_API_KEY env var first}"
export GITHUB_TOKEN GROQ_API_KEY

LOG_DIR=/var/log/nus-digital-human
mkdir -p "$LOG_DIR"
ADH=/root/work/awesome-digital-human-live2d

pkill -f "uv run python main.py" 2>/dev/null || true
pkill -f "/root/work/awesome-digital-human-live2d/.venv/bin/python3 main.py" 2>/dev/null || true
sleep 1

cd "$ADH"
setsid nohup env GITHUB_TOKEN="$GITHUB_TOKEN" GROQ_API_KEY="$GROQ_API_KEY" \
    uv run python main.py \
    < /dev/null > "$LOG_DIR/backend.log" 2>&1 &
disown $! 2>/dev/null || true

for i in {1..30}; do
    if curl -s -o /dev/null --max-time 1 http://127.0.0.1:8002/docs; then
        echo "Backend ready after ${i}s"; exit 0
    fi; sleep 1
done
echo "ERROR: backend not reachable after 30s"
tail -15 "$LOG_DIR/backend.log"
exit 1
