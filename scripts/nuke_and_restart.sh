#!/bin/bash
# Kill EVERYTHING related to ADH then restart fresh from current shell env.
set -e

echo "Current shell GROQ_API_KEY starts: ${GROQ_API_KEY:0:8}..."
echo "Current shell GITHUB_TOKEN starts: ${GITHUB_TOKEN:0:8}..."

if [ -z "${GROQ_API_KEY:-}" ] || [ -z "${GITHUB_TOKEN:-}" ]; then
    echo "ERROR: env vars not present in this shell"
    exit 1
fi

echo
echo "Killing ALL ADH-related processes..."
pkill -9 -f 'uv run python main.py' 2>/dev/null || true
pkill -9 -f '\.venv/bin/python3 main.py' 2>/dev/null || true
pkill -9 -f 'next start' 2>/dev/null || true
pkill -9 -f 'node.*next' 2>/dev/null || true
sleep 2

REMAINING=$(pgrep -af 'main.py|next start|node.*next' 2>/dev/null | wc -l)
echo "Processes still alive after kill: $REMAINING"

echo
echo "Now invoking start_all.sh with current shell env..."
exec bash /mnt/c/Users/troy.xu/Downloads/AI*Digital*Human/nus-digital-human/scripts/start_all.sh
