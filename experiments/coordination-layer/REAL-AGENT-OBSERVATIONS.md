# Real-agent hand-test observations

Template for the Day 5 deliverable. Fill in observations for each agent that participates in a hand-test.

> **Tip:** the objective questions below (claimed before editing? declared paths matched edits? used scope/done/break?) can be answered automatically by `./bin/tick analyze --write REAL-AGENT-OBSERVATIONS.md`. Run it after the session and let the analyzer fill in the per-agent compliance numbers and drift examples; you only need to write the subjective sections (what the prompt needed, what felt like friction) and the synthesis.

## Run metadata

- **Date:** _(YYYY-MM-DD)_
- **Duration:** _(e.g. 45 minutes)_
- **Fixture codebase:** _(path or short description)_
- **Seeded tasks:** _(how many, what scopes)_
- **Worktree topology:** _(one per agent / shared / other)_

## Per-agent observations

For each of Claude Code, Codex, Gemini that participated:

### Agent: _(name)_

- **Did it call `tick next` before editing?** _(yes / no / inconsistent — describe pattern)_
- **Did its declared paths match its actual edits?** _(yes / no / partial — quantify if possible: "matched on 4 of 6 claims, drifted into shared utils on 2")_
- **Did it emit `tick scope` when expanding mid-task?** _(yes / no / never needed)_
- **Did it emit `tick done` on completion?** _(yes / no / inconsistent)_
- **Did it emit `tick break` when stuck?** _(yes / no / never got stuck)_
- **What did the integration prompt need to say to make compliance reliable?** _(describe what worked and what was ignored)_
- **What enforcement, if any, was needed beyond prompting?** _(file watcher, pre-commit hook, periodic reminder, none)_

## Cross-cutting observations

- **Collisions observed:** _(any two-agent edits to the same file? if so, did `tick` catch them or did they hit git?)_
- **Wasted work:** _(did any agent burn iterations on a task another agent had already broken?)_
- **Friction points:** _(what slowed agents down? what felt unnatural?)_
- **Unexpected behavior:** _(anything `tick` did that surprised you, good or bad)_

## Recommendation

_(graduate to Phase 2 / iterate on substrate / abandon — with one-line reason)_

## Auto-analyzed (tick analyze)

- **Run window:** `2026-05-06T16:17:18.481Z` → `2026-05-06T16:20:27.912Z`
- **Total events:** 10 (created: 3, claimed: 5, released: 2)

### Per-agent

#### codex

- **Claimed before editing:** yes
- **Declared paths matched actual edits:** no work commits attributed
- **Used `tick scope` when expanding mid-task:** never observed
- **Used `tick done` on completion:** no
- **Used `tick break` when stuck:** never invoked
- **Other coordination events:** 2 release(s) (0 as handoff), 0 comment(s)
- **Claim outcomes:** 0 won, 2 lost (of 2 attempted)

#### dispatcher

- **Claimed before editing:** yes
- **Declared paths matched actual edits:** no work commits attributed
- **Used `tick scope` when expanding mid-task:** never observed
- **Used `tick done` on completion:** no
- **Used `tick break` when stuck:** never invoked
- **Other coordination events:** 0 release(s) (0 as handoff), 0 comment(s)
- **Claim outcomes:** 0 won, 0 lost (of 0 attempted)

#### gemini

- **Claimed before editing:** **no — 3 unclaimed work commit(s)**
- **Declared paths matched actual edits:** no work commits attributed
- **Used `tick scope` when expanding mid-task:** never observed
- **Used `tick done` on completion:** no
- **Used `tick break` when stuck:** never invoked
- **Other coordination events:** 0 release(s) (0 as handoff), 0 comment(s)
- **Claim outcomes:** 3 won, 0 lost (of 3 attempted)
- **Unclaimed work commits:**
  - `a5e6cd72` edited `experiments/coordination-layer/BACKLOG.md`, `experiments/coordination-layer/CLAUDE.md`, `experiments/coordination-layer/CODEX.md`, `experiments/coordination-layer/GEMINI.md` with no active claim
  - `c140e6a0` edited `experiments/coordination-layer/CLAUDE.md`, `experiments/coordination-layer/CODEX.md`, `experiments/coordination-layer/GEMINI.md` with no active claim
  - `c28d581e` edited `experiments/coordination-layer/README.md` with no active claim

### Cross-cutting

- **File collisions:** none
- **Wasted work on broken tasks:** none
