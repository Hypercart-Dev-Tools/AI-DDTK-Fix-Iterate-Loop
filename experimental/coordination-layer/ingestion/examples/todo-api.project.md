# Project: Trinity sandbox — Todo REST API

> **Illustration only.** This is the Run 2 synthetic app expressed in the
> ingestion format, to show what a filled-in spec looks like. Run 2 itself
> seeds `.tick/events/` by hand — this file is NOT its input.

**Goal:** A throwaway in-memory Todo REST API, used as the vehicle for the
Trinity Run 2 sustained-parallelism test. Two agents build two non-overlapping
halves (HTTP layer, store layer) concurrently.
**Branch:** experiment/coordination-layer
**Path-scoping strategy:** half-wide (each task declares its whole half)
**Max active claims per agent:** 2

## Constraints

- Node standard library only — `node:http`, `node:test`, `node:assert`. No dependencies.
- Do not edit or create `package.json` or lockfiles — shared, outside every task's scope.

## Interface contracts

The HTTP half codes against the store contract in `sandbox-app/STORE-CONTRACT.md`;
it does not read the store half's code. See that file for `createStore()` and the `todo` shape.

## Sub-tasks

### TASK-A1 — HTTP server bootstrap

- **Declared scope:** `src/http/**`, `test/http/**`
- **Files:** `src/http/server.js`, `test/http/server.test.js`
- **Priority:** 10
- **Depends on (contract only):** none
- **Description:** Minimal HTTP server — boot + `GET /health` only. Responds `200 {"status":"ok"}`. No routing or handlers here.
- **Acceptance:** `node --test test/http/server.test.js` exits 0; health check returns ok.

### TASK-A2 — Router

- **Declared scope:** `src/http/**`, `test/http/**`
- **Files:** `src/http/router.js`, `test/http/router.test.js`
- **Priority:** 8
- **Depends on (contract only):** none
- **Description:** Dispatch by `method + path`, support `:id` params, 404 for unmatched routes.
- **Acceptance:** `node --test test/http/router.test.js` exits 0; matches `GET /todos`, `GET /todos/:id`, 404 otherwise.

### TASK-A3 — Request handlers

- **Declared scope:** `src/http/**`, `test/http/**`
- **Files:** `src/http/handlers.js`, `test/http/handlers.test.js`
- **Priority:** 5
- **Depends on (contract only):** store contract (STORE-CONTRACT.md)
- **Description:** Handlers for `GET/POST/PUT/DELETE /todos` calling the store interface; shape JSON responses + status codes.
- **Acceptance:** `node --test test/http/handlers.test.js` exits 0 with a stub store; status codes 200/201/404/400 correct.

### TASK-B1 — In-memory store

- **Declared scope:** `src/store/**`, `test/store/**`
- **Files:** `src/store/store.js`, `test/store/store.test.js`
- **Priority:** 10
- **Depends on (contract only):** validate contract (TASK-B2)
- **Description:** In-memory store implementing the contract: `create/get/list/update/remove`. Unique string IDs.
- **Acceptance:** `node --test test/store/store.test.js` exits 0; CRUD round-trips; `get` of missing id returns null.

### TASK-B2 — Write validation

- **Declared scope:** `src/store/**`, `test/store/**`
- **Files:** `src/store/validate.js`, `test/store/validate.test.js`
- **Priority:** 8
- **Depends on (contract only):** none
- **Description:** Validate writes — `title` required non-empty string, `done` optional boolean.
- **Acceptance:** `node --test test/store/validate.test.js` exits 0; rejects empty/missing title, accepts valid input.

### TASK-B3 — Query helpers

- **Declared scope:** `src/store/**`, `test/store/**`
- **Files:** `src/store/query.js`, `test/store/query.test.js`
- **Priority:** 5
- **Depends on (contract only):** none
- **Description:** Query helpers for `store.list` — filter by `done`, sort by `createdAt` asc/desc.
- **Acceptance:** `node --test test/store/query.test.js` exits 0; filter + sort behave per contract.
