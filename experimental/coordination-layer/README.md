# Trinity — Coordination Layer Spike

Spike for letting Claude Code, Codex, and Gemini work the same codebase concurrently without colliding. See [`PROJECT/2-WORKING/P1-TRINITY.md`](../../PROJECT/2-WORKING/P1-TRINITY.md) for the full design rationale and acceptance criteria.

## Status

- All 7 mechanical acceptance criteria pass — run `./validate.sh`.
- Real-agent hand-test results: see [`REAL-AGENT-OBSERVATIONS.md`](REAL-AGENT-OBSERVATIONS.md).
- Spike recap: see [`RECAP.md`](RECAP.md).

## What it is

`tick` is a tiny CLI backed by an event log under `.tick/events/`. Each event is a separate JSONL file (one event per file = disjoint files = zero git merge conflicts). `tick project` folds events into `.tick/STATE.md`. Critical events (claims, scope changes, handoffs, breaks, completion) auto-fetch+rebase+commit+push so peer agents see them. `task.commented` is local-only and rides the next normal commit.

## Quickstart (single repo)

```bash
# from any clone of the coordination branch:
./experiments/coordination-layer/bin/tick init
./experiments/coordination-layer/bin/tick log task.created TASK-001 \
  --agent dispatcher --priority 10 --paths "src/auth/**"
./experiments/coordination-layer/bin/tick project
cat .tick/STATE.md
```

## CLI verbs

| Verb | Pushes? | Purpose |
|---|---|---|
| `tick init` | no | `mkdir -p .tick/events` |
| `tick log <type> <task> ...` | no (writes locally) | Append a raw event |
| `tick project` | no | Rebuild `.tick/STATE.md` from events |
| `tick claim <task> --agent <id> --paths <globs>` | yes | Optimistic claim with deterministic tie-breaker. Refused if the agent already holds 2 active claims (the cap). |
| `tick next --agent <id>` | no (fetches first) | Return next compatible task. Reports the claim limit instead of a task if the agent is at the cap. |
| `tick scope <task> --agent <id> --paths <globs>` | yes | Replace claim's path scope |
| `tick release <task> --agent <id> [--to <agent>]` | yes | Release claim, optionally hand off |
| `tick break <task> --agent <id> --reason "..."` | yes | Mark task circuit-broken; excluded from `tick next` for everyone |
| `tick done <task> --agent <id> [--note "..."]` | yes | Mark complete |
| `tick reap <agent> [--by <id>]` | yes | Coordinator lever: release every active claim held by a presumed-crashed agent so peers can pick the work back up. Manual and logged — not auto-recovery. |
| `tick analyze [--format human\|md\|json] [--since <ref>] [--write <file>]` | no | Audit a multi-agent run: walks `.tick/events/` + `git log` and reports per-agent compliance (claimed before editing? declared paths matched? scope/done/break used?) plus cross-cutting collisions. Reusable across testing phases. |

`--paths` accepts comma-separated globs: `--paths "src/auth/**,tests/auth/**"`.

## Multi-agent setup: separate clones

The architecture requires all coordinating agents to work on the same branch (`.tick/` is branch-scoped, and `tick`'s auto-push targets the current branch). `git worktree` cannot have the same branch checked out twice, so we use **separate clones** instead — one per agent, all tracking `experiment/coordination-layer`.

```bash
REMOTE=https://github.com/Hypercart-Dev-Tools/AI-DDTK-Fix-Iterate-Loop.git
for agent in claude codex gemini; do
  git clone --branch experiment/coordination-layer "$REMOTE" "../trinity-$agent"
  git -C "../trinity-$agent" config user.name  "$agent"
  git -C "../trinity-$agent" config user.email "$agent@trinity.local"
done
```

Each clone has its own `.git/`, so plain `git config user.name` is correctly scoped (no `--worktree` needed). The git author name is what `tick analyze` uses to attribute work commits to agents — set it before agents start.

**Why not worktrees?** A `git worktree` shares its branch space with the parent repo: same-branch checkouts are refused, and per-worktree git identity requires `extensions.worktreeConfig` plus `git config --worktree` (default `git config` writes to the shared repo config and silently overwrites). More importantly, if you put each agent on a child branch, `tick`'s auto-push lands on that child branch and peer agents on different child branches never see the events. Phase 2 may add a shared `.tick/`-only ref (or out-of-band sync daemon) to make worktrees viable; until then, clones.

## Agent integration prompt snippet

Paste this verbatim into each agent's system prompt or project instructions:

```
You are coordinating with other AI agents on this codebase via the `tick` CLI
at experiments/coordination-layer/bin/tick. Your agent ID is <YOUR-ID>.

ONE-TIME SETUP (run once at session start, in your worktree):
  git config user.name <YOUR-ID>
  git config user.email <YOUR-ID>@trinity.local
This is REQUIRED — `tick analyze` uses git author name to attribute each
work commit to an agent. If you skip this, your compliance can't be measured.

BEFORE EDITING ANY FILES:
  1. Run `tick next --agent <YOUR-ID>` to see what task is yours.
  2. Run `tick claim <TASK-ID> --agent <YOUR-ID> --paths "<glob1>,<glob2>"`
     declaring every file glob you intend to touch.
  3. If the claim returns "lost: ...", do not start work. Run `tick next` again.

CLAIM LIMIT: You may hold AT MOST 2 active claims at once. Finish (`tick done`)
or release (`tick release`) a task before claiming a third. `tick next` and
`tick claim` will refuse to give you a third — that is expected, not an error.

DEPENDENCIES: Use only the Node standard library — `node:http`, `node:test`,
`node:assert`. Do NOT install dependencies, do NOT edit `package.json`, do NOT
create a lockfile. `package.json` is shared and outside every task's scope;
touching it collides with the other agent and fails the run.

WHILE WORKING:
  - If you discover you need to edit files outside your declared paths, run
    `tick scope <TASK-ID> --agent <YOUR-ID> --paths "<expanded globs>"` BEFORE
    editing. This warns peer agents off the new scope.
  - If you get stuck or detect a poisoned task (failing tests after multiple
    attempts), run `tick break <TASK-ID> --agent <YOUR-ID> --reason "..."` so
    no other agent burns budget on it.

WHEN DONE:
  - Run `tick done <TASK-ID> --agent <YOUR-ID>` (after your final commit).
  - To pass the task to another agent instead, run
    `tick release <TASK-ID> --agent <YOUR-ID> --to <other-agent-id>`.

After the session, `tick analyze` will be run against the event log + git
history to measure: did you claim before editing? did your declared paths
match your actual edits? did you use scope/done/break correctly? Behave
accordingly.

Critical: `tick claim`, `tick scope`, `tick release`, `tick break`, `tick done`
auto-commit and push. If push fails twice, abort and pick a different task.
```

## Multi-agent flow

Seed the event log with non-overlapping tasks before starting agents:

```bash
tick log task.created TASK-A --agent dispatcher --priority 10 --paths "src/auth/**"
tick log task.created TASK-B --agent dispatcher --priority 10 --paths "src/billing/**"
tick log task.created TASK-C --agent dispatcher --priority 5  --paths "tests/**"
git add .tick && git commit -m "seed coordination tasks" && git push
```

Then start each agent in its worktree with the integration prompt loaded.

## Constraints

- **Same branch only.** All coordinating agents work on the same branch. Cross-branch is Phase 2.
- **Honest declaration required.** `tick` does not enforce that an agent's edits stay within declared paths. A pre-commit hook is one Phase 2 enforcement option.
- **Push retry once.** On rejection: fetch + rebase + retry. If second push also fails, the verb aborts with a clear error.

## Tests

```bash
./validate.sh        # run all acceptance tests
./test/handoff.sh    # run one
```

Each test sets up a bare remote + two clones in `$TMPDIR` and exercises the protocol end-to-end. Cleanup is automatic.

## Auditing a real-agent run

After any multi-agent session — Day 5 hand-test, future Phase 2 runs, anything — run:

```bash
./bin/tick analyze                                          # human-readable to stdout
./bin/tick analyze --format json                            # for downstream tooling
./bin/tick analyze --write REAL-AGENT-OBSERVATIONS.md       # append/replace the auto-analyzed section in-place
```

The analyzer walks `.tick/events/` and `git log`, attributes each work commit to whichever agent's claim window contains it (using git author name as the agent identifier — set `git config user.name` per worktree to your agent ID), and reports per-agent:

- **Claimed before editing?** Counts work commits not covered by any active claim by that agent.
- **Declared paths matched actual edits?** Per-commit comparison of touched files against the active claim's globs (claim paths ∪ scope_changed paths).
- **Used `tick scope` / `tick done` / `tick break`?** Direct event counts.
- **Drift examples + unclaimed work examples** for forensic inspection.

Cross-cutting: file collisions (same file edited by 2+ agents) and wasted work (commits on circuit-broken tasks).

Subjective questions in REAL-AGENT-OBSERVATIONS.md (what the prompt needed, what felt like friction) still require each agent to self-report.
