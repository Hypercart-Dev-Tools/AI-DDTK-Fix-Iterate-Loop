# Project: <project name>

> Human-authored. Fill this in, review it, then run `ingest.js` to convert it
> into `.tick/events/` task events. Everything here is for humans first —
> the machine task list is generated *from* this, not the other way around.

**Goal:** <one paragraph — what we're building and why it matters>
**Branch:** <coordination branch, e.g. experiment/coordination-layer>
**Path-scoping strategy:** <half-wide | per-file | other — how task scopes are declared>
**Max active claims per agent:** <int>

## Constraints

- <e.g. standard library only, no dependencies>
- <e.g. do not edit shared files: package.json, lockfiles>
- <add as many as the project needs>

## Interface contracts (if halves integrate)

<Describe any contract between parts so tasks don't depend on each other's
*code* — only documented interfaces. Link to a contract file if one exists.
Delete this section if not applicable.>

## Sub-tasks

> One `### TASK-<ID>` block per task. IDs must be unique. Keep each task small
> enough to be a single claim.

### TASK-<ID> — <short title>

- **Declared scope:** <path globs the claim covers, e.g. `src/http/**`>
- **Files:** <the actual files this task touches>
- **Priority:** <integer — higher is sooner>
- **Depends on (contract only):** <task IDs whose *contract* this needs, or `none`. Must NOT depend on another task's code — only its documented interface.>
- **Description:** <what to build>
- **Acceptance:** <concrete, testable — how do we know it's done>

### TASK-<ID> — <short title>

- **Declared scope:** ...
- **Files:** ...
- **Priority:** ...
- **Depends on (contract only):** ...
- **Description:** ...
- **Acceptance:** ...
