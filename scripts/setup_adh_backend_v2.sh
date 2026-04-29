#!/bin/bash
set -e
export PATH=/root/.local/bin:$PATH

cd /root/work/awesome-digital-human-live2d

# Remove Tsinghua mirror block from pyproject.toml (we're in Singapore, default PyPI is fine)
python3 << 'PYEOF'
from pathlib import Path
import re
p = Path("pyproject.toml")
content = p.read_text()
# Remove tsinghua index block
content = re.sub(r'\[\[tool\.uv\.index\]\]\nurl = "https://pypi\.tuna\.tsinghua[^\n]+\ndefault = true\n+', '', content)
p.write_text(content)
print(content)
PYEOF

echo "--- Reinstalling deps from default PyPI ---"
# Clean lock and re-resolve
rm -f uv.lock
uv add $(cat requirements.txt | tr '\n' ' ') 2>&1 | tail -10

echo "--- Verify imports ---"
uv run python -c "import fastapi, uvicorn, edge_tts, openai; print('FastAPI:', fastapi.__version__); print('uvicorn:', uvicorn.__version__); print('openai:', openai.__version__)"

echo "--- Backend setup complete ---"
