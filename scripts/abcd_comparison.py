"""
6-way comparison: 6 model+RAG configs answering same 7 NUS demo questions.

Configs A-D: gpt-4o-mini / gpt-4o on GitHub Models, RAG on/off.
Config  E:   Groq Llama-3.3-70B + RAG  (super fast, multilingual).
Config  F:   Cohere Command R+ + RAG   (RAG-native, citation-friendly).

Embeddings always come from GitHub Models text-embedding-3-small so RAG
quality is constant across configs — we're only varying the LLM.

Run inside the adh_ai_agent uv project:
    cd /root/work/adh_ai_agent && uv run python /tmp/abcd.py
"""
import os
import time
from pathlib import Path

import numpy as np
from openai import OpenAI


GH_TOKEN = os.environ["GITHUB_TOKEN"]
GROQ_KEY = os.environ.get("GROQ_API_KEY", "")

# Two clients: one for GitHub Models (most configs + embeddings), one for Groq.
gh_client = OpenAI(api_key=GH_TOKEN, base_url="https://models.inference.ai.azure.com")
groq_client = OpenAI(api_key=GROQ_KEY, base_url="https://api.groq.com/openai/v1") if GROQ_KEY else None


RAG_PATH = Path("/root/work/adh_ai_agent/data/nus_rag.npz")
_rag = np.load(RAG_PATH, allow_pickle=True)
EMB = _rag["embeddings"]
CHUNKS = _rag["chunks"].tolist()
print(f"RAG loaded: {len(CHUNKS)} chunks")

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
  numbers, names of specific people), say "I'm not sure, please check
  nus.edu.sg" — do not invent. Treat retrieved RAG context as background
  information, NOT as authoritative for person names or dates.
- Reasonable defaults: NUS Computing is at Kent Ridge (COM1/COM2/COM3);
  NUS has Kent Ridge, Bukit Timah, and Outram campuses.

Tone: warm and helpful, like a senior student in conversation.
"""

QUESTIONS = [
    ("RAG-grounded", "Where is NUS School of Computing located?"),
    ("RAG-grounded", "What undergraduate programmes does NUS Computing offer?"),
    ("Reasoning",    "What's the difference between Computing and Information Systems at NUS?"),
    ("RAG-phrasing", "What is the vision of NUS School of Computing?"),
    ("Guard rail",   "What's the application fee for the AY2026/27 Master of Computing?"),
    ("Guard rail",   "Who is the current Dean of NUS School of Computing?"),
    ("Mixed lang",   "Tell me about NUS 的 Computing 学院."),
]

# Each config: (label, provider, model_id, use_rag)
CONFIGS = [
    ("A", "gh",   "gpt-4o-mini",                True),
    ("B", "gh",   "gpt-4o-mini",                False),
    ("C", "gh",   "gpt-4o",                     False),
    ("D", "gh",   "gpt-4o",                     True),
    ("E", "groq", "llama-3.3-70b-versatile",    True),
    ("F", "gh",   "Cohere-command-r-plus-08-2024", True),
]


def retrieve(query, k=3):
    # Embeddings always via GitHub Models for consistency.
    resp = gh_client.embeddings.create(model="text-embedding-3-small", input=[query])
    q = np.asarray(resp.data[0].embedding, dtype=np.float32)
    q /= np.linalg.norm(q) + 1e-12
    sims = EMB @ q
    top_idx = np.argsort(-sims)[:k]
    return [CHUNKS[i] for i in top_idx]


def ask(question, provider, model, use_rag):
    if provider == "groq" and groq_client is None:
        return "<SKIP: GROQ_API_KEY not set>", 0.0

    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    if use_rag:
        retrieved = retrieve(question)
        rag_block = "\n\n".join(f"- {c}" for c in retrieved)
        messages.append({
            "role": "system",
            "content": (
                "Relevant NUS knowledge retrieved for this turn. Use it to "
                "ground factual claims about programmes, campus, and "
                "descriptions. But for person names, dates, fees, or other "
                "details that may be outdated, still admit uncertainty.\n\n"
                f"{rag_block}"
            ),
        })
    messages.append({"role": "user", "content": question})

    client = groq_client if provider == "groq" else gh_client
    t0 = time.perf_counter()
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=0.4,
            max_tokens=80,
        )
        text = (resp.choices[0].message.content or "").strip()
    except Exception as e:
        text = f"<ERROR: {type(e).__name__}: {str(e)[:160]}>"
    elapsed = time.perf_counter() - t0
    return text, elapsed


def main():
    for category, q in QUESTIONS:
        print(f"\n{'=' * 78}\n[{category}] Q: {q}\n{'-' * 78}")
        for label, provider, model, use_rag in CONFIGS:
            text, elapsed = ask(q, provider, model, use_rag)
            rag_tag = "RAG" if use_rag else "no-"
            tag = f"{label} | {provider:4s} | {model[:32]:32s} | {rag_tag} ({elapsed:5.2f}s):"
            print(tag)
            wrap_at = 110
            line = ""
            for word in text.split():
                if len(line) + len(word) + 1 > wrap_at:
                    print(f"   {line}")
                    line = word
                else:
                    line = (line + " " + word).strip()
            if line:
                print(f"   {line}")


if __name__ == "__main__":
    main()
