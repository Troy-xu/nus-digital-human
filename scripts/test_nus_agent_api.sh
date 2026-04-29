#!/bin/bash
# Smoke-test the NUS agent end-to-end via ADH backend API
# (bypasses the browser frontend; useful for diagnostic)

set -u

QUESTION="${1:-Where is NUS School of Computing on campus?}"
URL="http://127.0.0.1:8002/adh/agent/v0/engine"

echo "Q: $QUESTION"
echo "Streaming reply:"
echo "----------------------------------------"

curl -sN -X POST "$URL" \
  -H "Content-Type: application/json" \
  -H "user-id: smoke-test" \
  -d @- << EOF
{
  "engine": "OutsideAgent",
  "config": {
    "agent_type": "local_lib",
    "agent_module": "adh_ai_agent.nus_agent"
  },
  "data": "$QUESTION",
  "conversation_id": ""
}
EOF
echo
echo "----------------------------------------"
