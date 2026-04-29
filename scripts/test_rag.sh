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

ask "reset"
# These should benefit from the comp.nus.edu.sg pages we indexed.
ask "What does NUS Computing offer for undergraduate programmes?"
ask "Tell me about the BSc Computer Science programme at NUS."
ask "What's the difference between CS and IS at NUS Computing?"
ask "What is NUS School of Computing's vision or mission?"
echo
echo "--- RAG load message in backend log ---"
grep -i "rag\|chunk" /var/log/nus-digital-human/backend.log | head -5
