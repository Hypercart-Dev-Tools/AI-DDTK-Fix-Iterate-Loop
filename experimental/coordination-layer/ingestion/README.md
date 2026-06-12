# Task ingestion layer (SCAFFOLD)

> **Status: scaffold only.** Captured 2026-05-14 so the idea isn't lost.
> **NOT wired into Trinity Run 2** — Run 2 still seeds `.tick/events/` by hand
> via `tick log task.created`. This layer is a deliberate future step.

## The idea

Today the coordination layer starts at the JSON event log: someone hand-writes
`tick log task.created ...` calls to seed tasks. That is error-prone and not
reviewable — there is no human-readable artifact between "we want to build X"
and "here are 6 JSON task events with path scopes and priorities."

This layer adds the missing top tier:

```
human-authored project spec (.md)        <- a person writes and reviews this
        |
        v
   ingest.js  (hybrid pipeline)
   |- 1. deterministic parse        — extract structure, validate required fields
   |- 2. LLM review + orchestrate   — check scope overlap, sizing, deps, gaps;
   |                                  suggest ordering / half-assignment
   |- 3. human gate                 — surface issues; human edits .md, re-runs
        |
        v
  .tick/events/*.jsonl  task.created events   <- what the agents actually consume
```

The point: a human writes and signs off on a *readable* project breakdown, and
a deterministic + LLM-assisted script turns it into the machine task list —
instead of someone hand-authoring JSON events with no review surface.

## Files in this scaffold

- `PROJECT-SPEC.template.md` — the human-authored format. Copy, fill in, review.
- `examples/todo-api.project.md` — a filled-in example (the Run 2 app, for illustration only — NOT Run 2's actual seed input).
- `ingest.js` — STUB converter. Pipeline stages are documented but not implemented.

## Pipeline stages (design intent)

### 1. Deterministic parse
Pure, no LLM. Read the spec markdown, extract project metadata and each
`### TASK-*` block into structured objects. Hard-fail on: missing required
fields, duplicate task IDs, empty path scopes, non-numeric priority,
dependency cycles. Deterministic — the same `.md` always yields the same parse.

### 2. LLM review + orchestrate
Send the parsed structure to an LLM with a review prompt. It judges what a
parser can't: are two tasks' path scopes overlapping when they shouldn't be?
Is a task too large to be one claim? Are acceptance criteria testable? Are
there coverage gaps? It may also *orchestrate* — suggest task ordering,
half-assignment, or priority adjustments. Output: approved, or a list of
issues + suggestions. **The LLM advises; it does not have final say.**

### 3. Human gate
If stage 1 or 2 flags anything, surface it and stop. The human edits the spec
`.md` and re-runs. Only a clean, human-approved pass emits events. The human
is always the final reviewer — deterministic checks and LLM review both just
inform the decision.

### Emit
On a clean, human-approved pass: write `task.created` JSONL events into
`.tick/events/` (or an intermediate reviewable `tasks.json` + a `tick log`
script — decide at implementation time; see open questions).

## Open questions (resolve when this graduates from scaffold)

- Does `ingest.js` write `.tick/events/` directly, or emit an intermediate
  reviewable `tasks.json` that a human then feeds to `tick log`?
- "Orchestrate" — how far does the LLM go? Review-only, or also assign agents
  to halves and sequence dependencies?
- Which LLM / how is it invoked? (Anthropic SDK, with prompt caching.)
- Does the human gate run in-terminal, or produce a diff / PR for review?
- Where does this sit in the P1-TRINITY phase plan — Phase 1.5, or Phase 2?
