# Trinity — Synthetic parallelism run (Run 2)

**Parent:** [`P1-TRINITY.md`](P1-TRINITY.md)
**Branch:** `experiment/coordination-layer`
**Owner:** Noel / Hypercart
**Coordinator:** Claude Code (orchestrator — observes, does not claim or code)
**Agents:** 2 of {Codex, Gemini} — the peers doing the work
**Status:** Complete. Run 2 executed 2026-05-14–15. See RECAP.md "Run 2" section for findings.

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

This run targets gap #1 directly. The question it answers: **with a claim cap in place, will two agents sustain parallel work on separate parts of a real app — or does the protocol still collapse to one agent?** Gap #2 is partially mitigated by a manual `tick reap` lever (P5 below); full auto-reap stays deferred. Gap #3 is not exercised here (see Non-goals).

The test goal is **sustained parallelism, not throughput.** Success is two agents each making steady progress on their own half — *not* one agent finishing all 6 tasks fast.

---

## Prerequisites — engineering before the run

All of this lands and is committed before agents start. The coordinator (or Noel) does this work; it is **not** part of the observed run.

### P1 — Claim cap

`MAX_ACTIVE_CLAIMS_PER_AGENT = 2`, hardcoded. "Active" = claimed and not yet released, done, or circuit-broken.

- **`tick next`** ([`src/next.js`](../../experiments/coordination-layer/src/next.js)) — if the requesting agent already holds ≥ 2 active claims, return `(claim limit reached — finish or release a task first)` instead of a task ID.
- **`tick claim`** ([`src/claim.js`](../../experiments/coordination-layer/src/claim.js)) — if the requesting agent already holds ≥ 2 active claims, abort with `lost: claim limit reached (holding TASK-X, TASK-Y) — finish or release first` and write **zero events**.
- The active-claim count reuses the existing `tick project` projection logic — do not re-derive it.

### P2 — Audit + fix claim-cycle atomicity

`tick claim` does read-projection-then-write; that pattern is TOCTOU-race-prone. Audit [`src/claim.js`](../../experiments/coordination-layer/src/claim.js) for whether the check-then-write is protected (`O_EXCL`, `flock`, atomic rename) or whether two concurrent claims could both pass the cap check. With two clones syncing over `git push`/`pull` the race window is wider than in-process but narrower than two daemons on a shared FS — still real. If unprotected, add rename-based atomicity (or `proper-lockfile` — the one allowed dependency) before the run. **This is real pre-run engineering, not just an audit** — the cap is only as strong as the atomicity under it.

### P3 — Audit agent-identity source

Confirm the cap's per-agent check reads `git config user.name` (or equivalent) **at every claim-time check**, not once at startup, and that an agent cannot trivially mask or spoof it. The cap is per-agent or it is nothing. ~5-minute audit; fix if wrong.

### P4 — Concurrent-claim-time metric in `tick analyze`

Add a metric to `tick analyze` reporting how much of the run window had **both agents holding ≥ 1 active claim simultaneously** — absolute time and % of the run window. This is the real success metric (see Success criteria): it answers "did parallelism actually hold" directly, where per-agent task counts can be fooled by a lopsided 5-vs-1 split.

### P5 — Manual `tick reap <agent>` command

A tested, logged command the coordinator can run to release all of a crashed agent's active claims (emits a `task.released` event per claim). **Manual only — not auto-reap.** Without it, a single crash ends Run 2 with no cap answer; with it, the coordinator can unblock the backlog and salvage the run. Manual + logged preserves Run 2's "observe, don't auto-intervene" character — it is a deliberate, recorded coordinator action, not a background daemon.

### P6 — Tests

- **`test/claim-cap.sh`** — one agent claims 2 tasks; the 3rd `tick claim` is refused **and writes zero events** (assert the event count is unchanged); `tick next` returns the limit message; after `tick done` on one task, the 3rd claim succeeds.
- **`test/reap.sh`** — `tick reap <agent>` releases all of that agent's active claims and emits the `task.released` events; another agent's `tick next` can then pick them up.
- Wire both into `validate.sh`. All 7 prior acceptance tests must still pass → **9 / 9**.

### P7 — Integration prompt updates

In [`experiments/coordination-layer/README.md`](../../experiments/coordination-layer/README.md), add to the agent integration prompt:

- **Claim cap:** *"You may hold at most 2 active claims. Finish (`tick done`) or release (`tick release`) a task before claiming a third."*
- **No dependencies:** *"Use only the Node standard library — `node:http`, `node:test`, `node:assert`. Do NOT install dependencies, do NOT edit `package.json`, do NOT create a lockfile. `package.json` is shared and outside every task's scope; touching it collides with the other agent and fails the run."*

### P8 — Pin the store contract to its own file

Setup step 2 writes the contract (verbatim from "Store interface contract" below) to `experiments/coordination-layer/sandbox-app/STORE-CONTRACT.md`. Agents read **that file**, not this plan doc — the contract is then stable, co-located with the app, and the most plausible integration-time surprise is removed.

---

## The synthetic app

A small **Todo REST API** in Node.js — **standard library only, zero dependencies** (`node:http`, `node:test`, `node:assert`), in-memory storage. Built fresh under `experiments/coordination-layer/sandbox-app/`. It is deliberately throwaway; the app is the *vehicle* for the coordination test, not a deliverable.

The app has two cleanly separated halves with **no shared source files**, so path-routing sends each agent to its own half and they never edit the same file:

```
experiments/coordination-layer/sandbox-app/
├── src/
│   ├── http/          # Part A — one agent's half
│   │   ├── server.js
│   │   ├── router.js
│   │   └── handlers.js
│   └── store/         # Part B — the other agent's half
│       ├── store.js
│       ├── validate.js
│       └── query.js
├── test/
│   ├── http/          # Part A tests
│   └── store/         # Part B tests
├── STORE-CONTRACT.md  # written at setup (P8); the stable contract agents read
└── package.json       # stdlib-only, no deps; claimed by nobody; DO NOT EDIT
```

The two halves integrate through the **documented interface contract** (below), so neither agent needs to read the other's code. Integration is the coordinator's job at the end of the run.

### Store interface contract

This section is authoritative. Setup copies it verbatim into `sandbox-app/STORE-CONTRACT.md` (P8).

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

## Path-routing: how agents are separated into halves

The collision guarantee depends on this being explicit. **Mechanism for Run 2: half-wide declared scope + first-claim-wins-the-half.**

- Every Part A task is seeded with `paths: ["src/http/**", "test/http/**"]` — the **whole half**, not the individual file.
- Every Part B task is seeded with `paths: ["src/store/**", "test/store/**"]`.
- When an agent claims its first task (say A1), it declares that half's glob. The other agent's `tick next` now filters out A2 and A3 — their declared paths overlap a claim held by *another* agent — and routes that agent to Part B instead.
- Combined with the claim cap: the half's "owner" can hold at most 2 of its 3 tasks. The 3rd is claimable by nobody else (path overlap with the owner's claims) and not by the owner (cap) until the owner runs `tick done`. That is the intended "finish one before the third" pressure, and it is *protocol-enforced*, not prompt-enforced.

**Tradeoff accepted for Run 2:** half-wide scopes make `tick analyze`'s per-file drift detection coarse within a half — any edit under `src/http/**` matches the claim. Run 2 tests *parallelism and cross-half isolation*, not intra-half drift precision; this is acceptable. Precise per-file scoping returns in later runs.

**Edge case (out of scope, noted):** `tick claim` does not refuse a path-overlapping claim made by ID directly (Run 1 gap #3). An agent that bypasses `tick next` and claims an opposite-half task by ID is not blocked. Run 2 relies on agents using `tick next` for discovery, as the integration prompt instructs.

---

## The 6 tasks

Three tasks per half. Declared scope is the whole half (see Path-routing); the **Files** column is what the agent actually touches. The max-2-claim cap means each agent must `tick done` one task before claiming its third.

### Part A — HTTP layer · declared scope `src/http/**`, `test/http/**`

| Task | Files | Description | Acceptance |
|---|---|---|---|
| **TASK-A1** | `src/http/server.js`, `test/http/server.test.js` | HTTP server bootstrap — **intentionally minimal: boot + `GET /health` only.** Responds `200 {"status":"ok"}`. Do NOT add routing or request handling here; that is A2/A3. | `node --test test/http/server.test.js` exits 0; health check returns ok. |
| **TASK-A2** | `src/http/router.js`, `test/http/router.test.js` | Router: dispatch by `method + path`, support `:id` params, return 404 for unmatched routes. | `node --test test/http/router.test.js` exits 0; matches `GET /todos`, `GET /todos/:id`, 404 otherwise. |
| **TASK-A3** | `src/http/handlers.js`, `test/http/handlers.test.js` | Request handlers for `GET/POST/PUT/DELETE /todos` that call the store interface (per contract) and shape JSON responses + status codes. | `node --test test/http/handlers.test.js` exits 0 using a **stub store**; correct status codes (200/201/404/400). |

### Part B — Store layer · declared scope `src/store/**`, `test/store/**`

| Task | Files | Description | Acceptance |
|---|---|---|---|
| **TASK-B1** | `src/store/store.js`, `test/store/store.test.js` | In-memory store implementing the contract: `create/get/list/update/remove`. IDs are unique strings. | `node --test test/store/store.test.js` exits 0; CRUD round-trips; `get` of missing id returns null. |
| **TASK-B2** | `src/store/validate.js`, `test/store/validate.test.js` | Input validation for writes: `title` required non-empty string, `done` optional boolean. Used by `store.create/update`. | `node --test test/store/validate.test.js` exits 0; rejects empty/missing title, accepts valid input. |
| **TASK-B3** | `src/store/query.js`, `test/store/query.test.js` | Query helpers for `store.list`: filter by `done`, sort by `createdAt` asc/desc. | `node --test test/store/query.test.js` exits 0; filter + sort behave per contract. |

Priorities: A1=B1=10, A2=B2=8, A3=B3=5 (each agent's natural order is foundation → consumer).

**No task is blocked on another agent's commits.** TASK-A3 depends on the store *contract*, not Part B's code — it is tested with a stub store. TASK-B1 depends on B2's *contract*, not its code — B1 can ship a placeholder validator call and the real wiring is trivial.

---

## Test protocol

### 1. Setup (coordinator + Noel)

1. Land all prerequisites P1–P8, commit, push. Confirm `validate.sh` is 9 / 9.
2. Create the sandbox app skeleton: empty `src/http/`, `src/store/`, `test/http/`, `test/store/` dirs, a minimal stdlib-only `package.json`, and `STORE-CONTRACT.md` (P8). Commit as the seed — claimed by nobody.
3. Two clones, one per agent, both on `experiment/coordination-layer`, `git config user.name` set to the agent ID (`codex` / `gemini`). Per [`README.md`](../../experiments/coordination-layer/README.md) multi-agent setup.
4. Seed the event log with all 6 tasks via `tick log task.created` (half-wide `paths` and priorities per the task tables). Commit + push the seed.
5. **Solo stability soak** — *before* the parallel run, each agent claims and completes one trivial throwaway task **alone** (e.g. add a one-line comment to a scratch file, `tick done`). This surfaces "does this agent even stay alive through a full claim→done cycle" before a parallel slot is burned on it. If an agent fails the soak, fix or swap it first.
6. Load each agent with the integration prompt from `README.md` (now including the claim-cap and no-dependencies lines) plus this doc's task table.

### 2. Run (30–60 min, agents work, coordinator observes)

- Agents run `tick next`, claim, code, test, `tick done`, repeat.
- Coordinator monitors via `tick project` / `cat .tick/STATE.md` / `tick analyze` only. **Does not claim, code, or intervene** unless a stop condition is hit.
- Coordinator answers Noel's questions from that data.

### 3. Stop conditions (coordinator flags to Noel)

- An agent holds claims and is silent > 15 min → possible crash. Flag it; with Noel's go-ahead, run `tick reap <agent>` (P5) to release its claims and salvage the run. The reap is logged and reported — it is a deliberate coordinator action, not auto-recovery.
- File collision reported by `tick analyze` → flag immediately.
- An agent's `tick claim` is refused by the cap → **expected**; note it as a positive signal, not a problem.
- Both agents `tick done` all 6 tasks, or the 60-min box expires.

### 4. Wrap-up (coordinator + Noel)

1. `git pull` all peer commits.
2. `tick analyze --write experiments/coordination-layer/REAL-AGENT-OBSERVATIONS.md` — includes the new concurrent-claim-time metric.
3. Coordinator integrates the two halves (`server.js` wires `router` + `handlers` + a real `store`) and runs the full app once to confirm the pieces fit. This is the only coding the coordinator does.
4. Walk the auto-analyzed sections with Noel; capture subjective observations per agent.
5. Synthesize: did sustained parallelism hold? → graduate / iterate / abandon.
6. Append a "Run 2" section to [`RECAP.md`](../../experiments/coordination-layer/RECAP.md).

---

## Success criteria

1. **Parallel overlap held — primary metric.** `tick analyze`'s concurrent-claim-time metric (P4) shows both agents held active claims simultaneously for **≥ 50 % of the run window** *(threshold tunable — confirm with Noel before the run)*. This is the load-bearing number.
2. **Both agents did real work — secondary guard.** Each agent has `tick done` on **≥ 2 tasks**. Catches the degenerate lopsided split (e.g. 5-vs-1) that a high overlap % could otherwise mask.
3. **The cap held.** No agent ever held > 2 active claims in any window.
4. **No starvation.** Neither agent sat idle on `(no available task)` while the other held claimable work. (Cap-refusal messages don't count — those are expected.)
5. **No file collisions.** `tick analyze` cross-cutting section reports zero same-file edits by both agents.
6. **Path scopes honored.** Declared (half-wide) scopes matched actual edits — no agent edited outside its half.
7. **The app integrates.** The coordinator's end-of-run integration produces a Todo API that boots and serves `GET /health` + `GET /todos`.

Partial success (some but not all of 1–7) → **iterate**: adjust the cap, the prompt, the threshold, or the task granularity, run again.

If one agent still monopolizes despite the cap, or an agent crashes and `tick reap` can't salvage the run → **the cap is not sufficient**; the next lever is full liveness / TTL / auto-reap (gap #2) before any real-app attempt.

---

## Non-goals (do not build in Run 2)

- **Full TTL / liveness / auto-reap** (gap #2) — the manual `tick reap` lever (P5) is the Run 2 mitigation. Full auto-reap is the next lever *only if* Run 2 still stalls on a crash despite P5; unavoidable before any real-app run if so.
- **Refusing self-overlapping path claims** (gap #3) — not exercised here; the 6 tasks have zero cross-half overlap and agents discover work via `tick next`.
- **A configurable cap value** — hardcode 2.
- **Persisting the sandbox app** — it is throwaway. Do not polish it, do not open a PR for it.
- **WPCC / Git Pulse / MCP integration** — still Phase 2.
- **Touching any AI-DDTK source outside `experiments/coordination-layer/`.**

---

## Deliverables

- Prerequisites P1–P8 landed: claim cap, atomicity fix, identity audit, concurrent-claim-time metric, `tick reap`, tests, prompt updates, contract file.
- `validate.sh` at **9 / 9** (`claim-cap.sh` + `reap.sh` added; prior 7 still pass).
- `REAL-AGENT-OBSERVATIONS.md` updated with Run 2 auto-analysis (incl. concurrent-claim-time) + subjective notes.
- `RECAP.md` "Run 2" section with the graduate / iterate / abandon call.
- A one-paragraph answer to the load-bearing question: **does a per-agent claim cap produce sustained two-agent parallelism?**
