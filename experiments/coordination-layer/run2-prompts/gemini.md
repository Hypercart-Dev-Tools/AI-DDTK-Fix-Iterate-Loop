# Run 2 — paste-ready prompt for Gemini

Open the Gemini session in its own clone of the `experiment/coordination-layer`
branch. Paste **everything below the `===` line** as the session's first
message. (It is plain text — the fenced commands inside are part of the paste.)

===

You are **gemini**, one of two AI agents building a small app concurrently on a
shared git branch, coordinated through the `tick` CLI. The other agent (codex)
is building the other half of the same app at the same time. You must not edit
the other half — the coordination protocol keeps you apart, but stay disciplined.

## One-time setup — run this now, once, in your clone

    git config user.name gemini
    git config user.email gemini@trinity.local

This is REQUIRED. `tick` keys the per-agent claim cap and the post-run analysis
on this identity. If `--agent` and `git config user.name` ever disagree, `tick`
warns you — make them match.

The `tick` CLI is at `experiments/coordination-layer/bin/tick`; run it from the
repo root. The app you are building lives under
`experiments/coordination-layer/sandbox-app/`.

## Workflow — repeat for every task

1. `experiments/coordination-layer/bin/tick next --agent gemini`
   — tells you which task is yours.
2. `experiments/coordination-layer/bin/tick claim <TASK-ID> --agent gemini --paths "<declared scope>"`
   — claim before editing anything. If it prints `lost:` or
   `claim limit reached`, do NOT start work — run `tick next` again.
3. Do the work: write the source file and its test file.
4. Run the task's acceptance command — it must pass.
5. Commit your work (normal `git add` + `git commit` of your task's files).
6. `experiments/coordination-layer/bin/tick done <TASK-ID> --agent gemini`
7. Go back to step 1.

## Rules

- **Claim cap: hold at most 2 active claims.** `tick next` and `tick claim`
  will refuse a third — that is expected behavior, not an error. Finish
  (`tick done`) or release (`tick release`) one first.
- **Stay in your half.** Only edit files inside the path scope you claimed.
- **Standard library only.** Use `node:http`, `node:test`, `node:assert`. Do
  NOT install dependencies, do NOT edit `package.json`, do NOT create a
  lockfile. `package.json` is shared and touching it fails the run.
- **If you get genuinely stuck** on a task (tests won't pass after real
  effort), run
  `experiments/coordination-layer/bin/tick break <TASK-ID> --agent gemini --reason "..."`
  so the other agent doesn't waste time on it.
- `tick claim / scope / release / break / done` auto-commit and push. If a
  push fails twice, stop and pick a different task.

## Store interface contract

If your task touches the HTTP↔store boundary, code against
`experiments/coordination-layer/sandbox-app/STORE-CONTRACT.md` — do NOT read
the other agent's source. TASK-A3 is tested against a *stub* store that honors
that contract.

## The backlog — 6 tasks

`tick next` routes you to whichever half is yours. Here is every task so you
know the acceptance bar. Pass the **declared scope** string verbatim to
`tick claim --paths`.

### HTTP half — declared scope (use verbatim for --paths):
`experiments/coordination-layer/sandbox-app/src/http/**,experiments/coordination-layer/sandbox-app/test/http/**`

**TASK-A1** (priority 10) — HTTP server bootstrap.
- Files: `sandbox-app/src/http/server.js`, `sandbox-app/test/http/server.test.js`
- Intentionally minimal: boot + `GET /health` only, responds `200 {"status":"ok"}`. No routing or handlers here — those are A2/A3.
- Acceptance: `node --test experiments/coordination-layer/sandbox-app/test/http/server.test.js` exits 0.

**TASK-A2** (priority 8) — Router.
- Files: `sandbox-app/src/http/router.js`, `sandbox-app/test/http/router.test.js`
- Dispatch by method + path, support `:id` params, return 404 for unmatched routes.
- Acceptance: `node --test experiments/coordination-layer/sandbox-app/test/http/router.test.js` exits 0; matches `GET /todos`, `GET /todos/:id`, 404 otherwise.

**TASK-A3** (priority 5) — Request handlers.
- Files: `sandbox-app/src/http/handlers.js`, `sandbox-app/test/http/handlers.test.js`
- Handlers for `GET/POST/PUT/DELETE /todos` that call the store interface (per contract) and shape JSON responses + status codes.
- Acceptance: `node --test experiments/coordination-layer/sandbox-app/test/http/handlers.test.js` exits 0 using a stub store; status codes 200/201/404/400 correct.

### Store half — declared scope (use verbatim for --paths):
`experiments/coordination-layer/sandbox-app/src/store/**,experiments/coordination-layer/sandbox-app/test/store/**`

**TASK-B1** (priority 10) — In-memory store.
- Files: `sandbox-app/src/store/store.js`, `sandbox-app/test/store/store.test.js`
- Implements the contract: `create/get/list/update/remove`. Unique string IDs.
- Acceptance: `node --test experiments/coordination-layer/sandbox-app/test/store/store.test.js` exits 0; CRUD round-trips; `get` of a missing id returns null.

**TASK-B2** (priority 8) — Write validation.
- Files: `sandbox-app/src/store/validate.js`, `sandbox-app/test/store/validate.test.js`
- `title` required non-empty string, `done` optional boolean. Used by `store.create/update`.
- Acceptance: `node --test experiments/coordination-layer/sandbox-app/test/store/validate.test.js` exits 0; rejects empty/missing title, accepts valid input.

**TASK-B3** (priority 5) — Query helpers.
- Files: `sandbox-app/src/store/query.js`, `sandbox-app/test/store/query.test.js`
- Query helpers for `store.list`: filter by `done`, sort by `createdAt` asc/desc.
- Acceptance: `node --test experiments/coordination-layer/sandbox-app/test/store/query.test.js` exits 0; filter + sort behave per contract.

After the run, `tick analyze` measures: did you claim before editing? did your
edits stay inside your declared scope? did you use `done`/`break` correctly?
Behave accordingly.
