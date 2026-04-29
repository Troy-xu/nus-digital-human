#!/bin/bash
set -e
export PATH=/root/.local/bin:$PATH

cd /root/work/awesome-digital-human-live2d

# 1. Create config.yaml from template (idempotent)
if [ ! -f configs/config.yaml ]; then
    cp configs/config_template.yaml configs/config.yaml
    echo "Created configs/config.yaml from template"
fi

# 2. Patch config.yaml:
#    - PORT: 8880 -> 8002
#    - AGENTS SUPPORT_LIST: add outsideAgent.yaml
sed -i 's/^  PORT: 8880$/  PORT: 8002/' configs/config.yaml
# Insert outsideAgent.yaml into SUPPORT_LIST if not present
if ! grep -q '"outsideAgent.yaml"' configs/config.yaml; then
    sed -i 's|"repeaterAgent.yaml", "openaiAPI.yaml"|"repeaterAgent.yaml", "openaiAPI.yaml", "outsideAgent.yaml"|' configs/config.yaml
fi

echo "--- config.yaml AGENTS section ---"
grep -A 3 "AGENTS:" configs/config.yaml

echo "--- config.yaml PORT ---"
grep "PORT:" configs/config.yaml

# 3. Initialize uv project and add deps
if [ ! -f pyproject.toml ]; then
    uv init --quiet --no-readme --no-workspace
fi

# Pin to Python 3.10+ and add Tsinghua mirror to pyproject
python3 << 'PYEOF'
import re
from pathlib import Path
p = Path("pyproject.toml")
content = p.read_text()

# Add Tsinghua mirror at the top if not present
if "[[tool.uv.index]]" not in content:
    mirror_block = """[[tool.uv.index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true

"""
    content = mirror_block + content

# Pin Python >=3.10 if requires-python missing or too low
if "requires-python" in content:
    content = re.sub(r'requires-python\s*=\s*"[^"]+"', 'requires-python = ">=3.10"', content)

p.write_text(content)
print("pyproject.toml updated")
PYEOF

# 4. Install all requirements via uv add
echo "--- Installing requirements via uv (may take a few minutes) ---"
uv add $(cat requirements.txt | tr '\n' ' ') 2>&1 | tail -10

echo "--- Verify imports ---"
uv run python -c "import fastapi, uvicorn, edge_tts, openai; print('FastAPI:', fastapi.__version__); print('uvicorn:', uvicorn.__version__); print('openai:', openai.__version__)"

echo "--- Backend setup complete ---"
echo "Run with: cd /root/work/awesome-digital-human-live2d && uv run python main.py"
