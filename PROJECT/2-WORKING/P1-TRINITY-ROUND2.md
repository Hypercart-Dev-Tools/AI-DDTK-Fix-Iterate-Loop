# Trinity — Run 2 retrospective and Run 3 plan

**Parent:** [`P1-TRINITY.md`](P1-TRINITY.md)
**Branch:** Run 2 ran on `experiment/coordination-layer`; **Run 3 runs on `development`** (where all Run 3 fixes — `tick take` guard, `tick ping`/heartbeat, parked-claim detection, `run3-prompts/` — are committed).
**Owner:** Noel / Hypercart
**Run dates:** 2026-05-14 (start) → 2026-05-15 (close)
**Agents:** Gemini (Google), Codex (OpenAI)
**Coordinator / orchestrator:** Claude Code (observes only — does not claim or code)

---

## What Run 2 was testing

Run 1 (2026-05-06) collapsed immediately: Gemini claimed all 3 tasks in 33 seconds, Codex was starved, Gemini crashed with zero work output.

Run 2 added a per-agent claim cap (max 2 active claims), a manual `tick reap` liveness lever, and switched from the git-push-per-event transport to a shared local `.tick/events/` directory. The test question: **with a claim cap in place, will two agents sustain parallel work on separate halves of a real app?**

---

## What happened

All 6 tasks completed. Zero circuit breaks. Zero file collisions. The cap held throughout — no agent exceeded 2 active claims. The two halves (HTTP layer / store layer) stayed separate: path-routing kept agents on their own side without any collision.

The run spanned two calendar days due to session interruptions, which made the primary success metric (concurrent-claim-time) uninterpretable. The analyzer reported 0% concurrent overlap, but the 21-hour window was dominated by idle time between sessions — not actual agent inactivity. A single-session run would have shown genuine overlap.

### Event log summary

| Metric | Value |
|---|---|
| Run window | `2026-05-14T20:13:47Z` → `2026-05-15T17:21:31Z` |
| Total events | 18 (created: 6, claimed: 6, done: 6) |
| Circuit breaks | 0 |
| Releases | 0 |
| Concurrent-claim time | 2m 9s / 21h (0% — misleading; see above) |

### Per-agent compliance

| Agent | Claimed | Done | Protocol compliance |
|---|---|---|---|
| Gemini | 4 | 4 | Clean — both halves, claimed before editing, `tick done` on every task |
| Codex | 2 | 2 | Clean — store half, after resolving initial git identity issue |

---

## What each agent struggled with

Both agents provided post-run feedback independently. The overlap is significant: the two biggest problems were flagged by both without prompting.

### Both agents flagged

**1. `tick next` → `tick claim` race**
The two-step protocol has a TOCTOU gap. Codex lost TASK-B3 to it; Gemini lost TASK-B1 momentarily. An agent calls `tick next`, gets a task ID, then calls `tick claim` — but another agent can claim the same task in between. Both agents independently asked for an atomic combined command.

**2. Git identity interference**
`git config user.name` flips between agents as each configures their identity in the shared repo. `tick`'s identity cross-check read this value and fired misleading warnings ("--agent gemini != git config user.name codex") throughout the run. Both agents flagged it as noise that undermined trust in the tooling.

### Codex only

**3. Lock file in `.git/` blocked by sandbox**
`src/lock.js` wrote the claim lock to `.git/tick-claim.lock`. Codex's sandbox environment restricts writes to `.git/`, forcing an escalation just to claim a task.

**4. `tick next` dirtied the working tree**
`tick next` called `project()` internally, which rewrote `STATE.md` even on a read-only operation. Every `tick next` made `git status` show unstaged changes.

**5. No ownership enforcement**
`tick done`, `tick release`, `tick break`, and `tick scope` accepted events from any agent for any task. Any agent knowing a task ID could mark another agent's task done.

### Gemini only

**6. No way to query task scope**
Path globs had to be copied verbatim from the integration prompt. If the task list or file structure changes, the prompt falls out of sync. Gemini asked for `tick info <TASK-ID>` to let agents query their scope dynamically.

---

## What was fixed before closing the session

All 6 items were implemented and committed on 2026-05-15. The Run 2 `validate.sh` covered `claim`/`scope`/`reap`/etc. but not the new critical-path verb `tick take`; that gap has since been closed during Run 3 prep (`test/take.sh`), and `tick ping` is covered too — `validate.sh` is now **12/12** (see "Run 3 prerequisites").

| Item | Files changed | What it does |
|---|---|---|
| Lock to `.tick/locks/` | `src/lock.js` | Claim lock lives in `.tick/locks/claim.lock` — no `.git/` writes |
| Ownership enforcement | `src/scope.js` | `done/release/break/scope` throw if `--agent` doesn't match the current claimer; only `tick reap` bypasses. Caveat: the ownership check is **not atomic** with the event append (no `withClaimLock`, unlike `take`), so a concurrent `reap` could in principle interleave. Low practical risk for Run 3 (these are the claimer's own single-window verbs), tracked as a hardening item. |
| `tick take` | `src/take.js`, `bin/tick` | New verb: atomic next+claim under one lock; uses task's own declared paths. Closes the `next`→`claim` TOCTOU **in this deployment** (single shared lock + shared `.tick/events/`); separate clones or any non-shared transport would reintroduce the soft-mutex gap. Now also refuses a candidate overlapping *any* active claim — including the agent's own — so one agent can't reserve two overlapping tasks in the same half. |
| Remove identity check | `bin/tick` | `checkAgentIdentity()` removed; `--agent` is the sole authoritative identity |
| `tick next` read-only | `src/next.js` | Folds events in memory; never writes `STATE.md` |
| `tick info <TASK-ID>` | `bin/tick` | Prints task id / status / priority / paths / claimer on demand |

---

## What Run 3 needs to answer

The load-bearing question from Run 2 is still open because the metric was uninterpretable: **does a per-agent claim cap produce sustained two-agent parallelism when both agents are active in the same session?**

### Why Run 2's metric can't answer it (and neither can the same-session fix alone)

The current `tick analyze` concurrent-claim metric measures **overlap of open *claim windows*, not overlap of real work** ([`analyze.js` `computeParallelism`](../../experimental/coordination-layer/src/analyze.js)): a claim window opens at `task.claimed` and stays open until a terminal event, and the run window runs from the *earliest* event (task **seeding**) to the latest. Two confounds survive same-session:

1. **Parked claims inflate overlap.** A claim held but idle counts as "active" for its full duration. In Run 2, Gemini held `TASK-A1` from `2026-05-14T20:15Z` until `2026-05-15T17:21Z` while nearly all real edits happened in a ~8-minute burst — that parked window alone would manufacture "overlap."
2. **Seeding is in the denominator.** The window starts at task creation, not first work.

Same-session removes the overnight *gap*, but not parked-claim overlap or the seeding offset.

### Redefined success criterion (Run 3)

Run 3 passes only if **all** of these hold:

- **Work-bounded window.** Measure concurrent-claim time over **first `task.claimed` → last `task.done`**, not earliest-event → latest-event. Seeding is excluded from the denominator.
- **≥ 50% concurrent-claim time** within that work-bounded window, with **both agents completing ≥ 2 tasks each**.
- **Disqualifier — parked claims.** Any claim held with no work-activity **heartbeat** for > 10 min invalidates the run (it indicates manufactured overlap, not parallel work). Agents emit heartbeats with `tick ping --agent <name> <TASK-ID>` while working (see the agent prompts); `tick analyze` reports `parked-claim suspects` directly from those `task.heartbeat` events — **no git-author or timestamp dependency** (Run 2 removed distinct git identity, so git-author attribution is unavailable). This replaces the earlier git-diff-timing idea, which could not attribute commits under the single-identity model.
- **Disqualifier — serial double-claim.** No agent may hold two overlapping claims (now enforced in `take.js`); if the event log shows it anyway, the run is invalid.
- **Cross-check.** Coordinator confirms by `git diff` that overlapping claim windows correspond to overlapping *real edits* on both halves — the overlap metric is necessary but not sufficient.

> **50% is a stress bar, not a proof bar.** Crossing it with the guards above is evidence the protocol *can* sustain parallelism in this narrow setup — it is not proof the coordination layer is production-viable (see Open questions).

### Caveats / known limitations (read before running)

- **The parked-claim check is an operational contract, not an inference engine.** It relies on agents actually calling `tick ping` while they work; the tool cannot detect work that produced no heartbeat. A forgotten ping looks identical to a parked claim. The intended handling is therefore **fail/retry the run, not silently treat a missing heartbeat as a pass** — if `tick analyze` reports a parked-claim suspect, treat the run as invalid and re-run, even if you suspect the agent was actually working. Do not relax this into "probably fine."
- **Concurrent-claim % is computed by hand.** `tick analyze`'s printed `concurrent-claim time` line still uses the *old* earliest-event→latest-event window — it is informational only. The pass/fail number comes from the manual work-bounded calculation in Wrap-up step 1. (Only the parked-claim line from `tick analyze` is authoritative.)
- **`tick take`'s race-freedom is deployment-specific.** It is atomic only because both agents share one lock + one `.tick/events/`. Separate clones or any non-shared transport reintroduce the soft-mutex gap — do not generalize this result to a distributed setup.
- **Coarse, half-wide path scopes.** Lane separation is validated at `src/http/**` vs `src/store/**` granularity only; this run does not test per-file drift within a half (deferred to Run 4).

### Run 3 prerequisites (before agents start)

- [x] Document the manual metric-computation procedure the coordinator runs (done — see Wrap-up step 1). The concurrent-claim pass/fail is executable by hand; the parked-claim disqualifier is now automated.
- [x] Parked-claim detection implemented: `tick ping` emits `task.heartbeat` events and `tick analyze` reports `parked-claim suspects` from them, with no git-identity dependency (covered by `test/heartbeat.sh`).
- [ ] *(optional, convenience)* Update [`analyze.js`](../../experimental/coordination-layer/src/analyze.js) to also compute the **work-bounded** concurrent-claim window (first `claimed` → last `done`) so steps 2–4 of the manual procedure can be skipped. Not required to run Run 3.
- [x] **(hard gate — now green)** `tick take` test added (`test/take.sh`): atomic next+claim, same-half double-claim refusal, claim cap, cross-agent lane separation. `validate.sh` is **12/12**. The run-start gate is satisfied.

---

## Run 3 plan

### Changes from Run 2

- Agents call **`tick take --agent <name>`** instead of `tick next` + `tick claim` (atomic claim, no TOCTOU).
- Agents emit a liveness **`tick ping --agent <name> <TASK-ID>`** heartbeat while working a task, so the parked-claim disqualifier has a work-activity signal independent of git identity. These two verbs are the only protocol changes visible to agents.
- Same 6 tasks, same split. The sandbox-app files from Run 2 can be cleared or the run can use a fresh fixture.
- Both agents must be in the same session window — no overnight gaps.

### Coordinator setup (before agents start)

1. Run on `development` — all Run 3 fixes are committed there (the plan originally said `experiment/coordination-layer`; Run 3 moved to `development`). Ensure your working tree is on `development` and up to date.
2. Archive Run 2's `.tick/events/` to `.tick/archive/run-2-events/`, re-init with `tick init`.
3. Re-seed the 6 tasks:
   ```bash
   TICK=./experimental/coordination-layer/bin/tick
   ROOT=.
   $TICK log task.created TASK-A1 --agent dispatcher --priority 10 \
     --paths "experimental/coordination-layer/sandbox-app/src/http/**,experimental/coordination-layer/sandbox-app/test/http/**"
   $TICK log task.created TASK-A2 --agent dispatcher --priority 8  \
     --paths "experimental/coordination-layer/sandbox-app/src/http/**,experimental/coordination-layer/sandbox-app/test/http/**"
   $TICK log task.created TASK-A3 --agent dispatcher --priority 5  \
     --paths "experimental/coordination-layer/sandbox-app/src/http/**,experimental/coordination-layer/sandbox-app/test/http/**"
   $TICK log task.created TASK-B1 --agent dispatcher --priority 10 \
     --paths "experimental/coordination-layer/sandbox-app/src/store/**,experimental/coordination-layer/sandbox-app/test/store/**"
   $TICK log task.created TASK-B2 --agent dispatcher --priority 8  \
     --paths "experimental/coordination-layer/sandbox-app/src/store/**,experimental/coordination-layer/sandbox-app/test/store/**"
   $TICK log task.created TASK-B3 --agent dispatcher --priority 5  \
     --paths "experimental/coordination-layer/sandbox-app/src/store/**,experimental/coordination-layer/sandbox-app/test/store/**"
   ```
4. Clear sandbox-app source files (keep directory structure and `package.json`).
5. **Do not start the agents until both Run 3 prerequisite checkboxes (above) are complete.** Then paste the contents of `experimental/coordination-layer/run3-prompts/START-HERE.md` into both agent sessions simultaneously.

### Agent start prompt

Paste everything below the `===` in `experimental/coordination-layer/run3-prompts/START-HERE.md`. The Run 3 prompt files (`run3-prompts/codex.md`, `run3-prompts/gemini.md`) are already corrected for the Run 2 changes: they use the single `tick take` verb (no `tick next` + `tick claim`), drop the removed git-identity check, use the `experimental/` path, and note that `tick` verbs are local event appends (no auto-commit/push). The Run 2 prompt files under `run2-prompts/` are kept only as a historical record — **do not paste them.**

### Stop conditions (same as Run 2)

- Agent holds a claim and is silent > 15 min → `tick reap <agent> --by coordinator`
- **File collision** → flag immediately. Note: `tick analyze` does **not** detect collisions — drift/collision detection is deferred (the git transport was removed, so there are no work commits to attribute). The coordinator catches collisions by inspecting `git diff` by hand, watching both halves stay on their own paths.
- Both agents done all 6 tasks, or 60-min box expires

### Wrap-up

1. **Run `tick analyze`** for the parked-claim check, then **compute the concurrent-claim pass/fail manually** (the `concurrent-claim time` line `tick analyze` prints still uses the *old* earliest-event→latest-event window — treat it as informational only, not the pass/fail number; the `parked-claim suspects` line, however, is authoritative). Procedure:
   1. Dump the event log in time order:
      `cat .tick/events/*.jsonl` (one JSON object per file; read `type`, `task`, `agent`, `ts`).
   2. **Work-bounded window** = `[ earliest ts where type == task.claimed , latest ts where type == task.done ]`. Ignore `task.created` (seeding) timestamps entirely.
   3. **Per-agent claim intervals:** for each agent, each interval runs from a `task.claimed` to that task's next terminal event (`task.done` / `task.released` / `task.circuit_break`). Clip every interval to the work-bounded window.
   4. **Concurrent-claim time** = total wall-clock inside the window during which **both** agents have ≥ 1 open (clipped) interval. **Pass requires ≥ 50%** of the window, **and** each agent has ≥ 2 `task.done`.
   5. **Disqualifier — parked claims:** read the `parked-claim suspects` line from `tick analyze` (it flags any claim window with a > 10 min gap between heartbeats / claim / close, computed from `task.heartbeat` events). **Any suspect invalidates the run.** No git inspection needed.
   6. **Disqualifier — serial double-claim:** scan for any agent holding two overlapping-path claims simultaneously. (`take.js` now refuses this; if the log shows it, the run is invalid.)
   > Optional: if the `analyze.js` work-bounded-window prerequisite is also implemented, read its fields directly and skip steps 2–4. (The parked-claim flag in step 5 is already implemented.)
2. Walk the per-agent compliance numbers (including heartbeat counts), then run the manual `git diff` cross-check (overlapping claim windows correspond to overlapping *real edits* on both halves).
3. Coordinator integrates the two halves and boots the app.
4. Append a Run 3 section to `RECAP.md` and update this doc's status.

---

## Open questions for Run 3+

- **Concurrent-claim-time threshold:** 50% is the working target. Is that the right bar, or is any sustained overlap sufficient to call the protocol viable?
- **Same-session constraint:** is requiring both agents in the same session realistic for real-project use, or does the protocol need a durable handoff mechanism (TTL / auto-reap) to handle async workflows?
- **Intra-half drift:** half-wide path scopes (e.g. `src/http/**`) make drift detection coarse. If Run 3 passes, Run 4 should test per-file scopes and measure whether agents stay within them.
- **Phase 2 readiness:** if Run 3 hits the metric, the next decision is which Phase 2 integration earns its keep first — WPCC adapter, Git Pulse, MCP wrapping, or ask-self ingest.
