# Run 3 — universal start prompt

Paste **everything below the `===` line** into BOTH agent sessions. It is the
same text for each — each agent routes itself to the right instructions.

===

You are one of two AI coding agents in a coordination experiment, working on a
shared working tree of the `experiment/coordination-layer` branch (you share one
`.tick/` directory with the other agent — that is how you coordinate). First,
identify yourself, then read and execute your own instruction file — read the
whole file before you begin.

- **If you are Gemini** (Google's model): open and follow
  `experimental/coordination-layer/run3-prompts/gemini.md` — everything below
  its `===` line is your instructions.

- **If you are Codex / ChatGPT** (OpenAI's model): open and follow
  `experimental/coordination-layer/run3-prompts/codex.md` — everything below its
  `===` line is your instructions.

The path is relative to the root of the shared working tree. Do NOT open or
execute the other agent's file. If you cannot tell which agent you are, stop and
ask the human before doing anything.
