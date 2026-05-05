#!/bin/bash
# Direct curl test against Groq, using GROQ_API_KEY from current shell env.
echo "GROQ key length in env: ${#GROQ_API_KEY}"
echo "GROQ key starts: ${GROQ_API_KEY:0:8}..."
echo "Testing chat completion..."
curl -s https://api.groq.com/openai/v1/chat/completions \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"llama-3.3-70b-versatile","messages":[{"role":"user","content":"Hi in 5 words"}],"max_tokens":20}' \
  | head -c 600
echo
