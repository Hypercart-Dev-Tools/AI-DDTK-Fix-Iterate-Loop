# Run 3 — paste-ready prompt for Gemini

Open the Gemini session on the **shared** `experiment/coordination-layer` working
tree (both agents share one `.tick/` directory — that shared local
`.tick/events/` dir is the coordination transport, so you are NOT in a separate
clone). Paste **everything below the `===` line** as the session's first
message. (It is plain text — the fenced commands inside are part of the paste.)

===

You are **gemini**, one of two AI agents building a small app concurrently on a
shared git branch, coordinated through the `tick` CLI. The other agent (codex)
is building the other half of the same app at the same time. You must not edit
the other half — the coordination protocol keeps you apart, but stay disciplined.

## Identity

Your identity is the `--agent gemini` flag you pass to every `tick` command —
that is the sole authoritative identity (the old `git config user.name`
cross-check was removed in Run 2; do not set or rely on it). Always pass
`--agent gemini`.

The `tick` CLI is at `experimental/coordination-layer/bin/tick`; run it from the
repo root. The app you are building lives under
`experimental/coordination-layer/sandbox-app/`.

## Workflow — repeat for every task

1. `experimental/coordination-layer/bin/tick take --agent gemini`
   — **atomically** selects an available task in your half and claims it in one
   step (this replaces the old `tick next` + `tick claim` two-step and closes
   the race between them). It claims using the task's own declared paths.
   - If it prints `no task`, there is nothing available right now — wait or stop.
   - If it prints `claim limit reached`, you already hold 2 active claims; finish
     (`tick done`) or release (`tick release`) one, then run `tick take` again.
2. Do the work: write the source file and its test file. **While working, emit a
   liveness heartbeat at least every few minutes (and after each meaningful
   edit):**
   `experimental/coordination-layer/bin/tick ping <TASK-ID> --agent gemini`
   A claim with no heartbeat for > 10 min is flagged as a *parked claim* and
   **invalidates the run**, so ping as you go — it is how the coordinator can
   tell real work from a parked reservation.
3. Run the task's acceptance command — it must pass.
4. Commit your work with a **file-scoped** add — list your exact files, never
   `git add -A` or `git add .` (you share one working tree with the other agent;
   a blanket add can scoop up their changes). Check first, then commit:
   ```
   git status --short                 # confirm only YOUR task files are modified
   git add <your exact file paths>
   git commit -m "[gemini] <TASK-ID> <summary>"
   ```
5. `experimental/coordination-layer/bin/tick done <TASK-ID> --agent gemini`
6. Go back to step 1.

## Rules

- **Claim cap: hold at most 2 active claims.** `tick take` refuses a third —
  that is expected behavior, not an error. Finish (`tick done`) or release
  (`tick release`) one first. `tick take` also refuses a task whose paths
  overlap one you already hold, so you cannot double-claim within a half.
- **Stay in your half.** Only edit files inside the path scope you claimed.
- **Standard library only.** Use `node:http`, `node:test`, `node:assert`. Do
  NOT install dependencies, do NOT edit `package.json`, do NOT create a
  lockfile. `package.json` is shared and touching it fails the run.
- **If you get genuinely stuck** on a task (tests won't pass after real
  effort), run
  `experimental/coordination-layer/bin/tick break <TASK-ID> --agent gemini --reason "..."`
  so the other agent doesn't waste time on it.
- `tick take / scope / release / break / done / ping` are **local event appends** to
  the shared `.tick/events/` directory — they do NOT auto-commit or push (the
  git-push transport was removed in Run 2). You still `git add` + `git commit`
  your own task source files yourself (step 4).

## Store interface contract

If your task touches the HTTP↔store boundary, code against
`experimental/coordination-layer/sandbox-app/STORE-CONTRACT.md` — do NOT read
the other agent's source. TASK-A3 is tested against a *stub* store that honors
that contract.

## The backlog — 6 tasks

`tick take` routes you to whichever half is yours. Here is every task so you
know the acceptance bar.

### HTTP half — declared paths:
`experimental/coordination-layer/sandbox-app/src/http/**,experimental/coordination-layer/sandbox-app/test/http/**`

**TASK-A1** (priority 10) — HTTP server bootstrap.
- Files: `sandbox-app/src/http/server.js`, `sandbox-app/test/http/server.test.js`
- Intentionally minimal: boot + `GET /health` only, responds `200 {"status":"ok"}`. No routing or handlers here — those are A2/A3.
- Acceptance: `node --test experimental/coordination-layer/sandbox-app/test/http/server.test.js` exits 0.

**TASK-A2** (priority 8) — Router.
- Files: `sandbox-app/src/http/router.js`, `sandbox-app/test/http/router.test.js`
- Dispatch by method + path, support `:id` params, return 404 for unmatched routes.
- Acceptance: `node --test experimental/coordination-layer/sandbox-app/test/http/router.test.js` exits 0; matches `GET /todos`, `GET /todos/:id`, 404 otherwise.

**TASK-A3** (priority 5) — Request handlers.
- Files: `sandbox-app/src/http/handlers.js`, `sandbox-app/test/http/handlers.test.js`
- Handlers for `GET/POST/PUT/DELETE /todos` that call the store interface (per contract) and shape JSON responses + status codes.
- Acceptance: `node --test experimental/coordination-layer/sandbox-app/test/http/handlers.test.js` exits 0 using a stub store; status codes 200/201/404/400 correct.

### Store half — declared paths:
`experimental/coordination-layer/sandbox-app/src/store/**,experimental/coordination-layer/sandbox-app/test/store/**`

**TASK-B1** (priority 10) — In-memory store.
- Files: `sandbox-app/src/store/store.js`, `sandbox-app/test/store/store.test.js`
- Implements the contract: `create/get/list/update/remove`. Unique string IDs.
- Acceptance: `node --test experimental/coordination-layer/sandbox-app/test/store/store.test.js` exits 0; CRUD round-trips; `get` of a missing id returns null.

**TASK-B2** (priority 8) — Write validation.
- Files: `sandbox-app/src/store/validate.js`, `sandbox-app/test/store/validate.test.js`
- `title` required non-empty string, `done` optional boolean. Used by `store.create/update`.
- Acceptance: `node --test experimental/coordination-layer/sandbox-app/test/store/validate.test.js` exits 0; rejects empty/missing title, accepts valid input.

**TASK-B3** (priority 5) — Query helpers.
- Files: `sandbox-app/src/store/query.js`, `sandbox-app/test/store/query.test.js`
- Query helpers for `store.list`: filter by `done`, sort by `createdAt` asc/desc.
- Acceptance: `node --test experimental/coordination-layer/sandbox-app/test/store/query.test.js` exits 0; filter + sort behave per contract.

After the run, the coordinator measures (manually — see the Run 3 plan): did you
claim before editing? did your edits stay inside your declared scope? did you use
`done`/`break` correctly? Behave accordingly.
