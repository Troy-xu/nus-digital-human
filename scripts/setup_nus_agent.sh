#!/bin/bash
set -e
export PATH=/root/.local/bin:$PATH

# 1. Create the adh_ai_agent uv project
mkdir -p /root/work
cd /root/work

if [ ! -d adh_ai_agent ]; then
    uv init adh_ai_agent --quiet --no-readme --no-workspace
    echo "Created /root/work/adh_ai_agent"
fi

cd /root/work/adh_ai_agent

# 2. Patch pyproject.toml: pin Python 3.10 + add setuptools build backend (so `pip install -e` works)
python3 << 'PYEOF'
from pathlib import Path
p = Path("pyproject.toml")
content = p.read_text()

if "[build-system]" not in content:
    content += '''
[build-system]
requires = ["setuptools>=42"]
build-backend = "setuptools.build_meta"
'''

import re
content = re.sub(r'requires-python\s*=\s*"[^"]+"', 'requires-python = ">=3.10"', content)

p.write_text(content)
print(content)
PYEOF

# 3. Add openai dependency
uv add openai --quiet 2>&1 | tail -3

# 4. Create package directory + nus_agent.py + __init__.py
mkdir -p adh_ai_agent
touch adh_ai_agent/__init__.py

cat > adh_ai_agent/nus_agent.py << 'PYEOF'
"""
NUS Campus Assistant agent for ADH OutsideAgent.

Contract (from awesome-digital-human-live2d/digitalHuman/agent/core/outsideAgent.py):
    - module exposes `chat_with_agent(user_msg: str)`
    - it must be an async generator yielding ('TEXT', str) tuples
"""
import os
from openai import AsyncOpenAI

# GitHub Models endpoint (OpenAI-compatible). See https://github.com/marketplace/models
BASE_URL = os.environ.get("LLM_BASE_URL", "https://models.inference.ai.azure.com")
API_KEY = os.environ.get("GITHUB_TOKEN") or os.environ.get("EXAMPLE_API_KEY", "")
MODEL_ID = os.environ.get("LLM_MODEL_ID", "gpt-4o-mini")

SYSTEM_PROMPT = """\
You are an NUS (National University of Singapore) campus assistant.

Your role: a friendly, knowledgeable senior student helping prospective and current
NUS students with questions about:
- Admissions (undergraduate, graduate, exchange)
- Faculties and majors (Computing, Engineering, Business, Science, etc.)
- Campus life (hostels, food courts, libraries, MRT/buses, recreation)
- Key services (CourseReg, Student Card, IT helpdesk, registrar)

Rules:
1. Reply in the language the user uses (English or 中文).
2. Keep answers concise — under 4 sentences unless the user asks for detail.
3. If you do not know an NUS-specific fact (fees, dates, policies), honestly
   say so and suggest the user check nus.edu.sg or contact the relevant office.
4. Never fabricate dates, fees, or course codes — those change frequently.
5. Tone: warm, helpful, slightly upbeat — like a senior who actually likes the school.
6. Reasonable defaults: NUS Computing is at Kent Ridge in COM1/COM2/COM3 buildings;
   the Singapore campus has Kent Ridge, Bukit Timah, and Outram Park sites.
"""


_client = AsyncOpenAI(api_key=API_KEY, base_url=BASE_URL)


async def chat_with_agent(user_msg: str):
    """Async generator yielding ('TEXT', str) chunks for ADH OutsideAgent."""
    if not API_KEY:
        yield ('TEXT', "[NUS Agent] Missing GITHUB_TOKEN env var on the server.")
        return

    try:
        stream = await _client.chat.completions.create(
            model=MODEL_ID,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_msg},
            ],
            temperature=0.4,
            max_tokens=400,
            stream=True,
        )

        async for chunk in stream:
            if not chunk.choices:
                continue
            delta = chunk.choices[0].delta.content
            if delta:
                yield ('TEXT', delta)
    except Exception as e:
        yield ('TEXT', f"[NUS Agent] LLM error: {e}")
PYEOF

echo "--- adh_ai_agent layout ---"
find /root/work/adh_ai_agent -name "*.py" -o -name "pyproject.toml" | sort

echo "--- pyproject.toml ---"
cat /root/work/adh_ai_agent/pyproject.toml

echo "--- nus_agent.py first 30 lines ---"
head -30 /root/work/adh_ai_agent/adh_ai_agent/nus_agent.py
