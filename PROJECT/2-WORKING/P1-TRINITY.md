# AI-DDTK Coordination Layer — Experimental Spike

**Branch:** `experiment/coordination-layer`
**Codename:** Trinity (for Claude Code, Codex, Gemini)
**Time-box:** 5 working days
**Owner:** Noel / Hypercart
**Status:** Spike. If acceptance criteria pass, write a 1-page recap and open a draft PR. If they don't, delete the branch and write a 1-page post-mortem.

---

## Prompt for Claude Code Cloud

> You are building an experimental coordination layer for AI-DDTK on a new branch `experiment/coordination-layer`. Read this entire document before writing any code.
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
- **Hash chain (cheap, include it):** every event includes `parent_hash` = sha256 of the immediately prior event file. Tamper-evident. ~10 lines of code. No signing.
- **Event types (initial set):** `task.created`, `task.claimed` (with `paths`), `task.released` (with optional `to_agent` for handoff), `task.scope_changed` (with new `paths`), `task.commented`, `task.done`, `task.circuit_break`. Seven types. The computed *states* (open, claimed, broken, done) are still ≤4, so no FSM library needed.

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
├── README.md                    # short, points back to this doc + worktree setup notes
├── TODO_DEFER.md                # things you wanted to build but didn't
├── package.json                 # only if a new dep is unavoidable
├── bin/
│   └── tick                     # CLI entry point
├── src/
│   ├── events.js                # append, hash-chain, validate
│   ├── project.js               # event log → STATE.md
│   ├── claim.js                 # optimistic claim + reconciliation
│   ├── paths.js                 # glob overlap detection for path-scoped routing
│   └── scope.js                 # scope_changed + release-with-handoff
├── test/
│   ├── concurrent-claim.sh      # two agents, simultaneous claim, deterministic winner
│   ├── path-overlap.sh          # two agents, overlapping paths, second is routed elsewhere
│   ├── scope-change.sh          # mid-task scope expansion is honored by other agents
│   ├── handoff.sh               # release --to <agent> prioritizes targeted handoffs
│   ├── circuit-break.sh         # break event makes other agents skip
│   ├── projection-idempotent.sh # tick project twice = identical STATE.md
│   └── hash-chain.sh            # tampered event is detected
├── validate.sh                  # runs all of the above, exits 0/1
└── RECAP.md                     # written at the end: what worked, what didn't
```

A bare-repo `.tick/` directory is created by `tick init` (sixth verb, fine to add — it's just `mkdir -p`). Do not add other init logic.

---

## Roadmap (5 days)

### Day 1 — Event log + CLI scaffold

- [ ] Create branch, scaffold directory layout above
- [ ] Implement `events.js`: `appendEvent({type, task, agent, note, parentHash})` writes one JSONL file with computed hash chain
- [ ] Implement `bin/tick` with `tick init` and `tick log` only
- [ ] Hand-test: append 5 events, verify hash chain by reading file order

**Done when:** `tick log task.created TASK-001 --agent gianni` creates a valid JSONL file with a parent_hash referencing the previous event (or `null` for the first).

### Day 2 — Projection + claim reconciliation

- [ ] Implement `project.js`: read all `.tick/events/*.jsonl` in timestamp order, fold into in-memory state, write `STATE.md` with a generated-banner header
- [ ] Implement `tick project`
- [ ] Implement `claim.js` with the deterministic tie-breaker (earliest ts, then lex agent ID)
- [ ] Implement `tick claim` (append + project + verify)
- [ ] Write `concurrent-claim.sh` and `projection-idempotent.sh` tests

**Done when:** running `concurrent-claim.sh` shows two simulated agents claiming the same task simultaneously, projection picks one winner deterministically, loser has an auto-emitted `task.released` event.

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

### Day 5 — Worktree wiring + validation

- [ ] Write `README.md` with a "Multi-agent worktree setup" section: how to create one worktree per agent, how to point each agent at the same `.tick/` directory (it's at the repo root, shared across worktrees by virtue of being in the main checkout), how Claude Code / Codex / Gemini each invoke the CLI.
- [ ] Hand-test the full multi-agent flow: spin up two terminal sessions in two worktrees pointing at the same repo, manually simulate two agents claiming non-overlapping scopes, verify they don't collide on push.
- [ ] Run `validate.sh`, confirm all tests pass
- [ ] Write `RECAP.md`: what worked, what didn't, recommendation (graduate to Phase 2 / iterate on substrate / abandon)
- [ ] Open draft PR

**Done when:** `validate.sh` exits 0, RECAP.md is written, draft PR is open, README documents the worktree pattern with concrete commands.

---

## Acceptance criteria (validate.sh runs all of these)

1. **Concurrent same-task claim:** two simulated agents append `task.claimed` events for the same task within 1 second of each other. After `tick project`, exactly one is recorded as `claimed_by`, the other has an auto-`task.released` event in the log. Tie-breaker is deterministic across runs.

2. **Path-overlap routing:** with TASK-007 claimed by agent-A using `paths: ["src/auth/**"]` and TASK-008 also touching `src/auth/**` declared in its task.created event, agent-B's `tick next` does NOT return TASK-008 even if TASK-008 has higher priority. Returns the next compatible task instead.

3. **Scope expansion:** agent-A claims TASK-007 with `paths: ["src/auth/**"]`, then `tick scope` to `["src/auth/**", "src/middleware/**"]`. Agent-B's `tick next` immediately stops returning tasks touching `src/middleware/**`.

4. **Targeted handoff:** agent-A `tick release TASK-007 --to agent-B`. Agent-B's next `tick next` returns TASK-007 even when other tasks have higher base priority.

5. **Circuit breaker:** after `tick break TASK-007`, no agent's `tick next` returns TASK-007. The task is visible in `STATE.md` as broken with reason and breaking agent.

6. **Projection idempotency:** running `tick project` twice in a row produces byte-identical `STATE.md` files. (No timestamps in the body, only in events.)

7. **Hash chain integrity:** a script walks all events in order, verifies every `parent_hash` matches the sha256 of the actual previous file. A tampered event is detected.

---

## Implementation notes

- **Node.js version:** match whatever AI-DDTK currently pins. Don't bump it.
- **JSONL format:** one event per file, not one event per line in a shared file. The whole point is disjoint files.
- **Timestamps:** ISO 8601 with millisecond precision and explicit timezone offset. UTC preferred but not required if the rest of AI-DDTK uses local time — be consistent with existing convention.
- **Git interaction:** the spike does not need to do its own commits. Assume the user/agent commits and pushes as part of their normal flow. Document this in `README.md`.
- **Worktree isolation:** README must explain how to create one `git worktree` per agent so that filesystem-level edits don't collide even if path-scoping is sloppy. Show concrete commands for adding a worktree, pointing it at a feature branch, and how the shared `.tick/` directory is reachable from each.
- **Glob library:** `micromatch` is the one allowed dependency if needed for path-overlap detection. If you can do it correctly with plain string-prefix logic, do that and skip the dep.
- **Filenames must sort lexicographically by time.** ISO timestamps already do this; just don't get clever.
- **No log levels, no structured logging library.** `console.log` is fine for the spike.
- **Tests are bash scripts, not a test framework.** Each test sets up a temp directory, runs CLI commands, asserts on file contents with `grep` / `jq` / `diff`. Exit 0 = pass, exit 1 = fail. `validate.sh` runs them in order and aggregates.

---

## When to stop

The spike is done when **either**:

- All seven acceptance criteria pass and `RECAP.md` is written → open draft PR, end.
- Day 5 ends with criteria still failing → write `RECAP.md` honestly explaining why, recommend abandon or revise scope, end.

Do not extend the time-box. Do not skip writing the recap. The recap is the deliverable; the code is just evidence.

---

## Open questions (capture in RECAP.md, do not solve in spike)

- Does the optimistic-claim approach hold up with 5+ concurrent agents, not just 2?
- Is path-overlap detection by glob sufficient, or do we need AST-aware scoping (e.g., function-level claims within the same file)?
- What happens when an agent declares paths it doesn't end up touching, or touches paths it didn't declare? Is post-hoc reconciliation needed, or is honest declaration good enough?
- Should `tick break` require a confidence threshold or human ASK before firing, given AI-DDTK's existing ASK_HUMAN convention?
- What's the deletion policy for completed events? Compaction? Archival? (Spike does nothing.)
- Phase 2 priority order: WPCC adapter, Git Pulse upgrade, ask-self ingest, MCP tools — which earns its keep first?

These are graduation-time decisions, not spike-time decisions.