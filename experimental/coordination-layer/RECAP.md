# Trinity spike — recap

**Status:** Days 1-4 mechanical work compressed into a single Claude Code session on 2026-05-04. All 7 mechanical acceptance criteria pass. Day 5 real-agent hand-test deferred to a separate session.

## What worked

- **Disjoint-files-per-event** as the merge-conflict strategy. Two agents pushing claim events for different tasks in the same second produce zero conflicts because each writes a uniquely-named file.
- **Deterministic tie-breaker (earliest ts, then lex agent ID)** in projection. The `concurrent-claim.sh` test simulates the worst case — agent A pushes first but with a *later* timestamp than agent B's earlier-but-arrived-second claim — and projection consistently picks B as the winner across runs.
- **Auto-push contract on critical events** is a clean abstraction. The `auto-sync.sh` test verifies each of `claim/scope/release/break/done` produces exactly one remote commit, and `task.commented` produces zero.
- **Path-overlap routing via literal-prefix overlap** (no `micromatch` dependency) was sufficient for every test scenario — over-reports overlap (safer) but never misses one. If real-agent runs don't show starvation, leave it as-is.
- **Single-pass projection that resolves the winning claim first, then replays scope/handoff/terminal events** ([src/project.js](src/project.js)). The first cut had a sequencing bug — `scope_changed` ran before claims were resolved, so scope expansions were dropped on the floor. Fixed in the same session by computing the winner up front, then walking the timeline.

## What didn't work the first time

- **Initial projection sequencing.** Two-pass (events first, claims second) silently dropped `scope_changed` events because the claim wasn't yet bound when `scope_changed` was processed. Fix: bucket events per task, resolve the winning claim, then walk the bucket. Caught immediately by `scope-change.sh`.

## What we learned

- The **projection-after-push race** flagged in P1-TRINITY.md is real and observable. When agent A pushes a claim with ts=T1, then agent B pushes a claim with earlier ts=T0, A's `tick claim` returned `won=true` because A only saw its own event when it re-projected. A only learns it lost on the *next* `tick claim` or `tick project` after B's event arrives. The protocol is honest about this — the test exercises it explicitly — but it means agents must re-check before doing irreversible work, or a second `tick claim --confirm` verb (Phase 2) needs to gate the actual edits. **Concrete observation: a one-shot `tick claim` is not a reliable mutex; it is a best-effort soft claim that resolves correctly given enough time and re-projections.**
- **Worktree friction is worse than expected.** `git worktree add` refuses to check out the same branch twice. The README documents the workaround (per-agent child branches that push to the coordination ref), but this is enough friction that it could kill adoption. Phase 2 should consider either a separate ref for `.tick/` or an out-of-band sync daemon so agents can stay on their own branches.
- **The CLI is small (~600 lines of JS) but the tests are larger (~400 lines of bash) and were the slow part of the session.** Test-first would have caught the projection sequencing bug a step earlier. Worth the time investment — the protocol's correctness lives in the projection logic, and projections are easy to get wrong silently.

## What's next

Three live decisions, in order:

1. **Run the Day 5 real-agent hand-test** (the load-bearing deliverable). Fill in [REAL-AGENT-OBSERVATIONS.md](REAL-AGENT-OBSERVATIONS.md). Without this, the spike is incomplete — mechanical correctness ≠ adoption.
2. **If real-agent compliance is high → Phase 2.** Decide enforcement strategy (pre-commit hook? file watcher?) and pick which Phase 2 integration earns its keep first (WPCC adapter, Git Pulse, ask-self ingest, MCP wrapping).
3. **If real-agent compliance is low → revise.** The likely culprit is prompt friction or missing enforcement. Iterate on the integration snippet in README.md before declaring the protocol broken.

## Open questions surfaced (not solved)

All forwarded from P1-TRINITY.md plus:

- Is one-shot `tick claim` enough, or do we need `tick claim --confirm` as a second-phase mutex after re-projection settles?
- The path-overlap conservatism may starve agents whose tasks overlap in the literal prefix but not in actual files. Worth measuring in real-agent runs.
- Worktree friction — how badly does the per-child-branch workaround degrade the experience?

## Validate

```bash
cd experiments/coordination-layer
./validate.sh
# expected: passed: 7 / 7
```

---

## Run 2 — 2026-05-14–15

### What happened

Run 2 used a 6-task Todo REST API split into two halves (HTTP layer / store layer), with Gemini and Codex as peer agents on a shared local repo using the new local-transport model (no git push per event). All 6 tasks were completed with zero circuit breaks and zero file collisions. The claim cap held throughout — no agent exceeded 2 active claims.

The run spanned two calendar days due to session interruptions, which made the primary metric (concurrent-claim-time) uninterpretable: the 21h wall-clock window dominated by idle time produced 0% overlap even though agents were genuinely doing work when active.

### Compliance

- **Gemini:** 4 claimed / 4 done — both halves, clean protocol compliance
- **Codex:** 2 claimed / 2 done — store half, clean protocol compliance after initial git identity resolution

### Agent feedback (post-run)

Both agents independently surfaced the same two issues:

1. **`tick next` → `tick claim` race** — Codex lost TASK-B3, Gemini lost TASK-B1 momentarily to this gap.
2. **Git identity interference** — `git config user.name` flipped between agents in the shared repo, making `tick`'s identity warning noisy and unreliable.

Codex additionally flagged: lock in `.git/` (sandbox-blocked), `tick next` dirtying the working tree, ownership not enforced on `done/release/break`.

Gemini additionally flagged: no way to query task paths without copying from the prompt.

### Post-run improvements shipped

All 6 items from the agent feedback were implemented before closing the session:

- Lock moved to `.tick/locks/` (unblocks sandboxed environments)
- Ownership enforcement on `done/release/break/scope`
- `tick take` — atomic next+claim under one lock
- Git identity cross-check removed; `--agent` is authoritative
- `tick next` made read-only (no STATE.md write)
- `tick info <TASK-ID>` added

`validate.sh`: **10/10** green.

### Recommendation

**Iterate — Run 3 with same-session agents.** The protocol is sound; the measurement gap is operational. All known friction points are resolved. Run 3 success criterion: ≥50% concurrent-claim-time in a single session using `tick take`.

## Run 3 — 2026-06-14

### What happened

Run 3 re-ran the same 6-task split (HTTP / store) in a single session with the redefined success criterion (work-bounded window + parked-claim and serial-double-claim disqualifiers + heartbeats). All 6 tasks completed, **26/26 sandbox-app acceptance tests pass**, 0 collisions, 0 circuit breaks, 0 parked-claim suspects. The agent-facing changes worked: `tick take` (atomic claim, no observed race) and `tick ping` (heartbeats honored throughout).

The headline: the run was **mechanically flawless but missed the metric**. Work-bounded concurrent-claim time was **40%, below the ≥50% bar**.

### Compliance

- **Gemini:** 3 claimed / 3 done (HTTP half) / 3 heartbeats — clean
- **Codex:** 3 claimed / 3 done (store half) / 6 heartbeats — clean

### Why the metric missed

Gemini finished its HTTP half fast and went idle for the final ~1m 33s while Codex finished the store half alone. Genuine overlap happened early (~1m 27s of a 3m 37s work-bounded window), but a static per-half split gives the faster agent nothing to do once its lane is drained — no work-stealing across halves. So sustained overlap capped at 40%.

### Recommendation

**Iterate — Run 4 targets load balance, not mechanics.** The coordination layer is proven (atomic claims, lane separation, heartbeats, clean completion); the gap is that static partitioning lets the faster agent idle. Run 4 options: work-stealing across halves, finer/interleaved task split, or a balance-matched fixture — then retest the ≥50% bar. Not "graduate" (bar not cleared) and not "abandon" (flawless run, near-miss). `validate.sh`: **12/12** green (`tick take` + `tick ping` now tested).
