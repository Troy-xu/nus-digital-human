# NUS Digital Human — Demo Question List

Curated voice-or-text questions to showcase the NUS campus assistant. Tested
against the live agent (Groq Whisper + GitHub Models gpt-4o-mini + RAG over
24 `comp.nus.edu.sg` chunks).

The agent is `adh_ai_agent.nus_agent`. Default mode in incognito: Immersive
(VAD auto-detects speech start/end, no buttons).

---

## Tier 1 — easy English, RAG-grounded (open the demo with these)

Should produce confident, specific answers grounded in the scraped Computing
pages. Smoke-tested 2026-04-30; sample replies in `scripts/test_rag.sh`.

1. Where is NUS School of Computing located?
   _expected: Kent Ridge / COM1, COM2, COM3 buildings_
2. What undergraduate programmes does NUS Computing offer?
   _expected: CS, IS, Computer Engineering, BZA, Information Security_
3. Tell me about the BSc Computer Science programme.
   _expected: AI, software, industry collaboration emphasis_
4. What's the vision of NUS School of Computing?
   _expected: phrasing close to "unleash potential / shape the digital landscape"_
5. What does Information Systems major teach at NUS?
   _expected: integration of tech in business / IT management_

## Tier 2 — comparison / explanation (shows reasoning)

6. What's the difference between Computing and Information Systems at NUS?
7. Should a high-school student interested in AI pick CS or BZA?
8. How does NUS Computing prepare students for industry?

## Tier 3 — multi-turn (shows conversation memory + pronoun resolution)

Ask in order without resetting. The agent should resolve "they" / "it" /
"there" / "more" against earlier turns.

```
1. Where is NUS School of Computing?
2. What programmes do they offer?           ← "they" must resolve to NUS Computing
3. Tell me more about it.                    ← "it" carries the previous topic
4. How long is the programme?
5. Is it competitive to get in?              ← "it" still = the programme
```

Memory is the last 8 turns. Test the boundary by asking 9+ unrelated
questions then referring back to turn 1 — should *not* remember (this is
expected, not a bug).

## Tier 4 — Chinese / mixed-language (shows Whisper auto-detect + bilingual reply)

Whisper detects the input language; the system prompt tells the agent to
reply in the user's language. No need to flip a switch.

```
1. NUS 计算机学院有哪些本科专业？
2. CS 和 IS 这两个专业有什么区别？
3. NUS Computing 在哪个 campus？             ← mid-sentence English noun is fine
4. 国际学生申请奖学金有哪些途径？
5. Tell me about NUS 的 Computing 学院.      ← English+Chinese in one utterance
```

## Tier 5 — "I don't know" cases (shows guard rails)

These are deliberately about facts neither RAG nor LLM training data can know
reliably. The agent should admit ignorance and point at `nus.edu.sg`, NOT
fabricate.

1. What's the application fee for AY2026/27?
2. When does CourseReg open for AY2026/27 Semester 1?
3. Who is the current Dean of NUS School of Computing?
4. How many students are enrolled in NUS this year?
5. What's the dorm fee at PGP residences?

A good answer here is "I'm not sure, please check nus.edu.sg" rather than a
made-up date or number. **This is more impressive to a technical audience
than a confident wrong answer.**

## Tier 6 — control commands (shows reset)

```
1. reset                       ← English
2. clear                       ← English
3. 重置                         ← Chinese
4. 清空对话                     ← Chinese
```

Each clears the conversation history immediately and replies "Conversation
cleared. Ask me anything about NUS." Test by asking "What did I just ask?"
right after — agent should say it doesn't know.

## Tier 7 — voice-specific edge cases (only matters for live mic demo)

These exercise the voice path (VAD + Whisper) rather than the agent itself:

- **Pause mid-sentence for ~0.5s** — VAD should keep listening, not cut you off.
- **Whisper a question very softly** — VAD threshold may not trigger; useful to
  show the "Listening — speak naturally" idle state.
- **Make a non-speech noise (cough, type on keyboard)** — VAD should not
  trigger Speaking state; waveform stays empty.
- **Speak with strong background noise** — VAD may be over-aggressive; if it
  starts transcribing your background, that's a known limitation of public-
  space deployment (one of the kiosk concerns in [ROADMAP.md](ROADMAP.md)).

---

## Live demo recipe (4 minutes)

This is the path we'd recommend if you have one shot at presenting:

1. **Open** in incognito → http://localhost:3000/sentio. Wait for "Listening — speak naturally".
2. **Tier 1, q1**: "Where is NUS School of Computing?" — establishes voice + Whisper + agent + TTS all working.
3. **Tier 3 chain**: ask q1 → q2 ("What programmes do they offer?") → q3 ("Tell me more about it") — establishes multi-turn context.
4. **Tier 4, q3**: "Tell me about NUS 的 Computing 学院" — establishes mixed-language input.
5. **Tier 5, q1**: "What's the application fee?" — establishes guard rails (this is the moment a technical audience perks up — "wait, it admitted it didn't know?").
6. **Tier 6**: "reset" — establishes the control command, useful to show the team how to clear between visitors in a kiosk context.

Total ~ 8 voice exchanges. ~3 minutes of dialog + 1 minute of narration.

## Tips for the live demo

- **Browser**: Chrome or Edge, in **incognito** to skip stale localStorage.
- **Mic permission**: first load will prompt; allow it.
- **Quiet space**: VAD is more reliable away from background noise.
- **Volume**: bump up the system volume — TTS is at default loudness.
- **Speak naturally**: don't pause mid-word; do pause at the end. VAD takes
  ~500ms of silence to trigger end-of-speech.
- **Latency**: expect 3-5 seconds from "speak end" to "first subtitle char".
  Don't fill the silence yourself; let the user see the digital human "think".
- **If something fails mid-demo**: `reset` is your friend. Or open a new
  incognito window.

## Known limitations to disclose if asked

- **RAG corpus is small (24 chunks) and Computing-faculty-only.** Questions
  about admissions, hostels, food courts, scholarships fall back on LLM
  training data + guardrails ("please check nus.edu.sg"). Plan: integrate
  with NUS AI Know's RAG once available.
- **History is global and in-memory.** Multiple browser windows share the
  same conversation; backend restart wipes it. Real fix: per-visitor session.
- **Live2D character is the default Hiyori (二次元).** Not NUS-themed.
  Customizing requires a designer with Live2D Editor + Photoshop.
- **No real-time data** (current dates, live news, dorm availability).
- **English ASR is much better than Chinese ASR for proper nouns** in noisy
  environments — Whisper gets confused on ambiguous English+Chinese acronyms
  occasionally.

For a frank discussion of where this is heading and what's next, see
[ROADMAP.md](ROADMAP.md).
