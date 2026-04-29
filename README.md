# NUS Digital Human

A voice-first 2D real-time digital human that role-plays as an NUS (National University of Singapore) campus assistant. Ask about Computing programmes, faculties, campus locations — in **English or 中文** — and the digital human answers in voice with mouth-sync, grounded in scraped NUS Computing pages via RAG.

Built on top of [李锟's ADH fork](https://github.com/freecoinx/awesome-digital-human-live2d), with the AI Agent / RAG / ASR layers swapped for a free-tier Microsoft + Groq stack.

> Full build journal, including pitfalls and rationale, lives in [BUILD_LOG.md](BUILD_LOG.md).

## Where this is heading

This repo today is a working proof-of-concept; the longer-term direction is:

- **Kiosk deployment** — a touchscreen in NUS lobbies / open-house / library, not a personal browser tab. That implies session timeouts, privacy-by-default logging, wake-word / tap-to-start UX, and audio tuning for noisy spaces.
- **Backed by NUS AI Know** — the current self-scraped RAG (`comp.nus.edu.sg`, 24 chunks) and GitHub Models gpt-4o-mini are stopgaps. Plan is to swap both for NUS's internal AI Know RAG + chat API once integration is approved. The OutsideAgent contract is the only seam that needs to change.
- **Smarter agent loop** — currently a one-shot retrieve-then-answer. Ideas on the table: tool-using agent (web search, NUS calendar, bus times), conversation memory beyond raw turns, persona-aware Live2D customization for NUS branding.

If you've seen better frameworks for this (e.g. live2d alternatives, end-to-end voice agents like [Pipecat](https://github.com/pipecat-ai/pipecat), [Vapi](https://vapi.ai), etc.), please open an issue — we're not married to ADH.

---

## What you get

- 🎙️ **Voice in / voice out** — speak naturally; VAD auto-detects start/stop, no buttons.
- 🌐 **Bilingual** — Whisper auto-detects English and Chinese (works mid-sentence too).
- 🧠 **Multi-turn** — last 8 turns of memory; pronouns like *"there"* / *"它"* resolve correctly.
- 📚 **RAG-grounded** — answers cite scraped content from `comp.nus.edu.sg` rather than guessing.
- 🛡️ **Honest fallback** — refuses to invent fees, dates, deans; redirects to `nus.edu.sg`.
- 💰 **$0 demo cost** — runs entirely on free tiers (GitHub Models + Groq + EdgeTTS).

---

## Architecture (one paragraph)

A Windows browser hits a Next.js frontend (port 3000) running in WSL2 Ubuntu. The frontend captures mic audio, sends it to a FastAPI backend (port 8002, also in WSL2). The backend transcribes via **Groq Whisper**, then forwards the text to a custom Python agent (`adh_ai_agent.nus_agent`). That agent embeds the query via **GitHub Models text-embedding-3-small**, retrieves top-3 chunks from a local `nus_rag.npz` index, calls **GitHub Models gpt-4o-mini** with the chunks as context, and streams the response. **EdgeTTS** synthesizes the audio. The Live2D frontend syncs mouth movement to the audio.

```
Browser ──► Next.js (3000) ──► FastAPI (8002) ──► Groq Whisper        (ASR)
                                              ├──► GitHub Models       (embed + chat)
                                              └──► EdgeTTS              (TTS)
```

---

## Requirements

- **Windows 10/11** with WSL2 enabled
- **Ubuntu 22.04** WSL distro (`wsl --install -d Ubuntu-22.04`)
- A **GitHub account** with a Personal Access Token, scope: `Models: Read` ([github.com/settings/tokens](https://github.com/settings/tokens))
- A **Groq account** with an API key ([console.groq.com/keys](https://console.groq.com/keys)) — free tier is plenty
- **Chrome or Edge** browser (Web Speech / Whisper need media APIs Firefox lacks)
- ~1 GB free disk for WSL distro + `pnpm install` artifacts

> **Don't** bring up an NUS Pulse Secure VPN while bootstrapping — it kills WSL2 outbound networking.

---

## Quick start

### 1. Provision the WSL environment (one-time)

```bash
# Inside WSL Ubuntu-22.04 as root
apt update && apt install -y python3-pip python3-venv python3-dev ffmpeg git curl
curl -LsSf https://astral.sh/uv/install.sh | sh
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && apt install -y nodejs
npm install -g pnpm
```

### 2. Clone ADH and the agent (one-time)

```bash
mkdir -p /root/work && cd /root/work
git clone https://github.com/freecoinx/awesome-digital-human-live2d.git
git clone https://github.com/<your-github>/nus-digital-human.git   # this repo
```

### 3. Install agent into ADH backend (one-time)

```bash
cd /root/work
cp -r nus-digital-human/agent_template adh_ai_agent   # or follow BUILD_LOG.md to set up by hand
cd awesome-digital-human-live2d
uv pip install -e ../adh_ai_agent
```

### 4. Set your tokens (every shell, or in your dotfiles)

```bash
export GITHUB_TOKEN=ghp_xxx       # your GitHub PAT
export GROQ_API_KEY=gsk_xxx       # your Groq key
```

### 5. Build the RAG index (one-time, takes ~30s)

```bash
cd /root/work/adh_ai_agent
uv run python scripts/build_rag_index.py
```

### 6. Launch

From Windows side, double-click `start_demo.cmd`. Or from WSL:

```bash
bash /mnt/c/Users/<you>/path/to/nus-digital-human/scripts/start_all.sh
```

Then open **http://localhost:3000/sentio** in an **incognito window** (so you get the auto-defaults).

### 7. Ask away

See [demo_questions.md](demo_questions.md) for a curated 5-tier question bank (easy retrieval → guard rails → reset commands).

---

## Project layout

```
nus-digital-human/
├── README.md                 ← this file
├── BUILD_LOG.md              ← full journal: pitfalls, decisions, performance numbers
├── demo_questions.md         ← curated Q&A for live demos
├── start_demo.cmd            ← Windows double-click launcher
├── stop_demo.cmd
└── scripts/                  ← bash helpers (run inside WSL)
    ├── start_all.sh          ← bring up backend + frontend
    ├── stop_all.sh
    ├── health.sh             ← quick reachability + agent smoke test
    ├── build_rag_index.py    ← scrape NUS pages → embed → save .npz
    ├── restart_backend_only.sh
    ├── rebuild_frontend.sh
    └── test_*.sh             ← smoke tests
```

---

## Stop conditions / known limits

- nus.edu.sg main pages are JS-rendered → BeautifulSoup gets nothing → not in RAG (only `comp.nus.edu.sg` is).
- History is a single in-memory global — multi-window users will share / collide. Restart backend resets it.
- Live2D character is the default Hiyori, not NUS-themed. Customizing requires a designer + Photoshop + Live2D Editor.
- "Speak end → first audio" latency is 3–5s on free tiers. See [BUILD_LOG.md](BUILD_LOG.md#十性能数据参考) for breakdown.

---

## Contributing

PRs and issues welcome. Especially looking for help on:

- **Better speech / agent frameworks** — if you've used something that beats ADH + GitHub Models for kiosk-style voice agents, propose it. We're open to a rewrite if the gain is real.
- **Live2D model for NUS persona** — current default is the stock Hiyori character. Need a designer who can produce a Live2D model that fits NUS branding (Lion / staff / student persona).
- **Knowledge base coverage** — the RAG only covers `comp.nus.edu.sg` because `nus.edu.sg` main pages are JS-rendered. A Patchright/Playwright-based scraper (or first-class NUS AI Know integration) would broaden this.
- **Kiosk-form-factor UX** — wake-word detection, idle-timeout reset, error-state UI, telemetry.

Before opening a non-trivial PR, please skim [BUILD_LOG.md](BUILD_LOG.md) — it documents the 15 sharp edges we've already hit, plus the rationale for the current stack. Don't reintroduce solved problems.

## Credits

- [Awesome Digital Human Live2D](https://github.com/wan-h/awesome-digital-human-live2d) — Live2D + FastAPI + Next.js scaffolding by @wan-h.
- [李锟的 ADH 教程](https://gitee.com/mozilla88/adh_agent_tutorial) — the OutsideAgent pattern and overall architecture inspiration.
- [Groq](https://groq.com), [GitHub Models](https://github.com/marketplace/models), [EdgeTTS](https://github.com/rany2/edge-tts) — free-tier stack.

## License

MIT (see LICENSE if added).
