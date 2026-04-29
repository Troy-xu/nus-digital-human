#!/bin/bash
set -e
curl -LsSf https://astral.sh/uv/install.sh | sh 2>&1 | tail -5
export PATH=/root/.local/bin:$PATH
echo "---verify---"
uv --version
python3 --version
pip3 --version | head -1
ffmpeg -version 2>&1 | head -1
git --version
