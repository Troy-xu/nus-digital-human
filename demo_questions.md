# NUS Digital Human — Demo Question List

Curated questions to showcase the NUS campus assistant. Mix of English /
Chinese, factual / open-ended / "I don't know" cases.

The agent is `adh_ai_agent.nus_agent` running on top of GitHub Models
gpt-4o-mini, with a system prompt that role-plays a friendly senior NUS
student.

## Tier 1 — easy English (fact retrieval)

These should produce confident, accurate answers. Use them to open the demo.

1. Where is NUS School of Computing located?
2. What faculties does NUS have on Kent Ridge campus?
3. What are some popular majors in NUS Computing?

## Tier 2 — comparison / explanation (shows reasoning)

These show the agent reasoning, not just retrieval.

4. What's the difference between Computing and Information Systems at NUS?
5. Should I pick CS or BZA at NUS Computing?
6. How do I move between Kent Ridge and Bukit Timah campus?

## Tier 3 — Chinese (shows multi-language)

7. NUS 计算机学院的本科申请有什么要求？
8. NUS 校园里有什么好吃的食堂？推荐一下。
9. 国际学生在 NUS 申请奖学金大致有哪些途径？

## Tier 4 — "I don't know" cases (shows honesty)

These are deliberately about facts the model can't reliably know. The system
prompt instructs the agent to admit ignorance and point at official sources.

10. What is the application fee for NUS Master of Computing in 2026?
11. When does CourseReg open for AY2026/27 Semester 1?
12. Who is the current Dean of NUS School of Computing?

A good answer here is "I don't know — please check nus.edu.sg" rather than
fabricated dates / names.

## Tier 5 — out of scope (shows guardrails)

13. Can you write me a Python script to scrape job listings?
14. What's the weather in Singapore today?
15. Tell me a joke about MIT.

The agent should politely steer back to NUS topics or briefly oblige then
redirect — these are stress-tests for the persona, not core demo material.

---

## Tips for the live demo

- Start with Tier 1 to build confidence in the audience.
- Mix in Tier 3 (Chinese) to show language switching mid-conversation.
- Hit one Tier 4 question to demonstrate honest "I don't know" behavior — this
  is more impressive than a fabricated answer.
- The streaming output shows live token-by-token generation; let it finish so
  the digital human's mouth animation completes.
- Avoid Tier 5 unless you are comfortable handling odd outputs.

## Known limitations to disclose if asked

- No live data (CourseReg dates, fees, dorm availability).
- No NUS-specific RAG yet — answers come from the model's training data plus
  the system prompt.
- Voice input is not configured (default ASR points to Dify which we did not
  set up). Text input only for this demo.
- Live2D model is the stock ADH character, not a custom NUS persona.
