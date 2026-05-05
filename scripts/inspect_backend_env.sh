#!/bin/bash
PID=$(pgrep -f '/.venv/bin/python3 main.py' | head -1)
if [ -z "$PID" ]; then
    echo "No backend python process found"
    exit 1
fi
echo "Backend PID: $PID"
echo
ENV_DUMP=$(cat /proc/$PID/environ | tr '\0' '\n')
echo "Has GITHUB_TOKEN: $(echo "$ENV_DUMP" | grep -c '^GITHUB_TOKEN=')"
echo "GITHUB_TOKEN length: $(echo "$ENV_DUMP" | grep '^GITHUB_TOKEN=' | cut -d= -f2- | wc -c)"
echo "GITHUB_TOKEN starts: $(echo "$ENV_DUMP" | grep '^GITHUB_TOKEN=' | cut -d= -f2- | head -c8)..."
echo
echo "Has GROQ_API_KEY: $(echo "$ENV_DUMP" | grep -c '^GROQ_API_KEY=')"
echo "GROQ_API_KEY length: $(echo "$ENV_DUMP" | grep '^GROQ_API_KEY=' | cut -d= -f2- | wc -c)"
echo "GROQ_API_KEY starts: $(echo "$ENV_DUMP" | grep '^GROQ_API_KEY=' | cut -d= -f2- | head -c8)..."
echo
echo "LLM_PROVIDER: [$(echo "$ENV_DUMP" | grep '^LLM_PROVIDER=' | cut -d= -f2-)]"
echo "LLM_BASE_URL: [$(echo "$ENV_DUMP" | grep '^LLM_BASE_URL=' | cut -d= -f2-)]"
echo "LLM_MODEL_ID: [$(echo "$ENV_DUMP" | grep '^LLM_MODEL_ID=' | cut -d= -f2-)]"
