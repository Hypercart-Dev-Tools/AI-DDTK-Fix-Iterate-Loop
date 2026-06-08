#!/usr/bin/env bash
# Smoke test: drive the entire battery with the deterministic MOCK driver, so
# the harness is validated end-to-end with no API keys or real CLIs. Exercises
# spec parse → preflight → seed → concurrent run → analyze → report for every
# trial spec, plus the debug red→green path and the circuit-breaker.
set -euo pipefail

HARNESS="$(cd "$(dirname "$0")/.." && pwd)"
TRIAL="node $HARNESS/bin/trial"
PASS=0; FAIL=0

note() { printf '\n=== %s ===\n' "$1"; }
ok()   { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  ✗ %s\n' "$1"; FAIL=$((FAIL+1)); }

note "validate every spec"
for spec in "$HARNESS"/trials/*.project.md; do
  if $TRIAL validate "$spec" >/dev/null; then ok "valid: $(basename "$spec")"; else bad "invalid: $(basename "$spec")"; fi
done

note "doctor"
$TRIAL doctor >/dev/null && ok "doctor ran"

# Helper: run a spec with both agents forced onto the mock driver, auto past the
# preflight gate, and echo the resulting run dir.
run_mock() {
  local spec="$1" out
  out=$(mktemp)
  $TRIAL run "$spec" --agents gemini:mock,codex:mock --auto --timeout 60000 >"$out" 2>&1 || true
  echo "$HARNESS/$(grep -oE 'runs/[^ ]+' "$out" | head -1)"
}

note "build trial: build-todo-api (mock)"
RD=$(run_mock build-todo-api)
if grep -q '"done": 6' "$RD/report/analyze.json"; then ok "all 6 build tasks completed"; else bad "todo-api did not complete 6 tasks"; fi

note "build trial: build-url-shortener (mock)"
RD=$(run_mock build-url-shortener)
if grep -q '"done": 4' "$RD/report/analyze.json"; then ok "all 4 build tasks completed"; else bad "url-shortener did not complete 4 tasks"; fi

note "debug trial: calc-bugs (mock, red→green)"
RD=$(run_mock debug-calc-bugs)
if grep -q '"done": 2' "$RD/report/analyze.json"; then ok "both bugs fixed (tick done x2)"; else bad "calc-bugs not both done"; fi
if grep -q '✅ pass' "$RD/report/SUMMARY.md"; then ok "project verify passed (tests green)"; else bad "calc-bugs project verify did not pass"; fi

note "debug trial: poisoned-task (circuit-breaker)"
RD=$(run_mock debug-poisoned-task)
if grep -q '"circuit_break": 1' "$RD/report/analyze.json"; then ok "poisoned task circuit-broke (bounded, not infinite)"; else bad "poison task did not circuit-break"; fi
if grep -q '"done": 1' "$RD/report/analyze.json"; then ok "the fixable task still completed"; else bad "fixable task not completed"; fi

printf '\n--- smoke: %d passed, %d failed ---\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
