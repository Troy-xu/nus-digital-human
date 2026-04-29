#!/bin/bash
# Run a curated set of smoke tests against the NUS agent and concatenate the
# streamed output for each. Useful before a demo to spot regressions.
set -u

QUESTIONS=(
  "Where is NUS School of Computing located?"
  "What's the difference between Computing and Information Systems at NUS?"
  "NUS 计算机学院的本科申请有什么要求？"
  "Recommend a food court near COM1."
  "What is CourseReg and when does it open?"
)

URL="http://127.0.0.1:8002/adh/agent/v0/engine"

ask() {
  local q="$1"
  echo "=========================================="
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

for q in "${QUESTIONS[@]}"; do
  ask "$q"
done
