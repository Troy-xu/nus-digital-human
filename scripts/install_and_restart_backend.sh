#!/bin/bash
set -e
export PATH=/root/.local/bin:$PATH

# 1. Install adh_ai_agent into ADH backend venv as editable
cd /root/work/awesome-digital-human-live2d
uv pip install -e ../adh_ai_agent 2>&1 | tail -3

# 2. Verify the import works inside the backend venv
uv run python -c "from adh_ai_agent.nus_agent import chat_with_agent; print('OK: chat_with_agent imported')"

# 3. Kill any existing backend
pkill -f "uv run python main.py" 2>/dev/null || true
pkill -f "main.py" 2>/dev/null || true
sleep 2

# 4. Show kill confirmation
ss -tlnp 2>/dev/null | grep 8002 && echo "WARN: port 8002 still occupied" || echo "Port 8002 free, ready to restart"
