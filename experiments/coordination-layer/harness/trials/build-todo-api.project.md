# Project: Todo REST API (build)

**Goal:** Build a stdlib-only Node.js Todo REST API split into an HTTP layer and a store layer so two agents can build the halves concurrently without colliding. This is the Run 2 fixture shape, re-expressed as a harness-driven trial.
**Branch:** experiment/coordination-layer
**Kind:** build
**Agents:** gemini, codex
**Path-scoping strategy:** half-wide (HTTP half vs store half)
**Max active claims per agent:** 2

## Constraints

- Standard library only — no npm dependencies.
- Do not edit shared files: `package.json`, lockfiles.
- HTTP and store halves communicate only through the documented store contract.

## Interface contracts (if halves integrate)

The HTTP layer calls the store through a documented interface (`create`, `get`,
`list`, `update`, `remove`). Tasks depend only on that contract, never on each
other's code.

## Sub-tasks

### TASK-A1 — HTTP server bootstrap

- **Declared scope:** `src/http/**`
- **Files:** `src/http/server.js`
- **Priority:** 10
- **Depends on (contract only):** none
- **Description:** Create an http.createServer bootstrap that wires a router and listens on a configurable port.
- **Acceptance:** Server starts and responds 404 on an unknown route.

### TASK-A2 — HTTP router

- **Declared scope:** `src/http/**`
- **Files:** `src/http/router.js`
- **Priority:** 8
- **Depends on (contract only):** none
- **Description:** Method+path router that dispatches to handlers.
- **Acceptance:** Routes GET/POST/PUT/DELETE to the right handler; unknown → 404.

### TASK-A3 — HTTP handlers

- **Declared scope:** `src/http/**`
- **Files:** `src/http/handlers.js`
- **Priority:** 5
- **Depends on (contract only):** TASK-B1
- **Description:** CRUD handlers that translate HTTP to store calls and JSON responses.
- **Acceptance:** Each handler returns the correct status code and JSON body.

### TASK-B1 — Store core

- **Declared scope:** `src/store/**`
- **Files:** `src/store/store.js`
- **Priority:** 10
- **Depends on (contract only):** none
- **Description:** In-memory store implementing the documented create/get/list/update/remove contract.
- **Acceptance:** All five operations behave per contract.

### TASK-B2 — Store validation

- **Declared scope:** `src/store/**`
- **Files:** `src/store/validate.js`
- **Priority:** 8
- **Depends on (contract only):** none
- **Description:** Input validation for todo records (title required, done is boolean).
- **Acceptance:** Invalid records are rejected with a clear error.

### TASK-B3 — Store query helpers

- **Declared scope:** `src/store/**`
- **Files:** `src/store/query.js`
- **Priority:** 5
- **Depends on (contract only):** TASK-B1
- **Description:** Filtering/sorting helpers over the store (by done flag, by created time).
- **Acceptance:** Query helpers return correctly filtered/sorted lists.
