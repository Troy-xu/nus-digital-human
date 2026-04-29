#!/bin/bash
# Adds RAG deps to adh_ai_agent and runs the index builder.
set -e
export PATH=/root/.local/bin:$PATH
: "${GITHUB_TOKEN:?Set GITHUB_TOKEN env var first}"; export GITHUB_TOKEN

cd /root/work/adh_ai_agent

# 1. Install RAG deps if missing
echo "--- Adding deps (numpy, requests, beautifulsoup4) ---"
uv add numpy requests beautifulsoup4 2>&1 | tail -5

# 2. Stage the build script inside the project (so it has uv-managed env access)
mkdir -p scripts
cp /mnt/c/Users/troy.xu/Downloads/AI\ Digital\ Human/nus-digital-human/scripts/build_rag_index.py scripts/

# 3. Build the index
echo "--- Running build_rag_index.py ---"
uv run python scripts/build_rag_index.py
