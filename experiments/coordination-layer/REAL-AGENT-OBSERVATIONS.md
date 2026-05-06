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
