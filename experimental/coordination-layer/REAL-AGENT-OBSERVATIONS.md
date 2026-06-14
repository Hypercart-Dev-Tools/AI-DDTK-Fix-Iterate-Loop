# Real-agent hand-test observations

> **Tip:** run `./bin/tick analyze --write REAL-AGENT-OBSERVATIONS.md` after a session to auto-fill the per-agent compliance numbers. Write the subjective sections and synthesis by hand.

---

## Run 1 — 2026-05-06

### Run metadata

- **Date:** 2026-05-06
- **Duration:** ~3 minutes (Gemini crashed almost immediately)
- **Fixture codebase:** coordination-layer test harness (3 tasks: TASK-A, TASK-B, TASK-C)
- **Seeded tasks:** 3
- **Worktree topology:** shared repo, one branch

### Outcome: FAILED — no parallelism, no code output

Gemini claimed all 3 tasks in 33 seconds, starving Codex. Codex behaved correctly — lost 2 tie-breakers, auto-released both times, then stood down on `(no available task)`. Gemini then crashed with zero work commits, leaving all 3 tasks stuck in `claimed` with no recovery path.

**Root causes:**
1. No per-agent claim cap — fast claimer monopolized the backlog.
2. No liveness lever — crashed claimer left tasks unrecoverable.
3. Git transport made claim events too slow to arrive for Codex before Gemini swept all 3.

### Auto-analyzed (tick analyze)

- **Run window:** `2026-05-06T16:17:18.481Z` → `2026-05-06T16:20:27.912Z`
- **Total events:** 10 (created: 3, claimed: 5, released: 2)

#### codex — 0 won / 2 lost / 0 done
- Claimed before editing: yes
- Used `tick done`: no (never got a task)
- 2 releases (both auto-release after tie-breaker loss)

#### gemini — 3 won / 0 lost / 0 done
- Claimed before editing: **no — 3 unclaimed work commits**
- Used `tick done`: no (crashed)
- Unclaimed commits: edits to BACKLOG.md, CLAUDE.md, CODEX.md, GEMINI.md, README.md

### Cross-cutting
- File collisions: none
- Wasted work: none (Gemini never produced output)

---

## Run 2 — 2026-05-14–15

### Run metadata

- **Date:** 2026-05-14 (started) → 2026-05-15 (Gemini finished TASK-A1)
- **Duration:** ~21h elapsed wall time, but most of that was session interruptions; actual agent-active time was ~1h
- **Fixture codebase:** Todo REST API skeleton (`sandbox-app/`) — stdlib-only Node.js, 6 tasks
- **Seeded tasks:** 6 (TASK-A1–A3 HTTP layer, TASK-B1–B3 store layer)
- **Worktree topology:** shared local repo, local-transport `.tick/events/` (no git push per event)

### Outcome: ALL TASKS COMPLETE — parallelism partially achieved

All 6 tasks done, 0 circuit breaks. The cap held — no agent exceeded 2 active claims. No file collisions. The two halves were successfully kept separate by path-routing.

**Concurrent-claim-time: 2m 9s / 21h run window (0%)** — this number is misleading. The 21h elapsed window is dominated by session interruptions; the agents were not both active for most of it. A same-session run would show genuine parallel overlap.

### Auto-analyzed (tick analyze)

- **Run window:** `2026-05-14T20:13:47Z` → `2026-05-15T17:21:31Z`
- **Total events:** 18 (created: 6, claimed: 6, released: 0, done: 6)

#### codex — 2 claimed / 2 done

- Claimed before editing: yes (after resolving git identity issues)
- Used `tick done`: yes — both tasks
- Used `tick scope` / `tick break`: no
- Compliance: clean

#### gemini — 4 claimed / 4 done

- Claimed before editing: yes
- Used `tick done`: yes — all 4 tasks
- Did both halves (claimed A tasks after B tasks were done)
- Compliance: clean

### Cross-cutting

- File collisions: none
- Wasted work on broken tasks: none
- Cap held: no agent held > 2 claims at any point

### Subjective observations

**Friction — both agents:**
- The `tick next` → `tick claim` two-step has a real race window. Both agents hit it (Codex lost TASK-B3; Gemini lost TASK-B1 momentarily). Significant enough that both agents independently flagged it in post-run feedback.
- Git identity (`git config user.name`) flipped between agents in the shared repo, producing noisy and misleading `tick: warning` messages. Both agents flagged this independently.

**Friction — Codex specifically:**
- Writing `.git/tick-claim.lock` was blocked in Codex's sandbox environment. Forced an escalation just to claim work. Directly blocked progress.
- `tick next` rewrote `STATE.md` on every invocation, making `git status` dirty on read-only operations.

**Friction — Gemini specifically:**
- Path globs copied verbatim from the prompt — Gemini flagged that `tick info <TASK-ID>` would remove the need to copy-paste scope strings.

### Post-run improvements shipped (2026-05-15)

All implemented and committed before documentation:

| Item | Change |
|---|---|
| P0: Lock location | `.git/tick-claim.lock` → `.tick/locks/claim.lock` |
| P0: Ownership enforcement | `done/release/break/scope` now reject calls from non-owning agents |
| P1: Atomic claim | New `tick take --agent <id>` — next+claim under one lock |
| P1: Identity check | Removed `checkAgentIdentity()` — `--agent` is authoritative |
| P2: Read-only `next` | `tick next` no longer writes STATE.md |
| P2: Task query | New `tick info <TASK-ID>` — prints status/priority/paths/claimer |

### Recommendation

**Iterate — run again (Run 3) with same-session agents.**

The protocol worked: both agents engaged, all tasks completed, no collisions, cap held. The primary failure was operational (session fragmentation over 21h), not protocol-level. The concurrent-claim-time metric (the load-bearing success criterion) is not answerable from Run 2's data because the 21h window dominated by idle time makes 0% meaningless.

Run 3 should: (a) use the same-session start prompt (`START-HERE.md`), (b) use `tick take` instead of `tick next` + `tick claim`, (c) complete within a single session so the concurrent-claim-time metric is meaningful. All known friction points are fixed. If Run 3 shows ≥50% concurrent-claim time with both agents active, graduate to Phase 2.

---

## Run 3 — 2026-06-14

### Run metadata

- **Date:** 2026-06-14 (single session)
- **Duration:** work-bounded window **3m 37s** (first `task.claimed` → last `task.done`). Note: ~8h elapsed between coordinator seeding and agent start — excluded from the metric by the redefined work-bounded window.
- **Fixture codebase:** same Todo REST API skeleton (`sandbox-app/`), cleared to scaffolding and re-seeded
- **Seeded tasks:** 6 (TASK-A1–A3 HTTP, TASK-B1–B3 store)
- **Worktree topology:** shared local repo, shared `.tick/events/`, single session, branch `development`
- **Protocol:** `tick take` (atomic claim) + `tick ping` (liveness heartbeat); parked-claim detection via `tick analyze`

### Outcome: ALL TASKS COMPLETE, mechanically clean — but metric MISSED (40% < 50%)

All 6 tasks done; **26/26 sandbox-app acceptance tests pass** (real, working, integrated code on both halves). 0 circuit breaks, 0 file collisions, 0 parked-claim suspects, cap held throughout. The agent-facing fixes all worked: no claim-race reported (`tick take`), heartbeats honored (`tick ping`), lane separation clean.

**Redefined success criterion — FAIL:**

| Check | Result | Bar | Pass? |
|---|---|---|---|
| Work-bounded concurrent-claim time | **40%** (1m 27s / 3m 37s) | ≥ 50% | ❌ |
| Both agents ≥ 2 done | gemini 3, codex 3 | ≥ 2 each | ✅ |
| Disqualifier — parked claims | 0 suspects | none | ✅ |
| Disqualifier — serial double-claim | none | none | ✅ |
| Cross-check — overlap = real edits | 26/26 tests pass, both halves real | — | ✅ |

**Why the metric missed:** Gemini completed all 3 HTTP tasks quickly, then sat **idle for the final ~1m 33s** while Codex finished B2 and B3 alone. Genuine simultaneous overlap occurred early (~1m 27s with both holding claims), but static per-half partitioning gives the faster agent nothing to do once its lane is clear — there is no work-stealing across halves. Sustained overlap therefore capped at 40%.

### Auto-analyzed (tick analyze)

- **Run window (tool default, old metric):** `2026-06-14T07:25:58Z` → `2026-06-14T15:24:04Z` — shows 0%/7h56m, **misleading** (dominated by the ~8h seed→start gap). Use the work-bounded number above.
- **Total events:** 27 (created: 6, claimed: 6, released: 0, scope_changed: 0, heartbeat: 9, done: 6, circuit_break: 0)

#### codex — 3 claimed / 3 done / 6 heartbeats
- Store half (B1, B2, B3). Claimed before editing: yes. Used `tick done`: all 3. Heartbeats: 6 (contract honored). Compliance: clean.

#### gemini — 3 claimed / 3 done / 3 heartbeats
- HTTP half (A1, A2, A3). Claimed before editing: yes. Used `tick done`: all 3. Heartbeats: 3 (contract honored). Compliance: clean. Went idle after its half completed (~1m 33s before run end).

### Cross-cutting

- File collisions: none
- Parked-claim suspects: none (heartbeats present throughout each claim window)
- Wasted work on broken tasks: none
- Cap held: no agent held > 2 claims at any point
- Claim mechanics: `tick take` produced no observed race; lane separation kept agents on their own halves

### Subjective observations

> _To be filled from agent post-run feedback (ask Codex and Gemini directly) and Noel's own observation. Objective sections above are coordinator-verified._

### Recommendation

**Iterate — Run 4.**

The coordination protocol is mechanically proven: atomic claims, clean lane separation, zero collisions, honored heartbeats, all tasks completed with passing tests. The failure is **not** a coordination failure — it is **load imbalance**: a static per-half split lets the faster agent idle once its lane is clear, capping sustained overlap below the 50% bar (40% achieved).

Run 4 should target balance rather than mechanics:
- **Work-stealing across halves** (let an idle agent claim from the other half once its own is drained), or
- **Finer-grained / interleaved task split** so neither agent runs dry early, or
- **A balanced fixture** where the two halves take comparable effort.

Then retest the ≥50% bar. Do **not** graduate to Phase 2 until sustained parallelism clears the bar — but note the result is a near-miss on a flawless run, not a structural dead end (so not "abandon").
