#!/bin/bash
# Quick health check: verify backend, frontend, and NUS agent are all working.

echo "[1/3] Backend (port 8002)"
curl -s -o /dev/null -w "    /docs: %{http_code} (%{time_total}s)\n" --max-time 3 http://127.0.0.1:8002/docs

echo "[2/3] Frontend (port 3000)"
curl -s -o /dev/null -w "    /sentio: %{http_code} (%{time_total}s)\n" --max-time 3 http://127.0.0.1:3000/sentio

echo "[3/3] NUS agent end-to-end"
REPLY=$(curl -sN -X POST http://127.0.0.1:8002/adh/agent/v0/engine \
    -H "Content-Type: application/json" \
    -H "user-id: health-check" \
    -d '{"engine":"OutsideAgent","config":{"agent_type":"local_lib","agent_module":"adh_ai_agent.nus_agent"},"data":"In one short sentence, where is NUS School of Computing?","conversation_id":""}' \
    --max-time 30 | grep '^data: ' | sed 's/^data: //' | tr -d '\n')

if echo "$REPLY" | grep -qi "kent ridge\|com1\|com2\|com3\|computing"; then
    echo "    ✓ NUS agent replied with relevant content:"
    echo "      ${REPLY:0:200}..."
else
    echo "    ✗ NUS agent did not produce expected reply:"
    echo "      $REPLY"
fi
