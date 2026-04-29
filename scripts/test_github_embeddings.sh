#!/bin/bash
# Test if GitHub Models exposes Cohere embedding models we can reuse for RAG.
set -u
: "${GITHUB_TOKEN:?Set GITHUB_TOKEN env var first}"
TOKEN="$GITHUB_TOKEN"

# Try a few common embedding model IDs known to be on GitHub Models.
for MODEL in "Cohere-embed-v3-multilingual" "cohere-embed-v3-multilingual" "text-embedding-3-small" "text-embedding-3-large"; do
    echo "--- $MODEL ---"
    curl -s -X POST "https://models.inference.ai.azure.com/embeddings" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"model\":\"$MODEL\",\"input\":\"test\"}" \
        | python3 -c "import sys, json; d=json.load(sys.stdin); print('OK, dim=' + str(len(d['data'][0]['embedding'])) if 'data' in d else json.dumps(d, indent=2)[:300])"
    echo
done
