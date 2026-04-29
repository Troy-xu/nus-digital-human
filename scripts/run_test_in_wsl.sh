#!/bin/bash
set -e
export PATH=/root/.local/bin:$PATH

# Use a temp uv project so openai SDK is isolated
mkdir -p /tmp/nus-llm-test
cd /tmp/nus-llm-test
[ -f pyproject.toml ] || uv init --quiet
uv add openai --quiet 2>&1 | tail -3

# Inline test script
cat > /tmp/nus-llm-test/test.py << 'PYEOF'
import os
from openai import OpenAI

client = OpenAI(
    api_key=os.environ["GITHUB_TOKEN"],
    base_url="https://models.inference.ai.azure.com",
)

resp = client.chat.completions.create(
    model="gpt-4o-mini",
    messages=[
        {"role": "system", "content": "You are an NUS campus assistant. Answer briefly in 2-3 sentences."},
        {"role": "user", "content": "Where is NUS School of Computing located on campus?"},
    ],
    temperature=0.4,
    max_tokens=200,
)

print("=== GitHub Models gpt-4o-mini ===")
print(resp.choices[0].message.content)
print()
print(f"[tokens: prompt={resp.usage.prompt_tokens}, completion={resp.usage.completion_tokens}]")
PYEOF

uv run python /tmp/nus-llm-test/test.py
