#!/bin/bash
for PID in $(pgrep -f '\.venv/bin/python3 main.py'); do
    echo "=== PID $PID env (GROQ + GITHUB) ==="
    cat /proc/$PID/environ 2>/dev/null | tr '\0' '\n' | grep -E '^(GROQ_API_KEY|GITHUB_TOKEN)' | sed -E 's/=(.{8}).+$/=\1.../'
done
echo
echo "=== Currently inherited env in this shell ==="
echo "GITHUB_TOKEN=${GITHUB_TOKEN:0:8}..."
echo "GROQ_API_KEY=${GROQ_API_KEY:0:8}..."
