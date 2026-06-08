#!/usr/bin/env bash
# CONFIRMATION: Claude Code (or any operator) can execute AND monitor the real
# gemini/codex CLI commands through the harness.
#
# We point the gemini/codex drivers at stand-in binaries (GEMINI_CMD/CODEX_CMD)
# that honor the exact headless contract, then run a real trial with the REAL
# driver names `gemini` and `codex`. The driver builds and spawns the real
# command shapes (`gemini --yolo`, `codex exec --full-auto -`), pipes the prompt
# on stdin, runs both concurrently, and captures every transcript — exactly what
# it will do with the real binaries installed. Only the model is swapped out.
set -euo pipefail

HARNESS="$(cd "$(dirname "$0")/.." && pwd)"
FAKE="$HARNESS/test/fake-cli"
export GEMINI_CMD="$FAKE/gemini"
export CODEX_CMD="$FAKE/codex"

PASS=0; FAIL=0
ok()  { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
bad() { printf '  ✗ %s\n' "$1"; FAIL=$((FAIL+1)); }

echo "=== doctor sees gemini + codex (via *_CMD overrides) ==="
node "$HARNESS/bin/trial" doctor

echo; echo "=== running trial with REAL gemini/codex drivers (stand-in binaries) ==="
OUT=$(mktemp)
node "$HARNESS/bin/trial" run build-todo-api --agents gemini:gemini,codex:codex --auto --timeout 60000 | tee "$OUT"
RD="$HARNESS/$(grep -oE 'runs/[^ ]+' "$OUT" | head -1)"

echo; echo "=== assertions ==="
# The harness spawned the real command shapes and monitored them (run.jsonl is JSON).
grep -q '"cmd":"[^"]*gemini --yolo"' "$RD/run.jsonl"            && ok "spawned 'gemini --yolo'"            || bad "no gemini --yolo spawn"
grep -q '"cmd":"[^"]*codex exec --full-auto -"' "$RD/run.jsonl" && ok "spawned 'codex exec --full-auto -'" || bad "no codex exec spawn"
# Both processes were monitored to a clean exit.
grep -q '"type":"agent.exit","agent":"gemini","code":0' "$RD/run.jsonl" && ok "monitored gemini → exit 0" || bad "gemini did not exit cleanly"
grep -q '"type":"agent.exit","agent":"codex","code":0'  "$RD/run.jsonl" && ok "monitored codex → exit 0"  || bad "codex did not exit cleanly"
# The prompt was delivered on stdin (the stand-in echoes its byte count).
grep -q 'prompt [0-9]* bytes on stdin' "$RD/logs/gemini.log" && ok "prompt delivered to gemini on stdin" || bad "no stdin prompt to gemini"
# Work actually completed through the coordination protocol.
grep -q '"done": 6' "$RD/report/analyze.json" && ok "all 6 tasks completed via tick protocol" || bad "tasks not all done"
# Live transcripts exist for monitoring.
[ -s "$RD/logs/gemini.log" ] && [ -s "$RD/logs/codex.log" ] && ok "per-agent transcripts captured" || bad "missing transcripts"

echo; echo "--- per-agent transcripts (the 'monitor' view) ---"
echo "# gemini.log";  sed 's/^/  /' "$RD/logs/gemini.log"
echo "# codex.log";   sed 's/^/  /' "$RD/logs/codex.log"

printf '\n--- confirm-cli-orchestration: %d passed, %d failed ---\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
