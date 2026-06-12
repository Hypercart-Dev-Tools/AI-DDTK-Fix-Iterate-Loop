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
