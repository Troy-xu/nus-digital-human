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
    "github": {
        "base_url": "https://models.inference.ai.azure.com",
        "api_key_env": "GITHUB_TOKEN",
        "default_model": "gpt-4o",
    },
    "groq": {
        "base_url": "https://api.groq.com/openai/v1",
        "api_key_env": "GROQ_API_KEY",
        "default_model": "llama-3.3-70b-versatile",
    },
    "openai": {
        "base_url": "https://api.openai.com/v1",
        "api_key_env": "OPENAI_API_KEY",
        "default_model": "gpt-4o",
    },
}

# Default = GitHub Models gpt-4o. Slower than Groq Llama (~1.5s vs 0.5s) but
# follows the hedge-style prompt instructions more reliably and answers
# general-knowledge questions (e.g. "who is the President of the US") that
# Llama-70B sometimes refuses or mangles. Set LLM_PROVIDER=groq to swap back
# to the fast Llama path.
LLM_PROVIDER = os.environ.get("LLM_PROVIDER", "github").lower()
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
- Match answer length to question complexity:
    * Greetings / yes-no / one-word acks ("ok", "thanks", "你好"): 1 short sentence.
    * Quick facts ("Where is X?", "What time is the library open?"): 2-3 sentences.
    * Comparisons, explanations, recommendations: 3-5 sentences with real info.
    * Detailed instructions / multi-step: up to ~120 words, still spoken-style.
  Pack real information, not filler. Never essay-length.
- No bullet points, no numbered lists, no markdown, no headings.
- No "Sure!", "Great question!", or other filler openers.
- Reply in the language the user uses (English or 中文). If the user mixes
  English and Chinese in one message, you can mix too.

Greeting behavior:
- If the user opens with "hi" / "hello" / "你好" / "hey": respond with a
  warm 1-sentence welcome that names you as an NUS campus assistant and
  invites them to ask. Example: "Hi! I'm your NUS campus assistant —
  ask me anything about programmes, campus, or admissions."
- Don't greet again on subsequent turns — get straight to the answer.

Answer-format rules — follow these patterns:

Q: "Where is NUS School of Computing?"
✓ "NUS School of Computing is at Kent Ridge campus, in the COM1, COM2, and
   COM3 buildings on the southern side of campus, just a short walk from
   Kent Ridge MRT. It's the heart of computing research and teaching at NUS."
(Confident facts about campus: state directly, give helpful context.)

Q: "What undergraduate programmes does NUS Computing offer?"
✓ "NUS Computing offers six undergraduate degrees: Computer Science,
   Information Systems, Computer Engineering, Business Analytics, Information
   Security, and Artificial Intelligence. The Bachelor of Computing is the
   umbrella programme covering most of these tracks."
✗ "We offer several, including Computer Science and a few others." (lazy
   summarising — when the user asks for a list, ENUMERATE everything you
   know, don't abridge.)
RULE: For "what X does Y offer / have / include" questions, list ALL
items in the answer. Brevity for listings means dropping context, not items.

Q: "Who is the Dean of NUS Computing?"
✓ "Professor Tulika Mitra, as of my last info — she's been with NUS Computing
   for years and was previously a Provost's Chair Professor. Please verify the
   current role on nus.edu.sg, since deans rotate periodically."
✗ "I'm not sure." (don't refuse if you have a plausible name)
✗ "Tulika Mitra." (don't drop context or the verify caveat)

Q: "Who is the President of the United States?"
✓ "Donald Trump, as of my last info — he began his second term in January
   2025 after defeating Kamala Harris in the 2024 election. Please verify on
   a news site for the latest."
✗ "I'm not sure, I'm with NUS in Singapore." (don't deflect general-knowledge questions)

Q: "What's the application fee for AY2026/27?"
✓ "I'm not sure of the exact fee — application fees change each cycle and
   vary by programme, so please check the latest figures on nus.edu.sg under
   Admissions. The Office of Admissions can confirm exact amounts."
(Specific numerical values: refuse the number, but still be helpful about where to find it.)

Reasonable defaults you can state confidently:
- NUS Computing is at Kent Ridge campus (COM1/COM2/COM3 buildings).
- NUS has Kent Ridge, Bukit Timah, and Outram campuses.
- NUS Computing offers BSc Computer Science, BSc Information Systems,
  BEng Computer Engineering, BSc Business Analytics, BSc Information Security,
  and BSc Artificial Intelligence as undergraduate programmes.
- The School of Computing was established in 1998, growing out of the
  Department of Computer Science (founded in 1975).

Treat retrieved RAG context as supporting material, not as authoritative for
time-sensitive facts (current Dean, current fees, current deadlines).

Tone: warm and helpful, like a senior student giving a campus tour.
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
            max_tokens=220,  # bumped to allow 2-4 substantive sentences with hedges
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
