"""
One-shot RAG index builder for NUS digital human.

Scrapes a curated list of NUS URLs, chunks the text, embeds via GitHub Models
(text-embedding-3-small), and saves to data/nus_rag.npz for runtime retrieval.

Run inside the adh_ai_agent project:
    cd /root/work/adh_ai_agent
    GITHUB_TOKEN=ghp_xxx uv run python scripts/build_rag_index.py
"""
from __future__ import annotations
import os
import re
import sys
import time
from pathlib import Path

import numpy as np
import requests
from bs4 import BeautifulSoup
from openai import OpenAI


# Curated NUS pages. Mostly comp.nus.edu.sg + nus.edu.sg core info pages.
# Add more here over time. Pages that 403/404/timeout are skipped silently.
URLS: list[str] = [
    "https://www.nus.edu.sg/about",
    "https://www.nus.edu.sg/about/campuses",
    "https://www.comp.nus.edu.sg/about",
    "https://www.comp.nus.edu.sg/programmes",
    "https://www.comp.nus.edu.sg/programmes/ug/cs",
    "https://www.comp.nus.edu.sg/programmes/ug/is",
    "https://www.comp.nus.edu.sg/programmes/ug/bza",
    "https://www.nus.edu.sg/admissions",
    "https://www.nus.edu.sg/oam/apply-to-nus",
    "https://nus.edu.sg/osa/student-services/hostel-admission",
    "https://www.utown.nus.edu.sg/",
]

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)
OUT_PATH = DATA_DIR / "nus_rag.npz"

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0 Safari/537.36")

EMBED_MODEL = "text-embedding-3-small"
BASE_URL = "https://models.inference.ai.azure.com"


def fetch(url: str, timeout: int = 15) -> str:
    r = requests.get(url, headers={"User-Agent": UA}, timeout=timeout)
    r.raise_for_status()
    return r.text


def extract_text(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    # Drop noise
    for tag in soup(["script", "style", "nav", "footer", "header", "noscript", "form"]):
        tag.decompose()
    # Title gives valuable context for retrieval
    title = soup.title.string.strip() if soup.title and soup.title.string else ""
    text = soup.get_text(separator=" ", strip=True)
    text = re.sub(r"\s+", " ", text)
    return f"{title}\n{text}" if title else text


def chunk_text(text: str, max_chars: int = 800, overlap: int = 100) -> list[str]:
    text = text.strip()
    chunks = []
    i = 0
    while i < len(text):
        end = min(i + max_chars, len(text))
        chunk = text[i:end].strip()
        if len(chunk) >= 80:  # skip nearly-empty
            chunks.append(chunk)
        if end == len(text):
            break
        i += max_chars - overlap
    return chunks


def main() -> int:
    token = os.environ.get("GITHUB_TOKEN", "")
    if not token:
        print("ERROR: GITHUB_TOKEN env var not set.", file=sys.stderr)
        return 1

    client = OpenAI(api_key=token, base_url=BASE_URL)

    all_chunks: list[str] = []
    all_sources: list[str] = []

    for url in URLS:
        try:
            html = fetch(url)
            text = extract_text(html)
            if len(text) < 200:
                print(f"  skip (too short): {url}")
                continue
            chunks = chunk_text(text)
            all_chunks.extend(chunks)
            all_sources.extend([url] * len(chunks))
            print(f"  OK  {url} -> {len(chunks)} chunks")
        except Exception as e:
            print(f"  FAIL {url}: {e}")
        time.sleep(0.5)  # be polite to NUS servers

    if not all_chunks:
        print("ERROR: no chunks extracted, aborting.", file=sys.stderr)
        return 2

    print(f"\nEmbedding {len(all_chunks)} chunks via {EMBED_MODEL}...")
    embeddings: list[list[float]] = []
    batch_size = 16
    for i in range(0, len(all_chunks), batch_size):
        batch = all_chunks[i:i + batch_size]
        resp = client.embeddings.create(model=EMBED_MODEL, input=batch)
        embeddings.extend([d.embedding for d in resp.data])
        print(f"  batch {i//batch_size + 1}/{(len(all_chunks)-1)//batch_size + 1} done")

    arr = np.asarray(embeddings, dtype=np.float32)
    # L2-normalize for cosine similarity via dot product.
    arr /= np.linalg.norm(arr, axis=1, keepdims=True) + 1e-12

    np.savez(
        OUT_PATH,
        embeddings=arr,
        chunks=np.asarray(all_chunks, dtype=object),
        sources=np.asarray(all_sources, dtype=object),
    )
    print(f"\nSaved {len(all_chunks)} chunks ({arr.shape}) -> {OUT_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
