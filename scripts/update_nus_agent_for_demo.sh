#!/bin/bash
# Update nus_agent.py to produce shorter, spoken-style replies so the streaming
# text doesn't race far ahead of the TTS audio.
set -e

cat > /root/work/adh_ai_agent/adh_ai_agent/nus_agent.py << 'PYEOF'
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

# This prompt is tuned for a SPOKEN demo where TTS plays alongside the streamed
# text. Short answers keep the subtitle/audio gap small.
SYSTEM_PROMPT = """\
You are an NUS (National University of Singapore) campus assistant. You speak
out loud through a digital human, so your answers must sound like natural speech.

Hard rules:
- Reply in 1-2 SHORT sentences. Never more than ~30 words total.
- No bullet points, no numbered lists, no markdown, no headings.
- No "Sure!", "Great question!", or other filler openers.
- Reply in the language the user uses (English or 中文).

Content rules:
- For Admissions, Faculties, Campus life, IT services, food courts, hostels,
  CourseReg, Student Card, registrar — answer briefly with what you know.
- If you do NOT know an NUS-specific fact (fees, dates, current dean, room
  numbers), say "I'm not sure, please check nus.edu.sg" — do not invent.
- Reasonable defaults: NUS Computing is at Kent Ridge (COM1/COM2/COM3);
  NUS has Kent Ridge, Bukit Timah, and Outram campuses.

Tone: warm and helpful, like a senior student in conversation.
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
            max_tokens=80,
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

echo "nus_agent.py updated. Restarting backend..."

# Kill backend so the new module is reloaded; setsid-detached frontend stays up
pkill -f "uv run python main.py" 2>/dev/null || true
pkill -f "/root/work/awesome-digital-human-live2d/.venv/bin/python3 main.py" 2>/dev/null || true
sleep 1

# Restart backend (frontend is still running)
export PATH=/root/.local/bin:$PATH
: "${GITHUB_TOKEN:?Set GITHUB_TOKEN env var first}"; export GITHUB_TOKEN

cd /root/work/awesome-digital-human-live2d
setsid nohup env GITHUB_TOKEN="$GITHUB_TOKEN" uv run python main.py \
    < /dev/null > /var/log/nus-digital-human/backend.log 2>&1 &
BACKEND_PID=$!
disown $BACKEND_PID 2>/dev/null || true
echo "Backend restarted (pid=$BACKEND_PID)"

# Wait for it to come back up
for i in {1..30}; do
    if curl -s -o /dev/null --max-time 1 http://127.0.0.1:8002/docs; then
        echo "Backend ready after ${i}s"
        break
    fi
    sleep 1
done
