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
