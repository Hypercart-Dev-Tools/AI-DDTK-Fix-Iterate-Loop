# Trinity trial harness — automated multi-agent runs from the CLI

**Question this answers:** *Can the Trinity coordination layer use Gemini CLI and
Codex CLI to run automated trials, instead of a human manually coordinating agent
chat sessions in VS Code?*

**Answer: yes.** The coordination layer (`../bin/tick`) was already fully
headless. The only manual part of Runs 1–3 was *driving the agents* — pasting
prompts into VS Code chat panels and babysitting. This harness automates exactly
that: it seeds a backlog from a structured spec, runs a preflight question round,
spawns each agent CLI **headlessly and concurrently**, captures everything, and
scores the run with `tick analyze`. No human in the loop during the run.

```
spec (.md) ─▶ parse ─▶ preflight Q&A ─▶ [human gate] ─▶ seed .tick/ ─▶ spawn agents ─▶ analyze ─▶ report
              stage 1    agents ask        review &        backlog       gemini/codex/…   metrics    SUMMARY.md
              (deterministic) clarifying    answer          (isolated)    in parallel
                              questions
```

## Quick start

```bash
cd experiments/coordination-layer/harness

node bin/trial list                       # the battery of trial specs
node bin/trial doctor                     # which agent CLIs are installed
node bin/trial validate debug-calc-bugs   # parse + validate a spec

# Real run (needs gemini + codex installed with API keys):
node bin/trial run build-todo-api

# Harness self-test with the deterministic mock driver (no keys needed):
node bin/trial run build-todo-api --agents gemini:mock,codex:mock --auto
bash test/smoke.sh                        # runs the whole battery on the mock
```

## How a run works

1. **Parse + validate** the spec (`src/spec.js`) — this is the deterministic
   "stage 1" the [ingestion scaffold](../ingestion/README.md) described:
   duplicate IDs, empty scopes, non-numeric priority, dependency cycles all
   hard-fail before anything spawns.
2. **Isolated workspace** — each run gets `runs/<spec>-<ts>/workspace/`, its own
   throwaway git repo with its own `.tick/` state (`TICK_REPO_ROOT` points at
   it). The real repo's `.tick/` is never touched, so trials are safe to run
   repeatedly and in parallel.
3. **Preflight + human gate** — every agent gets a read-only prompt and may emit
   `QUESTION:` lines (or `NO_QUESTIONS`). Questions are collected to
   `preflight/QUESTIONS.md` and the run **pauses** for a human to review/answer
   by editing the spec. `--auto` skips the gate; `--skip-preflight` skips the
   round entirely.
4. **Seed** the backlog — one `tick log task.created` per task.
5. **Spawn agents concurrently** — each driver runs its CLI headlessly with the
   integration prompt (`prompts/agent-loop.md`), looping
   `tick take → work → tick done|break`.
6. **Verify + analyze** — runs the project `Verify` command, then `tick analyze`,
   and writes `report/SUMMARY.md`.

## Observability

Everything a run does is recorded so it's fully reconstructable:

| Artifact | What's in it |
|---|---|
| `run.jsonl` | structured spine — one JSON line per harness event (`seed.task`, `agent.spawn`, `agent.exit`, `verify.result`, `trial.end`, …) |
| `logs/<agent>.log` | raw stdout+stderr transcript of each agent process |
| `prompt-<agent>.md` | the exact prompt each agent received |
| `preflight/QUESTIONS.md` | clarifying questions per agent |
| `report/analyze.json` / `.md` | full `tick analyze` output (claims, dones, breaks, concurrent-claim time) |
| `report/SUMMARY.md` | human-readable verdict + per-agent table |
| `spec.json` | the parsed, resolved spec |

## The battery

| Spec | Kind | Tasks | Exercises |
|---|---|---|---|
| `build-todo-api` | build | 6 | two-half path routing (HTTP / store), claim cap |
| `build-url-shortener` | build | 4 | three-concern routing (codec / store / http), contract deps |
| `debug-calc-bugs` | debug | 2 | fix-iterate: seeded failing tests → green |
| `debug-poisoned-task` | debug | 2 | circuit-breaker: one fixable bug + one unsatisfiable task |

Debug specs carry a **Fixture** (seeded-bug code under `trials/fixtures/`) and a
per-task **Verify** command. The fixtures include a `.solutions/` dir and a
`Mock-solution:` mapping so the mock driver can drive red→green deterministically
— **real drivers ignore that field and actually debug.**

## Drivers

Headless invocation per agent (`src/drivers.js`). Flags are overridable with env
vars so you can tune them without editing code (CLIs move fast):

| Driver | Run invocation | Override env |
|---|---|---|
| `gemini` | `gemini --yolo` (prompt on stdin) | `GEMINI_CMD`, `GEMINI_ARGS` |
| `codex` | `codex exec --full-auto -` | `CODEX_CMD`, `CODEX_ARGS` |
| `claude` | `claude -p --permission-mode acceptEdits` | `CLAUDE_CMD`, `CLAUDE_ARGS` |
| `mock` | deterministic in-process stand-in | — |

`--agents id:driver,id:driver` overrides the roster, e.g.
`--agents gemini:gemini,codex:codex` for a real run, or
`--agents a:mock,b:mock` to validate the harness anywhere.

## Running for real (gemini + codex)

1. Install both CLIs and set their API keys:
   - Gemini CLI — `GEMINI_API_KEY` (or its configured auth).
   - Codex CLI — `OPENAI_API_KEY` (or its configured auth).
2. `node bin/trial doctor` — confirm both show ✅.
3. `node bin/trial run build-todo-api` — preflight pauses at the gate; review
   `preflight/QUESTIONS.md`, edit the spec if needed, then re-run with
   `--skip-preflight` (or `--auto`).
4. Read `report/SUMMARY.md`. The load-bearing metric is **concurrent-claim time**
   (target ≥ 50%, per the Run 3 success criterion in
   [`P1-TRINITY-ROUND2.md`](../../../PROJECT/2-WORKING/P1-TRINITY-ROUND2.md)).

## Adding a trial

Copy any `trials/*.project.md`, following
[`../ingestion/PROJECT-SPEC.template.md`](../ingestion/PROJECT-SPEC.template.md).
Project metadata (`**Key:** value`) goes above the first `##` heading; one
`### TASK-<ID>` block per task. For a debug trial, add a `Fixture:` dir and a
per-task `Verify:` command (plus `Mock-solution:` if you want the mock to drive
it green). `node bin/trial validate <spec>` checks it before you run.

## Limitations / honest notes

- **The mock is not a real agent.** It proves the *harness* — protocol calls,
  concurrency, observability, red→green, circuit-break — not that Gemini/Codex
  will comply with the prompt. That's still the load-bearing open question from
  the Run 1/2 retros; only a real-CLI run answers it.
- **Mock concurrent-claim time runs ~30–40%** because simulated work is fast and
  tasks are few. Real agents (minutes per task) should overlap far more; the
  metric is computed identically either way.
- **The claim lock is shared across agents** — simultaneous `tick take` calls
  collide and the loser must retry. The mock retries with backoff; the real
  agent prompt instructs the same. If real runs show this as friction, the
  Phase-2 fix is a per-agent lock or a queue.
- Single branch / single host only, same as the underlying `tick` protocol.
