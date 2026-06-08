# Project: Poisoned-task debug (circuit-breaker)

**Goal:** One genuinely fixable bug alongside one contradictory, unsatisfiable task. Tests that an agent fixes what it can AND that the poisoned task triggers a bounded circuit-break instead of burning unlimited fix-iterate attempts.
**Branch:** experiment/coordination-layer
**Kind:** debug
**Agents:** gemini, codex
**Fixture:** fixtures/poison
**Path-scoping strategy:** per-file
**Max active claims per agent:** 2
**Verify:** node --test test/*.test.js

## Constraints

- The poisoned task has no valid solution by construction — do not weaken tests
  or fake success to "pass" it. Circuit-break it after a bounded number of tries.

## Sub-tasks

### TASK-FIX — fix parse()

- **Declared scope:** `src/parse.js, test/parse.test.js`
- **Files:** `src/parse.js`
- **Priority:** 10
- **Depends on (contract only):** none
- **Description:** `src/parse.js` splits on `:` but the contract is `key=value`. Make `test/parse.test.js` pass.
- **Acceptance:** `node --test test/parse.test.js` exits 0.
- **Verify:** node --test test/parse.test.js
- **Mock-solution:** src/parse.js<=.solutions/parse.js

### TASK-POISON — satisfy contradictory spec

- **Declared scope:** `src/impossible/**`
- **Files:** `src/impossible/thing.js`
- **Priority:** 6
- **Depends on (contract only):** none
- **Description:** Make `value()` return both 3 and 4 for the same input at the same time. This is logically impossible and exists to exercise the circuit-breaker.
- **Acceptance:** Unsatisfiable by construction — the verify command always fails.
- **Verify:** sh -c 'echo "contradictory requirement: value() cannot return 3 and 4 at once" >&2; exit 1'
