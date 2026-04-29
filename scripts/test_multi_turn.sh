#!/bin/bash
URL="http://127.0.0.1:8002/adh/agent/v0/engine"

ask() {
  local q="$1"
  echo "================================================"
  echo "Q: $q"
  echo "------"
  curl -sN -X POST "$URL" \
    -H "Content-Type: application/json" \
    -H "user-id: smoke-test" \
    -d "{\"engine\":\"OutsideAgent\",\"config\":{\"agent_type\":\"local_lib\",\"agent_module\":\"adh_ai_agent.nus_agent\"},\"data\":\"$q\",\"conversation_id\":\"\"}" \
    | grep '^data: ' | sed 's/^data: //' | tr -d '\n'
  echo
  echo
}

# Reset history first to start clean
ask "reset"
ask "Where is NUS Computing?"
ask "How do I get there from Kent Ridge MRT?"
ask "What's nearby for lunch?"
ask "Sounds great. Any drinks recommendations?"
echo "--- Should remember COM1/Kent Ridge context across turns ---"
echo
echo "--- Now test reset: ---"
ask "reset"
ask "What did I just ask you about?"
