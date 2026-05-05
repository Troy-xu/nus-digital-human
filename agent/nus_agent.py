"""
NUS Campus Assistant agent for ADH OutsideAgent.

Contract (from awesome-digital-human-live2d/digitalHuman/agent/core/outsideAgent.py):
    - module exposes `chat_with_agent(user_msg: str)`
    - it must be an async generator yielding ('TEXT', str) tuples

LLM provider selection via env var LLM_PROVIDER:
    - "groq"    -> llama-3.3-70b-versatile via api.groq.com (default; fastest, free)
    - "github"  -> gpt-4o-mini via models.inference.ai.azure.com (free)
    - "openai"  -> gpt-4o via api.openai.com (paid, future option)

Per-provider env overrides also supported:
    - LLM_BASE_URL / LLM_MODEL_ID let you pin specific values.
    - Embeddings ALWAYS via GitHub Models (uses GITHUB_TOKEN). RAG retrieval
      quality stays constant regardless of which LLM you chose.
"""
import os
from pathlib import Path

import numpy as np
from openai import AsyncOpenAI


# ---------- LLM provider dispatch ----------------------------------------

PROVIDERS = {
    "groq": {
        "base_url": "https://api.groq.com/openai/v1",
        "api_key_env": "GROQ_API_KEY",
        "default_model": "llama-3.3-70b-versatile",
    },
    "github": {
        "base_url": "https://models.inference.ai.azure.com",
        "api_key_env": "GITHUB_TOKEN",
        "default_model": "gpt-4o-mini",
    },
    "openai": {
        "base_url": "https://api.openai.com/v1",
        "api_key_env": "OPENAI_API_KEY",
        "default_model": "gpt-4o",
    },
}

LLM_PROVIDER = os.environ.get("LLM_PROVIDER", "groq").lower()
_cfg = PROVIDERS.get(LLM_PROVIDER, PROVIDERS["groq"])

LLM_API_KEY = os.environ.get(_cfg["api_key_env"], "")
LLM_BASE_URL = os.environ.get("LLM_BASE_URL", _cfg["base_url"])
MODEL_ID = os.environ.get("LLM_MODEL_ID", _cfg["default_model"])

_llm_client = AsyncOpenAI(api_key=LLM_API_KEY, base_url=LLM_BASE_URL)
print(f"[NUS Agent] LLM: provider={LLM_PROVIDER} model={MODEL_ID} base={LLM_BASE_URL}")


# ---------- Embeddings (always GitHub Models, for free + consistent RAG) ----

EMBED_API_KEY = os.environ.get("GITHUB_TOKEN", "")
EMBED_BASE_URL = "https://models.inference.ai.azure.com"
EMBED_MODEL = os.environ.get("EMBED_MODEL_ID", "text-embedding-3-small")
_embed_client = AsyncOpenAI(api_key=EMBED_API_KEY, base_url=EMBED_BASE_URL)


# ---------- RAG index loading -------------------------------------------

_RAG_PATH = Path(__file__).resolve().parent.parent / "data" / "nus_rag.npz"
USE_RAG = os.environ.get("USE_RAG", "true").lower() in {"1", "true", "yes", "on"}

try:
    _rag = np.load(_RAG_PATH, allow_pickle=True)
    _rag_embeddings: np.ndarray | None = _rag["embeddings"]
    _rag_chunks: list[str] = _rag["chunks"].tolist()
    _rag_sources: list[str] = _rag["sources"].tolist()
    print(f"[NUS Agent] RAG loaded: {len(_rag_chunks)} chunks (USE_RAG={USE_RAG})")
except Exception as _rag_err:
    _rag_embeddings = None
    _rag_chunks = []
    _rag_sources = []
    print(f"[NUS Agent] RAG NOT loaded ({_rag_err}); continuing without retrieval.")


# ---------- System prompt -----------------------------------------------

# This prompt is tuned for a SPOKEN demo where TTS plays alongside the streamed
# text. Short answers keep the subtitle/audio gap small. The "honesty" block
# uses a HEDGE-rather-than-REFUSE policy: if the agent has a plausible answer
# for a person/date/fact, it shares it with a verify note instead of declining
# entirely. Refuses outright only for numerical fees/dates it doesn't know.
SYSTEM_PROMPT = """\
You are an NUS (National University of Singapore) campus assistant. You speak
out loud through a digital human, so your answers must sound like natural speech.

Hard rules:
- Reply in 1-2 SHORT sentences. Never more than ~30 words total.
- No bullet points, no numbered lists, no markdown, no headings.
- No "Sure!", "Great question!", or other filler openers.
- Reply in the language the user uses (English or 中文).

Honesty / accuracy:
- For things you DO know confidently (campus locations, programme names,
  faculty descriptions, well-established facts): share directly.
- For things that change over time (current Dean, current fees, current
  deadlines, room assignments, course offerings each semester): if you have
  a plausible answer, share it AND add a brief verify note such as
  "please verify on nus.edu.sg" or "as of my last info".
- For specific numbers you don't actually recall (exact fee amounts,
  exact dates, room numbers): say "I'm not sure, please check nus.edu.sg".
  Never invent numerical values.
- Treat retrieved RAG context as supporting material, not as authoritative
  for time-sensitive facts. Cross-check against your own knowledge before
  asserting names or dates.

Reasonable defaults:
- NUS Computing is at Kent Ridge campus (COM1/COM2/COM3 buildings).
- NUS has Kent Ridge, Bukit Timah, and Outram campuses.

Tone: warm and helpful, like a senior student in conversation.
"""


# ---------- Conversation history ----------------------------------------

# Single-user demo conversation history. Cleared on backend restart, or when
# the user says "reset"/"clear"/"重置"/"清空".
# Each entry: {"role": "user"|"assistant", "content": "..."}.
_history: list[dict] = []
MAX_TURNS = 8  # keep last 8 user+assistant pairs (~16 messages)


def _is_reset_command(msg: str) -> bool:
    s = msg.strip().lower().rstrip('.!?。！？')
    return s in {"reset", "clear", "clear chat", "start over",
                 "重置", "清空", "清空对话", "重新开始"}


# ---------- RAG retrieval ------------------------------------------------

async def _retrieve(query: str, k: int = 3) -> list[str]:
    """Retrieve top-k most relevant NUS knowledge chunks via cosine similarity."""
    if not USE_RAG or _rag_embeddings is None or len(_rag_chunks) == 0:
        return []
    import time
    t0 = time.perf_counter()
    try:
        resp = await _embed_client.embeddings.create(model=EMBED_MODEL, input=[query])
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


# ---------- Main entry point --------------------------------------------

async def chat_with_agent(user_msg: str):
    """Async generator yielding ('TEXT', str) chunks for ADH OutsideAgent."""
    global _history

    if not LLM_API_KEY:
        env_name = _cfg["api_key_env"]
        yield ('TEXT', f"[NUS Agent] Missing {env_name} env var on the server.")
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
                "Relevant NUS knowledge retrieved for this turn. Use it to "
                "ground factual claims about programmes, campus, and "
                "descriptions. For person names, dates, fees, or details that "
                "may be outdated, cross-check against your own knowledge and "
                "hedge appropriately.\n\n"
                f"{rag_block}"
            ),
        })
    messages.extend(_history)

    full_response = ""
    try:
        stream = await _llm_client.chat.completions.create(
            model=MODEL_ID,
            messages=messages,
            temperature=0.4,
            max_tokens=120,  # bumped from 80 to leave room for hedge phrases
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
        yield ('TEXT', f"[NUS Agent] LLM error ({type(e).__name__}): {e}")
