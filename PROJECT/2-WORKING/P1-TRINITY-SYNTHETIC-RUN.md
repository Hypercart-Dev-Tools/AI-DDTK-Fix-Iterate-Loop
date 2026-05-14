# Trinity — Synthetic parallelism run (Run 2)

**Parent:** [`P1-TRINITY.md`](P1-TRINITY.md)
**Branch:** `experiment/coordination-layer`
**Owner:** Noel / Hypercart
**Coordinator:** Claude Code (orchestrator — observes, does not claim or code)
**Agents:** 2 of {Codex, Gemini} — the peers doing the work
**Status:** Planned. Not started.

---

## Why this run exists

Run 1 (2026-05-06) was the first real-agent hand-test. It failed in an instructive way:

- Gemini claimed **all 3 seeded tasks** in 33 seconds (TASK-A, TASK-B, TASK-C), starving Codex completely.
- Codex behaved correctly — claimed, lost the deterministic tie-breaker twice, auto-released both times, then stood down when `tick next` returned `(no available task)`.
- Gemini then crashed with **zero work commits**, leaving all 3 tasks stuck in `claimed` state with no liveness mechanism to recover them.
- Net code output: nothing.

Three protocol gaps surfaced:

1. **No per-agent claim cap** — a fast claimant monopolizes the backlog.
2. **No liveness / TTL on claims** — a crashed claimer leaves stuck claims no peer can pick up.
3. **Self-overlapping claims allowed** — Gemini claimed TASK-C while holding TASK-A (both touched `tools/servers-audit.sh`); path-routing only filters `tick next`, it does not refuse a self-stacking claim.

This run targets gap #1 directly. The question it answers: **with a claim cap in place, will two agents sustain parallel work on separate parts of a real app — or does the protocol still collapse to one agent?** Gaps #2 and #3 are noted but out of scope for Run 2 (see Non-goals).

The test goal is **sustained parallelism, not throughput.** Success is two agents each making steady progress on their own half — *not* one agent finishing all 6 tasks fast.

---

## Prerequisite — implement the claim cap

This must land before the run. It is a small change to the existing `tick` CLI; the coordinator (or Noel) implements it, commits it, and the agents pull it before starting.

**Rule:** an agent may hold at most **2 active claims** at any time. "Active" = claimed and not yet released, done, or circuit-broken.

Constant: `MAX_ACTIVE_CLAIMS_PER_AGENT = 2` (hardcoded for this run; a config knob is Phase 2).

Two enforcement layers:

1. **`tick next` gate** ([`src/next.js`](../../experiments/coordination-layer/src/next.js)) — before returning a new task, count the requesting agent's active claims. If `>= 2`, return `(claim limit reached — finish or release a task first)` instead of a new task ID.
2. **`tick claim` refusal** ([`src/claim.js`](../../experiments/coordination-layer/src/claim.js)) — before writing the `task.claimed` event, count the requesting agent's active claims. If `>= 2`, abort with `lost: claim limit reached (holding TASK-X, TASK-Y) — finish or release first` and write nothing. Belt-and-braces for an agent that ignores `tick next` and claims by ID directly.

The active-claim count comes from the same projection logic `tick project` already uses — reuse it, do not re-derive.

**Also add a test:** `test/claim-cap.sh` — one agent claims 2 tasks, the 3rd `tick claim` is refused, `tick next` returns the limit message; after `tick done` on one task, the 3rd claim succeeds. Wire it into `validate.sh`. The other 7 acceptance tests must still pass.

Update the agent integration prompt in [`experiments/coordination-layer/README.md`](../../experiments/coordination-layer/README.md) with one line: *"You may hold at most 2 active claims. Finish (`tick done`) or release (`tick release`) a task before claiming a third."*

---

## The synthetic app

A small **Todo REST API** in Node.js — no external dependencies, plain `http` module, in-memory storage. Built fresh under `experiments/coordination-layer/sandbox-app/`. It is deliberately throwaway; the app is the *vehicle* for the coordination test, not a deliverable.

The app has two cleanly separated halves with **no shared files**, so path-routing sends each agent to its own half and they never edit the same file:

```
experiments/coordination-layer/sandbox-app/
├── src/
│   ├── http/          # Part A — Agent 1's scope
│   │   ├── server.js
│   │   ├── router.js
│   │   └── handlers.js
│   └── store/         # Part B — Agent 2's scope
│       ├── store.js
│       ├── validate.js
│       └── query.js
├── test/
│   ├── http/          # Part A tests
│   └── store/         # Part B tests
└── package.json       # pre-created in seed step, claimed by nobody
```

The two halves integrate through a **documented interface contract** (below), so neither agent needs to read the other's code. Integration is the coordinator's job at the end of the run.

### Store interface contract (Part A codes against this; Part B implements it)

```
createStore() -> store
  store.create(todo)   -> { id, title, done, createdAt }   // throws on invalid input
  store.get(id)        -> todo | null
  store.list(query)    -> todo[]                            // query: { done?, sort? }
  store.update(id, p)  -> todo | null
  store.remove(id)     -> boolean
```

`todo` shape: `{ id: string, title: string, done: boolean, createdAt: ISO-string }`.
Validation rules and query semantics are defined in tasks B2 and B3.

---

## The 6 tasks

Three tasks per half. Each task's path scope is fully inside one half — **zero cross-half overlap**, so the two agents are routed to separate work automatically. The max-2-claim cap means each agent must `tick done` one task before claiming its third.

### Part A — HTTP layer (`src/http/**`, `test/http/**`)

| Task | Scope | Description | Acceptance |
|---|---|---|---|
| **TASK-A1** | `src/http/server.js`, `test/http/server.test.js` | HTTP server bootstrap. Boots on a port, responds `200 {"status":"ok"}` to `GET /health`. | `node test/http/server.test.js` exits 0; health check returns ok. |
| **TASK-A2** | `src/http/router.js`, `test/http/router.test.js` | Router: dispatch by `method + path`, support `:id` params, return 404 for unmatched routes. | Router unit test exits 0; matches `GET /todos`, `GET /todos/:id`, returns 404 otherwise. |
| **TASK-A3** | `src/http/handlers.js`, `test/http/handlers.test.js` | Request handlers for `GET/POST/PUT/DELETE /todos` that call the store interface (per contract) and shape JSON responses + status codes. | Handler test exits 0 using a stub store; correct status codes (200/201/404/400). |

### Part B — Store layer (`src/store/**`, `test/store/**`)

| Task | Scope | Description | Acceptance |
|---|---|---|---|
| **TASK-B1** | `src/store/store.js`, `test/store/store.test.js` | In-memory store implementing the contract: `create/get/list/update/remove`. IDs are unique strings. | Store test exits 0; CRUD round-trips; `get` of missing id returns null. |
| **TASK-B2** | `src/store/validate.js`, `test/store/validate.test.js` | Input validation for writes: `title` required non-empty string, `done` optional boolean. Used by `store.create/update`. | Validate test exits 0; rejects empty/missing title, accepts valid input. |
| **TASK-B3** | `src/store/query.js`, `test/store/query.test.js` | Query helpers for `store.list`: filter by `done`, sort by `createdAt` asc/desc. | Query test exits 0; filter + sort behave per contract. |

Priorities: A1=B1=10, A2=B2=8, A3=B3=5 (so each agent's natural order is foundation → consumer).

**Note:** TASK-A3 depends on the store *contract*, not on Part B's code — it is tested with a stub store. TASK-B1 depends on B2's *contract*, not its code — B1 can ship a placeholder validator call and the real wiring is trivial. No task is blocked on another agent's commits.

---

## Test protocol

### 1. Setup (coordinator + Noel)

1. Land the claim-cap prerequisite (above), commit, push.
2. Create the sandbox app skeleton: empty `src/http/`, `src/store/`, `test/` dirs and a minimal `package.json`. Commit as the seed — claimed by nobody.
3. Two clones, one per agent, both on `experiment/coordination-layer`, `git config user.name` set to the agent ID (`codex` / `gemini`). Per [`README.md`](../../experiments/coordination-layer/README.md) multi-agent setup.
4. Seed the event log with all 6 tasks via `tick log task.created` (see task table for scopes/priorities). Commit + push the seed.
5. Load each agent with the integration prompt from `README.md` (now including the claim-cap line) plus this doc's task table.

### 2. Run (30–60 min, agents work, coordinator observes)

- Agents run `tick next`, claim, code, test, `tick done`, repeat.
- Coordinator monitors via `tick project` / `cat .tick/STATE.md` / `tick analyze` only. **Does not claim, code, or intervene** unless a stop condition is hit (below).
- Coordinator answers Noel's questions from that data.

### 3. Stop conditions (coordinator flags to Noel)

- An agent holds 2 claims and is silent > 15 min → possible crash; note it, do not auto-reap.
- File collision reported by `tick analyze` → flag immediately.
- An agent's `tick claim` is refused by the cap → **expected**; note it as a positive signal, not a problem.
- Both agents `tick done` all 6 tasks, or the 60-min box expires.

### 4. Wrap-up (coordinator + Noel)

1. `git pull` all peer commits.
2. `tick analyze --write experiments/coordination-layer/REAL-AGENT-OBSERVATIONS.md`.
3. Coordinator integrates the two halves (`server.js` wires `router` + `handlers` + a real `store`) and runs the full app once to confirm the pieces fit. This is the only coding the coordinator does.
4. Walk the auto-analyzed sections with Noel; capture subjective observations per agent.
5. Synthesize: did sustained parallelism hold? → graduate / iterate / abandon.
6. Append a "Run 2" section to [`RECAP.md`](../../experiments/coordination-layer/RECAP.md).

---

## Success criteria

The run **succeeds** if all of the following hold:

1. **Both agents do real work** — each agent has `tick done` on ≥ 2 tasks (contrast Run 1: one agent did 0, the other did 0).
2. **The cap held** — at no point does either agent hold > 2 active claims; `tick analyze` shows no agent with > 2 simultaneous claims in any window.
3. **No starvation** — neither agent sat idle waiting on `(no available task)` while the other held claimable work.
4. **No file collisions** — `tick analyze` cross-cutting section reports zero same-file edits by both agents.
5. **Path scopes honored** — declared paths matched actual edits (drift acceptable as a caveat, not a failure).
6. **The app integrates** — coordinator's end-of-run integration produces a Todo API that boots and serves `GET /health` + `GET /todos`.

Partial success (some but not all of 1–6) → **iterate**: adjust the cap, the prompt, or the task granularity and run again.

If one agent still monopolizes despite the cap, or an agent crashes and stalls the run → **the cap is not sufficient**; the next lever is gap #2 (liveness/TTL) before any real-app attempt.

---

## Non-goals (do not build in Run 2)

- Liveness / TTL / `tick reap` for crashed agents (gap #2) — observe only; address before real-app run if Run 2 still stalls.
- Refusing self-overlapping path claims (gap #3) — not exercised here since the 6 tasks have zero cross-scope overlap.
- A configurable cap value — hardcode 2.
- Persisting the sandbox app — it is throwaway; do not polish it, do not open a PR for it.
- WPCC / Git Pulse / MCP integration — still Phase 2.
- Touching any AI-DDTK source outside `experiments/coordination-layer/`.

---

## Deliverables

- Claim-cap change landed in `tick` + `test/claim-cap.sh` passing in `validate.sh` (8/8).
- `REAL-AGENT-OBSERVATIONS.md` updated with Run 2 auto-analysis + subjective notes.
- `RECAP.md` "Run 2" section with the graduate / iterate / abandon call.
- A one-paragraph answer to the load-bearing question: **does a per-agent claim cap produce sustained two-agent parallelism?**
