# Trinity — AI-DDTK Coordination Layer Spike

**Codename:** Trinity (Claude Code · Codex · Gemini — three agents, one shared substrate)
**Branch:** `experiment/coordination-layer`
**Time-box:** 5 working days
**Owner:** Noel / Hypercart
**Status:** **Days 1-4 mechanical work compressed into one Claude Code session on 2026-05-04. All 7 mechanical acceptance criteria pass.** Day 5 real-agent hand-test still required. See [`experiments/coordination-layer/RECAP.md`](../../experiments/coordination-layer/RECAP.md).

---

## Prompt for Claude Code Cloud

> You are building **Trinity**, an experimental coordination layer for AI-DDTK that lets Claude Code, Codex, and Gemini work the same codebase concurrently without colliding. Branch: `experiment/coordination-layer`. Read this entire document before writing any code.
>
> **Build only what is specified in the roadmap below.** The Non-goals section is a hard fence — if you find yourself wanting to build something not listed in scope, do not build it. Add a one-line entry to `experiments/coordination-layer/TODO_DEFER.md` and move on.
>
> Optimize for, in order: (1) simplicity, (2) deletability, (3) fast validation. When uncertain between two designs, pick the one with less surface area. When uncertain whether to add a feature, don't. Reuse existing AI-DDTK conventions (Node.js, JSONL, plain `fs` + `child_process` for git). Do not add new dependencies unless an acceptance criterion requires it.
>
> When all acceptance criteria pass end-to-end (validated by `experiments/coordination-layer/validate.sh`), stop. Do not polish. Open a draft PR with a write-up answering: what worked, what didn't, what the next decision should be.

---

## Why this exists

The primary goal is to run multiple VS Code coding agents (Claude Code, Codex, Gemini) on the same codebase concurrently without stepping on each other. Today there is no shared substrate, so two agents can independently:

- Claim the same task and double-do the work.
- Edit the same file and silently overwrite each other on push.
- Burn their full Fix-Iterate budget (5 failures / 10 iterations) on the same poisoned task because circuit-breaks are per-agent, not swarm-visible.

This spike validates whether an event-sourced coordination layer — append-only JSONL events in `.tick/events/`, projected into a markdown state file, with **path-scoped task claims** and a small set of pivot events — eliminates those collisions. WPCC and Git Pulse integration are deferred to Phase 2; they're nice-to-haves, not the goal.

---

## Architecture (settled — do not re-derive)

- **Event log:** one JSONL file per event under `.tick/events/`. Filename: `{ISO-ts}-{agent}-{action}-{taskId}.jsonl`. Append-only. Agents never edit shared files; they only create new ones. Disjoint files = zero git merge conflicts.
- **Projection:** `tick project` rebuilds `STATE.md` from the event log. `STATE.md` is generated, never hand-edited. A header banner says so.
- **Optimistic claim:** to claim, an agent appends a `task.claimed` event with declared file globs (`paths: ["src/auth/**", "tests/auth/**"]`) and pushes. After push, it re-projects and checks whether its claim won (deterministic tie-breaker: earliest event timestamp, then lexicographic agent ID). Loser auto-emits a `task.released` event.
- **Path-scoped routing:** `tick next` filters out tasks whose declared paths overlap with currently-claimed paths. Two agents are routed to non-overlapping work automatically.
- **Worktree convention (recommended, not enforced):** each agent runs in its own `git worktree`. Filesystem-level isolation backstops path-scoping if an agent strays outside its declared paths.
- **Sync primitive — auto-push on critical events.** Critical events (`task.claimed`, `task.scope_changed`, `task.released`, `task.circuit_break`, `task.done`) auto-fetch + auto-push. Non-critical events (`task.commented`, `task.created` when seeded from a backlog file) are written locally and ride along with the next normal commit. Read verbs (`tick next`, `tick claim`'s pre-flight) `git fetch` before acting so agents see latest peer state. Cost: 2 commits per typical task lifecycle, 3-5 with pivots. Phase 2 mitigations (squash, separate ref, replace git with a daemon) deferred. **Constraint:** all coordinating agents must work on the same branch — `.tick/` is branch-scoped. Cross-branch coordination is Phase 2.
- **Claim implementation contract:** `tick claim` is `git fetch → git rebase → write event → git add → git commit → git push (retry once on rejection with re-fetch) → tick project → verify claim won deterministic tie-breaker → if lost, auto-emit task.released (which itself auto-pushes)`. This sequence is load-bearing; do not shortcut it.
- **Event types:** `task.created`, `task.claimed` (with `paths`), `task.released` (with optional `to_agent` for handoff), `task.scope_changed` (with new `paths`), `task.commented`, `task.done`, `task.circuit_break`. Seven types. The computed *states* (open, claimed, broken, done) are still ≤4, so no FSM library needed.

---

## Scope

### In scope (build this)

- `.tick/events/` directory + JSONL event format with `paths` field on claims
- CLI verbs (in this exact order — don't add others):
  - `tick log <type> <task> [--note "..."] [--agent <id>] [--paths <globs>]` — append an event
  - `tick project` — rebuild `STATE.md` from events
  - `tick claim <task> --agent <id> --paths <globs>` — sugar for `log task.claimed`, then re-project, then verify win
  - `tick next --agent <id>` — read `STATE.md`, return next available task whose paths don't overlap currently-claimed paths
  - `tick scope <task> --agent <id> --paths <globs>` — emit `task.scope_changed` (mid-task path expansion or narrowing)
  - `tick release <task> --agent <id> [--to <agent>]` — emit `task.released`, optionally as handoff
  - `tick break <task> --agent <id> --reason "..."` — emit `task.circuit_break`
- `STATE.md` projector with path-overlap routing for `tick next`
- `validate.sh` covering all acceptance criteria

**Phase 2 (out of scope for this spike, listed for awareness):** WPCC findings adapter, Git Pulse source extension, ask-self event ingest, MCP tool wrapping. These graduate after the core substrate is proven.

### Non-goals (hard fence — do not build)

- WPCC findings adapter (Phase 2)
- Git Pulse source extension (Phase 2)
- ask-self event ingest (Phase 2)
- MCP tool additions (agents call the CLI directly during the spike — Phase 2)
- SQLite projection cache
- Ed25519 signing or any cryptographic auth
- Lock files or any lock-based concurrency control
- Vector clocks
- Web dashboard or any HTML UI
- Push notifications, webhooks, git hooks
- New event types beyond the seven listed in Architecture
- `task.blocked` or `task.ask_human` (use `task.commented` with a note for now; design these in Phase 2 alongside the existing ASK_HUMAN convention)
- Configuration files (`.tickrc`, etc.) — use sensible defaults, env vars if absolutely required
- Retry logic, backoff, or queueing
- Multi-repo or multi-project support
- Schema versioning beyond a single `schema_version: "0.1.0"` field on every event

If you think a non-goal is required, you're wrong. Stop and document why in `TODO_DEFER.md` instead.

---

## File layout

```
experiments/coordination-layer/
├── README.md                    # short, points back to this doc + worktree setup notes + agent integration prompt snippet
├── TODO_DEFER.md                # things you wanted to build but didn't
├── package.json                 # only if a new dep is unavoidable
├── bin/
│   └── tick                     # CLI entry point
├── src/
│   ├── events.js                # append + JSONL validate
│   ├── sync.js                  # fetch/rebase/commit/push wrapper for critical events
│   ├── project.js               # event log → STATE.md
│   ├── claim.js                 # optimistic claim + reconciliation (uses sync.js)
│   ├── paths.js                 # glob overlap detection for path-scoped routing
│   └── scope.js                 # scope_changed + release-with-handoff
├── test/
│   ├── concurrent-claim.sh      # two simulated agents, simultaneous claim, deterministic winner
│   ├── path-overlap.sh          # two agents, overlapping paths, second is routed elsewhere
│   ├── scope-change.sh          # mid-task scope expansion is honored by other agents
│   ├── handoff.sh               # release --to <agent> prioritizes targeted handoffs
│   ├── circuit-break.sh         # break event makes other agents skip
│   ├── projection-idempotent.sh # tick project twice = identical STATE.md
│   └── auto-sync.sh             # critical events push automatically; non-critical do not
├── validate.sh                  # runs all of the above, exits 0/1
├── REAL-AGENT-OBSERVATIONS.md   # written during Day 5 hand-test
└── RECAP.md                     # written at the end: what worked, what didn't
```

A bare-repo `.tick/` directory is created by `tick init` (sixth verb, fine to add — it's just `mkdir -p`). Do not add other init logic.

---

## Roadmap (5 days)

### Day 1 — Event log + CLI scaffold

- [ ] Create branch, scaffold directory layout above
- [ ] Implement `events.js`: `appendEvent({type, task, agent, note, paths})` writes one JSONL file
- [ ] Implement `bin/tick` with `tick init` and `tick log` only
- [ ] Hand-test: append 5 events, verify they sort lexicographically by filename

**Done when:** `tick log task.created TASK-001 --agent gianni` creates a valid JSONL file in `.tick/events/` with a parseable timestamp-based filename.

### Day 2 — Projection + claim reconciliation + auto-sync

- [ ] Implement `project.js`: read all `.tick/events/*.jsonl` in timestamp order, fold into in-memory state, write `STATE.md` with a generated-banner header
- [ ] Implement `tick project`
- [ ] Implement `sync.js`: a wrapper that handles `git fetch → rebase → add → commit → push (one retry on rejection)`. Critical event verbs use it; non-critical verbs don't.
- [ ] Implement `claim.js` following the load-bearing contract: `fetch → rebase → write event → add → commit → push (retry on conflict) → project → verify deterministic tie-breaker → if lost, auto-emit task.released`
- [ ] Implement `tick claim` using `claim.js`
- [ ] Write `concurrent-claim.sh`, `projection-idempotent.sh`, and `auto-sync.sh` tests. The auto-sync test verifies critical events trigger a push and non-critical events don't.

**Done when:** running `concurrent-claim.sh` (which simulates network ordering by manipulating two local clones of a bare remote) shows two agents claiming the same task, exactly one wins deterministically, the loser auto-releases. `auto-sync.sh` confirms the push pattern.

### Day 3 — Path-scoped routing

- [ ] Implement `paths.js`: glob overlap detection. Given a candidate task's `paths` and a set of currently-claimed paths from other agents, return whether they overlap. Use a simple library like `micromatch` if needed; this is the one allowed dependency.
- [ ] Implement `tick next --agent <id>`: read `STATE.md`, find tasks not yet claimed, filter out any whose paths overlap currently-claimed paths from *other* agents, return the highest priority remaining.
- [ ] Add `--paths` flag to `tick claim`
- [ ] Write `path-overlap.sh`: agent-A claims TASK-007 with `paths: ["src/auth/**"]`. Agent-B calls `tick next` — does NOT receive any task whose paths overlap `src/auth/**`. Receives the next compatible task instead.

**Done when:** the test passes. Two agents claiming overlapping path scopes are routed to non-overlapping work automatically.

### Day 4 — Pivots: scope change, handoff, circuit break

- [ ] Implement `tick scope <task> --agent <id> --paths <globs>`: emits `task.scope_changed`. Projection updates the active claim's paths to the union (or replacement, document which) of old + new paths.
- [ ] Implement `tick release <task> --agent <id> [--to <agent>]`: emits `task.released` with optional `to_agent`. If `to_agent` is set, that agent's `tick next` prioritizes this task as a handoff.
- [ ] Implement `tick break <task> --agent <id> --reason "..."`: emits `task.circuit_break`. Projection marks the task as `circuit_broken` and excludes from `tick next` for all agents.
- [ ] Write `scope-change.sh`: agent-A claims with `["src/auth/**"]`, then expands scope to `["src/auth/**", "src/middleware/**"]`. Agent-B's `tick next` no longer returns tasks touching `src/middleware/**`.
- [ ] Write `handoff.sh`: agent-A releases TASK-007 with `--to agent-B`. Agent-B's `tick next` returns TASK-007 even if a higher-priority task exists.
- [ ] Write `circuit-break.sh`: agent-A breaks TASK-007. Agent-B's `tick next` skips TASK-007.

**Done when:** all three pivot tests pass. `STATE.md` clearly shows broken tasks, handoffs, and current scope per claim.

### Day 5 — Real-agent hand-test + validation

This is the day that answers the actual question: **will Claude Code, Codex, or Gemini reliably call the CLI when prompted to?** The mechanical tests on Days 1–4 prove the protocol works; this day proves whether agents will use it.

- [ ] Write `README.md` with three sections:
  - **Worktree setup** — concrete commands for one `git worktree` per agent, all pointing at the same coordination branch.
  - **Agent integration prompt snippet** — paste-ready text to add to an agent's system prompt or project instructions: "Before editing files, run `tick next --agent <your-id>`. Claim with `tick claim <task> --paths <globs>` declaring every file glob you'll touch. Emit `tick scope` if scope expands. Run `tick done` on completion."
  - **Multi-agent flow** — how to seed the event log with 4–5 non-overlapping tasks before starting agents.
- [ ] Run the hand-test: spin up two real agents (any two of Claude Code / Codex / Gemini) in separate worktrees with the integration prompt loaded. Seed `.tick/events/` with tasks. Let them run for 30–60 minutes on a small fixture codebase.
- [ ] Observe and write `REAL-AGENT-OBSERVATIONS.md` answering, for each agent:
  - Did it call `tick next` before editing? (yes / no / inconsistent)
  - Did its declared paths match its actual edits? (yes / no / partial)
  - Did it emit `tick scope` when expanding? `tick done` on completion? `tick break` when stuck?
  - What did the integration prompt need to say to make compliance reliable?
  - What enforcement, if any, did the agent need beyond prompting? (file watcher, pre-commit hook, etc.)
- [ ] Run `validate.sh`, confirm all mechanical tests still pass
- [ ] Write `RECAP.md` synthesizing observations into a graduate / iterate / abandon recommendation
- [ ] Open draft PR

**Done when:** `validate.sh` exits 0, `REAL-AGENT-OBSERVATIONS.md` documents at least one real-agent run, `RECAP.md` is written, draft PR is open.

---

## Acceptance criteria (validate.sh runs all of these)

1. **Concurrent same-task claim:** two simulated agents append `task.claimed` events for the same task within 1 second of each other. After `tick project`, exactly one is recorded as `claimed_by`, the other has an auto-`task.released` event in the log. Tie-breaker is deterministic across runs.

2. **Path-overlap routing:** with TASK-007 claimed by agent-A using `paths: ["src/auth/**"]` and TASK-008 also touching `src/auth/**` declared in its task.created event, agent-B's `tick next` does NOT return TASK-008 even if TASK-008 has higher priority. Returns the next compatible task instead.

3. **Scope expansion:** agent-A claims TASK-007 with `paths: ["src/auth/**"]`, then `tick scope` to `["src/auth/**", "src/middleware/**"]`. Agent-B's `tick next` immediately stops returning tasks touching `src/middleware/**`.

4. **Targeted handoff:** agent-A `tick release TASK-007 --to agent-B`. Agent-B's next `tick next` returns TASK-007 even when other tasks have higher base priority.

5. **Circuit breaker:** after `tick break TASK-007`, no agent's `tick next` returns TASK-007. The task is visible in `STATE.md` as broken with reason and breaking agent.

6. **Projection idempotency:** running `tick project` twice in a row produces byte-identical `STATE.md` files. (No timestamps in the body, only in events.)

7. **Auto-sync pattern:** running each critical-event verb (`claim`, `scope`, `release`, `break`, `done`) against a local clone with a configured remote results in exactly one `git push` per verb. Running `tick log task.commented` results in zero pushes (event is committed locally only).

**Plus a Day 5 qualitative deliverable** (not part of validate.sh, but required for a passing spike): `REAL-AGENT-OBSERVATIONS.md` documenting at least one real-agent end-to-end run with answers to the four observation questions in Day 5.

---

## Implementation notes

- **Node.js version:** match whatever AI-DDTK currently pins. Don't bump it.
- **JSONL format:** one event per file, not one event per line in a shared file. The whole point is disjoint files.
- **Timestamps:** ISO 8601 with millisecond precision and explicit timezone offset. UTC preferred but not required if the rest of AI-DDTK uses local time — be consistent with existing convention.
- **Git interaction is the sync primitive.** Critical-event verbs auto-fetch+rebase+commit+push. Non-critical verbs write locally only. The agent's normal commit cadence picks up batched comments. Document this in `README.md` so users know what hits the remote and when.
- **Push retry policy:** on push rejection (someone else pushed first), one re-fetch + rebase + retry. If second attempt also fails, abort with a clear error and let the agent decide whether to retry or pick a different task. Do not loop indefinitely.
- **Single branch only.** All coordinating agents must work on the same branch. Cross-branch coordination is Phase 2.
- **Worktree isolation:** README must explain how to create one `git worktree` per agent so that filesystem-level edits don't collide even if path-scoping is sloppy. Show concrete commands.
- **Glob library:** `micromatch` is the one allowed dependency if needed for path-overlap detection. If you can do it correctly with plain string-prefix logic, do that and skip the dep.
- **Filenames must sort lexicographically by time.** ISO timestamps already do this; just don't get clever.
- **No log levels, no structured logging library.** `console.log` is fine for the spike.
- **Tests are bash scripts.** Each test sets up a temp directory (often a bare remote + two clones to simulate distributed agents), runs CLI commands, asserts on file contents and `git log` with `grep` / `jq` / `diff`. Exit 0 = pass, exit 1 = fail. `validate.sh` runs them in order and aggregates.

---

## When to stop

The spike is done when **either**:

- All seven mechanical acceptance criteria pass, `REAL-AGENT-OBSERVATIONS.md` documents at least one real-agent run, and `RECAP.md` is written → open draft PR, end.
- Day 5 ends with criteria still failing or no real-agent run completed → write `RECAP.md` honestly explaining why, recommend abandon or revise scope, end.

Do not extend the time-box. Do not skip the real-agent run — it is the load-bearing deliverable. Mechanical tests prove the protocol; the real-agent run proves whether agents will use it. Without that, you've built a tool nobody will adopt.

---

## Open questions (capture in RECAP.md, do not solve in spike)

- **Projection-after-push race (observe, do not design around):** between `git push` succeeding and `tick project` reading the projected state, another agent's claim event can land. The deterministic tie-breaker handles correctness (earliest timestamp wins regardless of push order), but it means the "winner" of a `tick claim` call can flip on subsequent re-projects until events settle. The `concurrent-claim.sh` test should explicitly exercise this — push agent-A's claim, then push agent-B's earlier-timestamped claim, then re-project and verify agent-B wins, agent-A auto-releases. Document the observed behavior in RECAP.md. Not a bug; the protocol is honest about it.
- Does the optimistic-claim approach hold up with 5+ concurrent agents, not just 2?
- Is path-overlap detection by glob sufficient, or do we need AST-aware scoping (e.g., function-level claims within the same file)?
- What enforcement, if any, is needed beyond prompting? File watcher? Pre-commit hook that rejects commits touching files outside the active claim's paths?
- How do we handle agents that declare paths they don't end up touching, or touch paths they didn't declare? Post-hoc reconciliation or trust-and-verify?
- Should `tick break` require a confidence threshold or human ASK before firing, given AI-DDTK's existing ASK_HUMAN convention?
- How do we squash or compact the coordination commit history once a task lifecycle completes?
- Cross-branch coordination — how would it work?
- Phase 2 priority order: WPCC adapter, Git Pulse upgrade, ask-self ingest, MCP tools — which earns its keep first?

These are graduation-time decisions, not spike-time decisions.

---

## Spike findings (2026-05-04)

Days 1-4 mechanical scope completed in one Claude Code session. All 7 acceptance criteria pass:

```
$ ./experiments/coordination-layer/validate.sh
passed: 7 / 7
  + projection-idempotent.sh
  + concurrent-claim.sh
  + path-overlap.sh
  + scope-change.sh
  + handoff.sh
  + circuit-break.sh
  + auto-sync.sh
```

**Code:** ~600 lines of JS in `experiments/coordination-layer/src/` + `bin/tick`. ~400 lines of bash tests. No new runtime dependencies (skipped `micromatch` — conservative literal-prefix overlap detection in [src/paths.js](../../experiments/coordination-layer/src/paths.js) was sufficient).

### What landed

- `tick` CLI with all 8 verbs from the scope (init, log, project, claim, next, scope, release, break, done).
- Single-pass projection with deterministic tie-breaker (earliest ts → lex agent ID).
- Auto-push contract for critical events (claim/scope/release/break/done = 1 push each; commented = 0 pushes).
- Bare-remote + two-clone test harness simulating distributed agents.
- README with worktree setup, agent integration prompt snippet, and multi-agent flow.

### What surprised us

- **Projection sequencing bug (caught + fixed in-session):** initial two-pass projection processed `scope_changed` before claim winners were resolved, silently dropping scope expansions. Fix: bucket events per task, resolve winning claim first, then walk the timeline applying scope/handoff/terminal events. Caught immediately by `scope-change.sh`.
- **One-shot `tick claim` is not a reliable mutex.** It is a best-effort soft claim that resolves correctly given enough time and re-projections. In `concurrent-claim.sh`, agent A's first `tick claim` returned `won=true` even though agent B's earlier-timestamped (but later-arriving) claim would eventually beat it — A only learned it lost on its *next* claim/project. The protocol is honest about this, but if Phase 2 wants strong-mutex semantics it'll need a `tick claim --confirm` second-phase verb.
- **Worktree friction is worse than expected.** `git worktree add` refuses to check out the same branch twice; the README documents a per-agent-child-branch workaround that is friction enough it could kill adoption. Phase 2 should consider a separate ref for `.tick/` or an out-of-band sync daemon.

### What still needs to happen (Day 5)

- **Real-agent hand-test.** Spin up two of {Claude Code, Codex, Gemini} in worktrees with the integration prompt loaded; let them run on a fixture for 30-60 min; fill in [REAL-AGENT-OBSERVATIONS.md](../../experiments/coordination-layer/REAL-AGENT-OBSERVATIONS.md). This is the load-bearing deliverable. Mechanical correctness ≠ adoption.
- **Decide:** if compliance is high, pick which Phase 2 integration earns its keep first. If low, iterate the integration prompt before declaring the protocol broken.