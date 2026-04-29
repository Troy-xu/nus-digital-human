# `agent/` — code that lives outside this repo at runtime

These files are the canonical version of the code that gets installed into a
fresh ADH (Awesome Digital Human Live2D) deployment. They aren't directly
runnable from this repo — they need to be copied into the right places inside
the ADH project tree.

## Files

| File | Where it goes at runtime |
|---|---|
| `nus_agent.py` | `<adh_ai_agent project>/adh_ai_agent/nus_agent.py` |
| `whisperASR.py` | `<ADH backend>/digitalHuman/engine/asr/whisperASR.py` |
| `whisperAPI.yaml` | `<ADH backend>/configs/engines/asr/whisperAPI.yaml` |

`<ADH backend>` is wherever you cloned `awesome-digital-human-live2d`, e.g. `/root/work/awesome-digital-human-live2d/`.
`<adh_ai_agent project>` is the sibling Python project we install editable into the ADH backend's venv, e.g. `/root/work/adh_ai_agent/`.

## Manual installation (one-time)

If you've never set this up before:

```bash
# 1. Bring up the ADH project + a sibling adh_ai_agent project with deps
cd /root/work
git clone https://github.com/freecoinx/awesome-digital-human-live2d.git
git clone https://github.com/Troy-xu/nus-digital-human.git   # this repo
uv init adh_ai_agent
cd adh_ai_agent
# In its pyproject.toml add: [tool.setuptools] packages = ["adh_ai_agent"]
uv add openai numpy requests beautifulsoup4
mkdir -p adh_ai_agent data scripts

# 2. Copy the canonical agent code into adh_ai_agent
cp /root/work/nus-digital-human/agent/nus_agent.py adh_ai_agent/
touch adh_ai_agent/__init__.py
cp /root/work/nus-digital-human/scripts/build_rag_index.py scripts/

# 3. Copy the Whisper engine into ADH backend
cp /root/work/nus-digital-human/agent/whisperASR.py /root/work/awesome-digital-human-live2d/digitalHuman/engine/asr/
cp /root/work/nus-digital-human/agent/whisperAPI.yaml /root/work/awesome-digital-human-live2d/configs/engines/asr/

# 4. Patch ADH's ASR registry to import the new engine
# Edit /root/work/awesome-digital-human-live2d/digitalHuman/engine/asr/__init__.py
# Add: from .whisperASR import WhisperApiAsr

# 5. Patch ADH's master config to default to Whisper + OutsideAgent
# Edit /root/work/awesome-digital-human-live2d/configs/config.yaml
# Under SERVER.ENGINES.ASR:
#     SUPPORT_LIST: ["whisperAPI.yaml", ...]
#     DEFAULT: "whisperAPI.yaml"
# Under SERVER.AGENTS:
#     SUPPORT_LIST: ["outsideAgent.yaml", ...]
#     DEFAULT: "outsideAgent.yaml"

# 6. Patch outsideAgent's required field + default agent_module
# Edit /root/work/awesome-digital-human-live2d/configs/agents/outsideAgent.yaml
# - agent_type: change required: true -> required: false
# - agent_module: change default: "" -> default: "adh_ai_agent.nus_agent"

# 7. Patch frontend defaults (optional but recommended)
# Edit /root/work/awesome-digital-human-live2d/web/lib/constants.ts
#   SENTIO_CHATMODE_DEFULT = PROTOCOL.CHAT_MODE.IMMSERSIVE   # was DIALOGUE
# Edit /root/work/awesome-digital-human-live2d/web/app/(products)/sentio/components/chatbot/input.tsx
# (See ../BUILD_LOG.md §"VAD waveform gating" for the exact diff)

# 8. Wire adh_ai_agent into ADH backend's venv as editable
cd /root/work/awesome-digital-human-live2d
uv pip install -e ../adh_ai_agent

# 9. Build the RAG index (needs GITHUB_TOKEN)
cd /root/work/adh_ai_agent
GITHUB_TOKEN=ghp_xxx uv run python scripts/build_rag_index.py

# 10. Build the frontend
cd /root/work/awesome-digital-human-live2d/web
pnpm install && pnpm run build
```

After all this, run `bash /root/work/nus-digital-human/scripts/start_all.sh`
(after exporting `GITHUB_TOKEN` and `GROQ_API_KEY` first).

## Why these aren't auto-installed

ADH is a third-party project we don't fork into this repo (we use upstream + 李锟's
fork as-is). Patching it requires touching its files in place. We chose this
approach over forking ADH because:

- We track only our own additions, not all of ADH.
- Upstream improvements to ADH are easy to pull (we don't carry a fork burden).
- Trade-off: a fresh contributor has 8-9 manual steps to set up — documented above.

Future improvement: a single `bootstrap.sh` that automates steps 2-10. Listed in [../ROADMAP.md](../ROADMAP.md) under Near-term polish.
