# NUS Digital Human — Product Brief

**A voice-first AI campus assistant for NUS. Speaks. Listens. Remembers. Free to run.**

---

## What it is

A 2D animated digital human that prospective students, current students, and campus visitors can simply *talk to* about NUS — programmes, faculties, campus locations, services. Replies come in voice, with synced mouth animation, in the language the visitor used.

Think of it as the AI receptionist at a tech-forward university: deployed once on a kiosk in a lobby, available 24/7, never tires of answering the same admissions question for the fiftieth time.

This is a working proof-of-concept toward an NUS-deployed kiosk product.

## Why this matters

Every year NUS handles tens of thousands of recurring information requests — "Where is the Computing building?", "What's the difference between CS and Information Systems?", "How do I apply as an international student?" Today these go through human staff at information counters, email helpdesks, or scattered web pages.

A voice-first kiosk fills the gap:

- **Always-on** — open-house weekends, evenings, holidays.
- **Patient** — every visitor gets the same polite, complete answer.
- **Multilingual** — built for a campus where over a third of students speak English as a second language.
- **A welcoming first impression** that isn't a static FAQ board on a wall.

## What it can do today

Walk up, speak. The system will:

- **Detect when you start and stop talking** automatically — no buttons, no wake word, no app to launch.
- **Transcribe in English, 中文, or a mix of both** — it handles *"Tell me about NUS 的 Computing 学院"* as a single sentence.
- **Answer in 1–2 spoken sentences**, grounded in official NUS Computing pages it has read in advance.
- **Remember the last several turns** — you can say *"tell me more about it"* without re-explaining what *it* refers to.
- **Honestly admit uncertainty** — for things it can't know reliably (current fees, dates, the current dean), it points you to nus.edu.sg rather than fabricating an answer.
- **Reset on command** — say *"reset"* or *"重置"* and the next visitor starts a fresh conversation.

The character animates in real time: blinks, tracks the cursor, opens its mouth in time with the voice.

## See it for yourself — 4-minute live demo

Suggested presentation flow:

1. **Open the page.** Speak: *"Where is NUS School of Computing?"* → it names Kent Ridge campus, the COM1/COM2/COM3 buildings.
2. *"What undergraduate programmes do they offer?"* → lists Computer Science, Information Systems, Computer Engineering, Business Analytics, Information Security. (Notice that *"they"* was resolved correctly to NUS Computing.)
3. *"Tell me more about Computer Science."* → continues with specifics.
4. Switch language mid-conversation: *"Tell me about NUS 的 Computing 学院."* → answers in mixed English-Chinese, language detected automatically.
5. *"What's the application fee for AY2026?"* → it says *"I'm not sure, please check nus.edu.sg."* (This admission of uncertainty is a feature, not a bug — and the moment a technical audience tends to nod.)
6. *"Reset."* → conversation cleared, ready for the next visitor.

Eight short exchanges. Three minutes of dialog. One minute of pre- and post-commentary.

## How it compares

| | This | Static FAQ page | ChatGPT | Human staff |
|---|---|---|---|---|
| **Voice in / out** | ✅ | ❌ | partial | ✅ |
| **NUS-grounded answers** | ✅ | ✅ | ❌ generic | ✅ |
| **Multilingual auto-detect** | ✅ | ❌ | ✅ | partial |
| **Conversational memory** | ✅ | ❌ | ✅ | ✅ |
| **Available 24/7** | ✅ | ✅ | ✅ | ❌ |
| **Cost per conversation** | ~$0 | $0 | $$ | $$$$ |

The point isn't to replace human staff — it's to absorb the repetitive long-tail of factual questions so staff can focus on the conversations that need a human.

## Where this is heading

The current build is a free-tier proof-of-concept. The intended trajectory:

1. **Integration with NUS AI Know.** The current build maintains its own small knowledge base scraped from public NUS pages. Once integrated with NUS's internal AI service, answers will stay current and authoritative without a maintenance burden on us.
2. **Kiosk deployment.** Move from "browser tab" to a touchscreen unit in a lobby, with idle-timeout reset, anonymized telemetry, and audio tuning for noisy public spaces.
3. **NUS-themed character.** A custom Live2D persona — possibly an NUS Lion, possibly a stylized senior student — to replace the generic stock character used today.
4. **Smarter conversations.** Tool-using agent that can look up real-time data (bus schedules, building hours, the academic calendar) rather than only relying on cached pages.

Several universities have begun deploying similar AI kiosks. This is a credible attempt at one tuned specifically for NUS, with deployable cost economics from day one.

## Footnote — how it works under the hood

Voice in → automatic speech recognition (Whisper, multilingual) → retrieval-augmented generation grounded in scraped NUS Computing pages → conversational LLM (GPT-4o-mini) → text-to-speech (Microsoft Edge TTS) → Live2D mouth-sync animation. Built on the open-source [Awesome Digital Human](https://github.com/wan-h/awesome-digital-human-live2d) framework. Source code, full architecture notes, and roadmap on GitHub.

## Links

- **Repository:** https://github.com/Troy-xu/nus-digital-human
- **Roadmap & open questions for the NUS AI Know team:** [ROADMAP.md](ROADMAP.md)
- **Build journal & technical pitfalls:** [BUILD_LOG.md](BUILD_LOG.md)
- **Demo question bank:** [demo_questions.md](demo_questions.md)

---

*Built April 2026 by Troy Xu. Open to collaboration — particularly on NUS-themed character design, broader knowledge coverage, and kiosk-form-factor UX.*
