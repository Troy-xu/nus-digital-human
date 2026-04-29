"""
NUS Campus Assistant agent for ADH OutsideAgent.

Contract (from awesome-digital-human-live2d/digitalHuman/agent/core/outsideAgent.py):
    - module exposes `chat_with_agent(user_msg: str)`
    - it must be an async generator yielding ('TEXT', str) tuples
"""
import os
from pathlib import Path

import numpy as np
from openai import AsyncOpenAI

# GitHub Models endpoint (OpenAI-compatible). See https://github.com/marketplace/models
BASE_URL = os.environ.get("LLM_BASE_URL", "https://models.inference.ai.azure.com")
API_KEY = os.environ.get("GITHUB_TOKEN") or os.environ.get("EXAMPLE_API_KEY", "")
MODEL_ID = os.environ.get("LLM_MODEL_ID", "gpt-4o-mini")
EMBED_MODEL = os.environ.get("EMBED_MODEL_ID", "text-embedding-3-small")

# RAG index built by scripts/build_rag_index.py. Loaded once at module import.
_RAG_PATH = Path(__file__).resolve().parent.parent / "data" / "nus_rag.npz"
try:
    _rag = np.load(_RAG_PATH, allow_pickle=True)
    _rag_embeddings: np.ndarray | None = _rag["embeddings"]
    _rag_chunks: list[str] = _rag["chunks"].tolist()
    _rag_sources: list[str] = _rag["sources"].tolist()
    print(f"[NUS Agent] RAG loaded: {len(_rag_chunks)} chunks from {_RAG_PATH}")
except Exception as _rag_err:
    _rag_embeddings = None
    _rag_chunks = []
    _rag_sources = []
    print(f"[NUS Agent] RAG NOT loaded ({_rag_err}); continuing without retrieval.")

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

# Single-user demo conversation history. Cleared on backend restart, or when
# the user says "reset"/"clear"/"重置"/"清空".
# Each entry: {"role": "user"|"assistant", "content": "..."}.
_history: list[dict] = []
MAX_TURNS = 8  # keep last 8 user+assistant pairs (~16 messages)


def _is_reset_command(msg: str) -> bool:
    s = msg.strip().lower().rstrip('.!?。！？')
    return s in {"reset", "clear", "clear chat", "start over",
                 "重置", "清空", "清空对话", "重新开始"}


async def _retrieve(query: str, k: int = 3) -> list[str]:
    """Retrieve top-k most relevant NUS knowledge chunks via cosine similarity."""
    if _rag_embeddings is None or len(_rag_chunks) == 0:
        return []
    import time
    t0 = time.perf_counter()
    try:
        resp = await _client.embeddings.create(model=EMBED_MODEL, input=[query])
        q = np.asarray(resp.data[0].embedding, dtype=np.float32)
        q /= np.linalg.norm(q) + 1e-12
        sims = _rag_embeddings @ q
        top_idx = np.argsort(-sims)[:k]
        # With only ~24 chunks, give the LLM the top-k unconditionally; let it
        # decide what's relevant. Threshold filtering caused too many misses on
        # follow-up questions where pronouns weakened the embedding signal.
        result = [_rag_chunks[i] for i in top_idx]
        print(f"[NUS Agent] retrieval {time.perf_counter()-t0:.2f}s, top sims={[round(float(sims[i]),3) for i in top_idx]}")
        return result
    except Exception as e:
        print(f"[NUS Agent] retrieval failed: {e}")
        return []


async def chat_with_agent(user_msg: str):
    """Async generator yielding ('TEXT', str) chunks for ADH OutsideAgent."""
    global _history

    if not API_KEY:
        yield ('TEXT', "[NUS Agent] Missing GITHUB_TOKEN env var on the server.")
        return

    if _is_reset_command(user_msg):
        _history = []
        yield ('TEXT', "Conversation cleared. Ask me anything about NUS.")
        return

    # Retrieve relevant NUS knowledge BEFORE appending to history (so retrieval
    # uses the raw query, not contaminated by previous assistant text).
    retrieved = await _retrieve(user_msg, k=3)

    # Append user turn now so it's part of THIS request's context.
    _history.append({"role": "user", "content": user_msg})

    # Trim to last MAX_TURNS pairs to bound token usage.
    if len(_history) > MAX_TURNS * 2:
        _history = _history[-MAX_TURNS * 2:]

    # Build the message list. Inject retrieved NUS context as a separate
    # system-role message, kept short enough to coexist with chat history.
    messages: list[dict] = [{"role": "system", "content": SYSTEM_PROMPT}]
    if retrieved:
        rag_block = "\n\n".join(f"- {c}" for c in retrieved)
        messages.append({
            "role": "system",
            "content": (
                "Relevant NUS knowledge retrieved for this turn. Ground your "
                "answer in this material when it applies; do not contradict it. "
                "If the material does not cover the question, say so honestly.\n\n"
                f"{rag_block}"
            ),
        })
    messages.extend(_history)

    full_response = ""
    try:
        stream = await _client.chat.completions.create(
            model=MODEL_ID,
            messages=messages,
            temperature=0.4,
            max_tokens=80,
            stream=True,
        )

        async for chunk in stream:
            if not chunk.choices:
                continue
            delta = chunk.choices[0].delta.content
            if delta:
                full_response += delta
                yield ('TEXT', delta)

        # Only commit assistant turn to history after streaming succeeds.
        if full_response.strip():
            _history.append({"role": "assistant", "content": full_response})
    except Exception as e:
        # Roll back the user turn so a transient LLM error doesn't poison history.
        if _history and _history[-1].get("role") == "user":
            _history.pop()
        yield ('TEXT', f"[NUS Agent] LLM error: {e}")
