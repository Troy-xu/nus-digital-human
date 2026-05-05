#!/bin/bash
# Wrapper to run abcd_comparison.py inside the adh_ai_agent venv.
# Reads abcd_comparison.py from /tmp/abcd.py (caller piped it in earlier).
set -e
export PATH=/root/.local/bin:$PATH
cd /root/work/adh_ai_agent
exec uv run python /tmp/abcd.py
