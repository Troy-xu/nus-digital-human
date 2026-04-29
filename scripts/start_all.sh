#!/bin/bash
# One-shot launcher for the NUS Digital Human demo.
# Brings up: ADH backend (8002) + ADH frontend (3000), both detached.
#
# Run inside WSL Ubuntu-22.04 as root:
#   bash /mnt/c/Users/troy.xu/Downloads/AI\ Digital\ Human/nus-digital-human/scripts/start_all.sh

set -u
export PATH=/root/.local/bin:$PATH

# Token for the NUS agent (read by adh_ai_agent.nus_agent at LLM call time).
# Get one at: https://github.com/settings/tokens (fine-grained, scope=Models: Read).
: "${GITHUB_TOKEN:?Set GITHUB_TOKEN env var or edit this line with your GitHub PAT}"
export GITHUB_TOKEN

# Token for Whisper ASR via Groq (free tier).
# Get one at: https://console.groq.com/keys
# Read by digitalHuman/engine/asr/whisperASR.py.
: "${GROQ_API_KEY:?Set GROQ_API_KEY env var or edit this line with your Groq API key}"
export GROQ_API_KEY

LOG_DIR=/var/log/nus-digital-human
mkdir -p "$LOG_DIR"

ADH=/root/work/awesome-digital-human-live2d
WEB=$ADH/web

# 1. Stop any previous instances to avoid port collisions
pkill -f "uv run python main.py" 2>/dev/null || true
pkill -f "next start" 2>/dev/null || true
sleep 1

# 2. Start backend (port 8002), detached, with token.
# setsid puts the process in a new session so it survives the WSL launcher exit
# (without setsid, child processes die with SIGHUP when the wsl session ends).
cd "$ADH"
setsid nohup env GITHUB_TOKEN="$GITHUB_TOKEN" uv run python main.py \
    < /dev/null > "$LOG_DIR/backend.log" 2>&1 &
BACKEND_PID=$!
disown $BACKEND_PID 2>/dev/null || true
echo "Backend started (pid=$BACKEND_PID, log=$LOG_DIR/backend.log)"

# 3. Wait for backend to be reachable (max 30s)
for i in {1..30}; do
    if curl -s -o /dev/null --max-time 1 http://127.0.0.1:8002/docs; then
        echo "Backend ready after ${i}s"
        break
    fi
    sleep 1
    if [ "$i" = "30" ]; then
        echo "ERROR: backend did not start in 30s. Check $LOG_DIR/backend.log"
        exit 1
    fi
done

# 4. Start frontend (port 3000, bound to 0.0.0.0 for WSL2 forwarding), detached.
# Same setsid pattern. Critical for the pnpm→node process tree, which otherwise
# gets nuked by SIGHUP when the wsl launcher session exits.
cd "$WEB"
setsid nohup pnpm exec next start -H 0.0.0.0 -p 3000 \
    < /dev/null > "$LOG_DIR/frontend.log" 2>&1 &
FRONTEND_PID=$!
disown $FRONTEND_PID 2>/dev/null || true
echo "Frontend started (pid=$FRONTEND_PID, log=$LOG_DIR/frontend.log)"

# 5. Wait for frontend to be reachable
for i in {1..30}; do
    if curl -s -o /dev/null --max-time 1 http://127.0.0.1:3000/sentio; then
        echo "Frontend ready after ${i}s"
        break
    fi
    sleep 1
done

echo ""
echo "============================================"
echo "  NUS Digital Human demo running"
echo "============================================"
echo "  Frontend: http://localhost:3000/sentio"
echo "  Backend : http://localhost:8002/docs"
echo "  Logs    : $LOG_DIR/*.log"
echo ""
echo "  In the browser, set Agent = OutsideAgent"
echo "    agent_type   = local_lib"
echo "    agent_module = adh_ai_agent.nus_agent"
echo ""
echo "  To stop: bash stop_all.sh"
echo "============================================"
