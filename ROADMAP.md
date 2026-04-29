# Roadmap

Where the project is headed, in priority order. **Demo today → kiosk in NUS lobbies eventually**, backed by NUS AI Know once that integration is approved. See [README.md](README.md#where-this-is-heading) for the public-facing summary.

This is a living document. If you have ideas, open an issue.

---

## Near-term (next 1-2 weeks of casual evenings)

Things that are clearly worth doing, low risk, ~hours each. Pick whichever matches your appetite.

### 1. Broaden the RAG corpus (~30 min – 2 h)

Current RAG only covers 4 pages from `comp.nus.edu.sg`. The big gap: `nus.edu.sg` main pages are JS-rendered, so `requests + BeautifulSoup` gets empty shells.

- **Quick fix (30 min)**: edit `scripts/build_rag_index.py` `URLS` list — add additional `comp.nus.edu.sg` sub-pages (research areas, faculty list, MSc programmes, etc.) that ARE static HTML.
- **Real fix (1-2 h)**: swap `requests` → `patchright` (already used by the parent ADH course) to handle JS rendering. This unlocks `nus.edu.sg/admissions`, `nus.edu.sg/osa/student-services/hostel-admission`, the academic calendar, and most other deep NUS pages.
- **Maintenance**: NUS pages change. Suggest re-running `build_rag_index.py` once a quarter. Stale chunks → wrong answers.

### 2. Idle-timeout reset (~1 h)

Today the conversation history is one global variable. In a kiosk, when one visitor leaves and another arrives, they'll see each other's turns. Fix:

- Frontend: track last user activity timestamp; after 60s idle, send a synthetic `reset` to the backend.
- Backend: nothing changes — it already accepts the reset command.
- Bonus: also clear the chat record bubble on the screen so the next visitor sees a clean slate.

### 3. Telemetry skeleton (~2 h)

A kiosk product needs to justify itself. Even basic counts help:

- Anonymous: visitor count, average session length, popular topics (cluster by retrieved chunk?), latency p50/p95, error rate.
- Don't log full transcripts (PII); log only metadata.
- Simplest sink: a sqlite file at `data/telemetry.db`. Or post to a single-row Google Sheet. Don't over-engineer.

### 4. Better error UX (~2 h)

Today an API failure mid-stream just prints `[NUS Agent] LLM error: ...` in the chat. In a kiosk:

- Show a friendly "I'm having trouble — please try again" state on the screen.
- Backend retries the LLM call once with exponential backoff before giving up.
- If GitHub Models is rate-limited, we should know (log + maybe a status indicator).

### 5. NUS-themed Live2D mood lighting (~1 h)

You don't need a custom Live2D model to look more NUS-y. Quick wins:

- Change the background image (`web/public/sentio/backgrounds/`) to NUS Kent Ridge skyline / SoC building.
- Tweak the chat bubble color to NUS orange (`#EF7C00` brand color).
- Add a small NUS lion logo in the corner.

These are all `web/public/` + `tailwind.config.ts` changes. No model swap needed.

---

## Mid-term (next 1-2 months)

Bigger design decisions. Worth thinking about before committing.

### 6. Custom Live2D NUS persona (1-2 weeks of designer time, ~$300-1000)

If we want this in a public lobby, the default Hiyori (anime schoolgirl) is wrong. Options:

- **Hire a Live2D designer** (B站、ArtStation、Fiverr) to build an NUS-staff or NUS-student character. Budget the time for back-and-forth.
- **Use NUS Lion mascot** as a stylized Live2D character (closer to招行小招喵). Plays well in marketing materials too.
- **Cartoon variant** of a generic helpful assistant, dressed in NUS colors.

Whichever, you'll need a designer who's worked with Live2D Editor before (it's not Photoshop — has its own learned-it-once skill).

### 7. Wake-word or tap-to-start (1-2 days)

Always-on VAD breaks down in noisy public spaces. Two options:

- **Wake word**: "Hi NUS" or similar. Free options: Picovoice's [Porcupine](https://picovoice.ai/platform/porcupine/) is the gold standard. Custom wake word costs ~$20/mo.
- **Tap-to-start**: simpler. Big "Talk to me" button on the kiosk; press it to start a conversation, idle screen otherwise. UX feels less magical but is robust.

### 8. NUS AI Know integration (depends on NUS infra team)

The big strategic swap. Today we self-host a 24-chunk RAG + call GitHub Models. Once NUS AI Know is available, swap:

- Replace `_retrieve()` in `nus_agent.py` with a call to NUS AI Know's RAG endpoint.
- Replace the `client.chat.completions.create()` in `chat_with_agent()` with NUS AI Know's chat API (likely OpenAI-compatible? confirm with their team).
- Likely need NUS SSO instead of static token. Adds an auth middleware to consider.
- Our `build_rag_index.py` becomes a fallback for offline / unavailable scenarios.

**Things to ask NUS AI Know team early**:
- API spec / OpenAPI doc?
- Auth model (SSO? service token? both?)
- Rate limits — what's reasonable for a kiosk doing ~1 call per visitor question?
- Citations — does it return source URLs? (Useful for "where did you see this?" follow-ups.)
- Update frequency — how stale can the knowledge be?
- Failure semantics — what error codes, how to fall back?

### 9. Tool-use / function-calling agent (1 week)

Move from one-shot RAG-then-answer to a true agent that decides when to:

- Search NUS AI Know vs use cached knowledge
- Look up the academic calendar / NUS bus schedule (real-time)
- Hand off to a human ("contact registrar" with a one-click link)

OpenAI Agents SDK supports this pattern; we already use the OpenAI SDK so the gap is small. Tradeoff: latency goes up because the agent does an extra "decide which tool" round trip.

---

## Long-term (3+ months / strategic options)

These are big bets. Need a real conversation before committing.

### 10. Framework re-evaluation

ADH was a fine starting point but wasn't designed for kiosk. Worth surveying alternatives:

- **[Pipecat](https://github.com/pipecat-ai/pipecat)** (Daily.co's open-source voice agent framework) — purpose-built for low-latency voice pipelines. Native VAD + STT + LLM + TTS + interrupt handling. **Likely candidate**.
- **[LiveKit Agents](https://github.com/livekit/agents)** — similar space, real-time-comm-native. Heavier but production-ready.
- **[Vapi](https://vapi.ai)** — managed service, less DIY but you trade flexibility for support. May make sense if NUS doesn't want to maintain infra.
- **[Retell AI](https://retellai.com)** — also managed. More phone-call oriented but kiosk-adjacent.

The honest test: if we redo this in Pipecat over a weekend, is the agent meaningfully smarter / more responsive? If yes, swap. If no, stay with ADH (sunk cost shouldn't decide, but neither should novelty).

### 11. 3D digital human

李锟 course discusses this trade-off at length. 3D (Nvidia ACE, Unreal MetaHuman) looks more impressive but eats GPU at runtime, hard on low-end kiosks. 2D Live2D scales to dirt-cheap hardware.

**Recommendation: stick with 2D until NUS gives you a kiosk hardware spec.** If the kiosk has GPU and the audience is open-house wow-factor not daily-use, revisit.

### 12. Voice cloning for a "named" NUS persona

If NUS has a beloved figure (a long-standing dean, a mascot voice) that students recognize, having the digital human speak in that voice creates a much stronger emotional connection than generic EdgeTTS. ElevenLabs / Resemble / Coqui can clone a voice from ~5 minutes of clean audio.

**Caveat**: voice rights / IP / consent need to be cleared properly. NUS Comms / Legal should be in the loop.

### 13. Multi-turn → multi-modal

Today voice in / voice out. A kiosk can also support:

- **Touch input** for the user who'd rather read and tap than speak (privacy in public).
- **QR code output** when the answer involves a URL (e.g. "scan to apply" → user pulls out phone).
- **Camera input** (with consent) for face-detection wake or for accessibility.

---

## Things I deliberately don't recommend (and why)

- **Don't switch LLM to Claude / Anthropic** for this project — GitHub Models has gpt-4o-mini for free and the quality is fine. Save the spend.
- **Don't host your own Whisper** — Groq's free tier is faster than CPU-bound local Whisper, and reliable. Self-host only if you can't get internet at the kiosk.
- **Don't over-engineer the RAG** — 24 chunks works fine for the demo. Vector DBs / hybrid retrieval / re-ranking is solving problems we don't have. Solve them when corpus grows past ~1000 chunks.
- **Don't build a custom ASR** — solved problem; using a vendor (Groq, Whisper API) is the correct decision.
- **Don't ship to production without rotating the demo tokens** — `git log` will eventually show them if a contributor digs around. The leaked tokens are in chat logs separately.

---

## Open questions for NUS team

When integration meetings start, ask these specifically. They unblock the biggest decisions.

1. Does NUS AI Know's API expose a streaming chat endpoint (SSE / chunked)?
2. Does it return source citations or just raw text?
3. Auth: SSO redirect, or service-account token? If SSO, what's the kiosk identity model?
4. Rate limits and cost model.
5. Data privacy stance — can we log queries for telemetry, or is that a non-starter?
6. Hardware spec for the planned kiosk — Windows mini-PC? Android tablet? Custom?
7. Network constraints — does the kiosk get a public internet egress, or only NUS-internal? (This decides whether GitHub Models / Groq are even reachable.)

---

If you're a contributor reading this, the highest-leverage near-term task to pick up is probably **#1 (broaden RAG)** — concrete, scoped, immediately makes the demo more impressive. The biggest open question is **#10 (framework re-evaluation)** — input on whether Pipecat or LiveKit beats ADH would be very welcome.
