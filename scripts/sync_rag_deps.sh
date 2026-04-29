#!/bin/bash
set -e
export PATH=/root/.local/bin:$PATH

echo "--- adh_ai_agent pyproject deps ---"
grep -A 10 "dependencies" /root/work/adh_ai_agent/pyproject.toml | head -15

echo "--- Re-installing adh_ai_agent into ADH backend venv (picks up new deps) ---"
cd /root/work/awesome-digital-human-live2d
uv pip install -e ../adh_ai_agent 2>&1 | tail -5

echo "--- Verify imports inside backend venv ---"
uv run python -c "import numpy, requests, bs4; print('numpy', numpy.__version__); print('requests', requests.__version__); print('bs4', bs4.__version__)"
