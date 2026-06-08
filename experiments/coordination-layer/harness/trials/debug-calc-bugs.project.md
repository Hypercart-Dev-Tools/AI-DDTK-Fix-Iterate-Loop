# Project: Calc library bug-fix (debug)

**Goal:** A tiny calc library ships two seeded bugs (add subtracts, mul adds). Each bug is an independent, path-isolated debug task with a failing test that must go green. Tests the coordination layer on a debug/fix-iterate workload rather than greenfield build.
**Branch:** experiment/coordination-layer
**Kind:** debug
**Agents:** gemini, codex
**Fixture:** fixtures/calc-bugs
**Path-scoping strategy:** per-file
**Max active claims per agent:** 2
**Verify:** node --test test/*.test.js

## Constraints

- Fix only the implementation under `src/`; do not weaken the tests.
- Each task owns exactly one source file — no cross-file edits.

## Sub-tasks

### TASK-ADD — fix add()

- **Declared scope:** `src/add.js, test/add.test.js`
- **Files:** `src/add.js`
- **Priority:** 10
- **Depends on (contract only):** none
- **Description:** `src/add.js` subtracts instead of adding. Make `test/add.test.js` pass.
- **Acceptance:** `node --test test/add.test.js` exits 0.
- **Verify:** node --test test/add.test.js
- **Mock-solution:** src/add.js<=.solutions/add.js

### TASK-MUL — fix mul()

- **Declared scope:** `src/mul.js, test/mul.test.js`
- **Files:** `src/mul.js`
- **Priority:** 8
- **Depends on (contract only):** none
- **Description:** `src/mul.js` adds instead of multiplying. Make `test/mul.test.js` pass.
- **Acceptance:** `node --test test/mul.test.js` exits 0.
- **Verify:** node --test test/mul.test.js
- **Mock-solution:** src/mul.js<=.solutions/mul.js
