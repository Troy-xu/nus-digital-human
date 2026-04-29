"""
Smoke test: call GitHub Models (OpenAI-compatible endpoint) with gpt-4o-mini.

Usage:
    export GITHUB_TOKEN=ghp_xxx   # PAT with models:read scope
    python test_github_models.py
"""
import os
from openai import OpenAI

API_KEY = os.environ.get("GITHUB_TOKEN")
if not API_KEY:
    raise SystemExit("Set GITHUB_TOKEN env var to your GitHub PAT (scope: models:read)")

client = OpenAI(
    api_key=API_KEY,
    base_url="https://models.inference.ai.azure.com",
)

MODEL_ID = "gpt-4o-mini"

resp = client.chat.completions.create(
    model=MODEL_ID,
    messages=[
        {"role": "system", "content": "You are an NUS campus assistant. Answer briefly."},
        {"role": "user", "content": "Where is NUS Computing located on campus?"},
    ],
    temperature=0.4,
    max_tokens=200,
)

print(f"Model: {MODEL_ID}")
print("Reply:")
print(resp.choices[0].message.content)
