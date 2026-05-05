#!/bin/bash
# One-shot helper: reuse env vars from the currently-running backend process
# to restart it. Useful when scripts/start_all.sh has been scrubbed of tokens
# but a backend is already running with valid env.
#
# Run inside WSL Ubuntu-22.04 as root.
set -e
export PATH=/root/.local/bin:$PATH

PID=$(pgrep -f '\.venv/bin/python3 main.py' | head -1)
if [ -z "$PID" ]; then
    echo "ERROR: no running backend process found. Use scripts/start_all.sh with explicit tokens instead."
    exit 1
fi

echo "Found running backend pid=$PID; reading its env vars..."
EXTRACTED_GH=$(cat /proc/$PID/environ 2>/dev/null | tr '\0' '\n' | grep '^GITHUB_TOKEN=' | head -1 | cut -d= -f2-)
EXTRACTED_GROQ=$(cat /proc/$PID/environ 2>/dev/null | tr '\0' '\n' | grep '^GROQ_API_KEY=' | head -1 | cut -d= -f2-)

if [ -z "$EXTRACTED_GH" ] || [ -z "$EXTRACTED_GROQ" ]; then
    echo "ERROR: couldn't extract tokens from running backend env."
    exit 1
fi
echo "Tokens extracted (lengths: GH=${#EXTRACTED_GH}, GROQ=${#EXTRACTED_GROQ})"

echo "Killing old backend..."
pkill -f "uv run python main.py" 2>/dev/null || true
pkill -f "/root/work/awesome-digital-human-live2d/.venv/bin/python3 main.py" 2>/dev/null || true
sleep 2

echo "Starting fresh backend with same env..."
cd /root/work/awesome-digital-human-live2d
setsid nohup env GITHUB_TOKEN="$EXTRACTED_GH" GROQ_API_KEY="$EXTRACTED_GROQ" \
    uv run python main.py \
    < /dev/null > /var/log/nus-digital-human/backend.log 2>&1 &
disown $! 2>/dev/null || true

# Drop the locals so they don't linger in this shell's env
unset EXTRACTED_GH EXTRACTED_GROQ

for i in {1..30}; do
    if curl -s -o /dev/null --max-time 1 http://127.0.0.1:8002/docs; then
        echo "Backend ready after ${i}s"
        exit 0
    fi
    sleep 1
done
echo "ERROR: backend not reachable after 30s"
tail -15 /var/log/nus-digital-human/backend.log
exit 1
