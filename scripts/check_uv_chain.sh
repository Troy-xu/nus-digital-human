#!/bin/bash
echo "=== Process chain for backend ==="
for PID in $(pgrep -f 'main.py'); do
    PARENT=$(ps -o ppid= -p $PID 2>/dev/null | tr -d ' ')
    PARENT_CMD=$(ps -o cmd= -p $PARENT 2>/dev/null)
    echo "PID $PID parent=$PARENT ($PARENT_CMD)"
    echo "  GROQ_API_KEY: $(cat /proc/$PID/environ 2>/dev/null | tr '\0' '\n' | grep '^GROQ_API_KEY=' | cut -d= -f2- | head -c12)..."
    echo "  GITHUB_TOKEN: $(cat /proc/$PID/environ 2>/dev/null | tr '\0' '\n' | grep '^GITHUB_TOKEN=' | cut -d= -f2- | head -c12)..."
    echo
done
echo "=== /root path env files ==="
ls -la /root/.env /root/.config/uv/ 2>&1 | head -10
echo
echo "=== uv version ==="
/root/.local/bin/uv --version
echo
echo "=== Is there a uv env file at /root/work/awesome-digital-human-live2d? ==="
ls -la /root/work/awesome-digital-human-live2d/.python-version /root/work/awesome-digital-human-live2d/.env* 2>&1
