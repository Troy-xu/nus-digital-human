#!/bin/bash
# Legacy single-service launcher. Prefer scripts/start_all.sh in normal use.
export PATH=/root/.local/bin:$PATH
: "${GITHUB_TOKEN:?Set GITHUB_TOKEN env var first}"; export GITHUB_TOKEN
cd /root/work/awesome-digital-human-live2d
exec uv run python main.py
