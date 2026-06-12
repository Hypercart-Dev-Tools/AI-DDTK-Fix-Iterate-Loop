#!/usr/bin/env bash
# AC #6: tick project twice produces byte-identical STATE.md
source "$(dirname "$0")/_setup.sh" projection-idempotent

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-001 --agent dispatcher --priority 10 --paths "src/foo/**" >/dev/null
TICK_TS=2026-05-04T10:00:01.000Z tick_a log task.created TASK-002 --agent dispatcher --priority 5 --paths "src/bar/**" >/dev/null
TICK_TS=2026-05-04T10:00:02.000Z tick_a log task.claimed TASK-001 --agent alice --paths "src/foo/**" >/dev/null

tick_a project >/dev/null
cp "$A/.tick/STATE.md" "$WORK/state-1.md"
tick_a project >/dev/null
cp "$A/.tick/STATE.md" "$WORK/state-2.md"

if diff -q "$WORK/state-1.md" "$WORK/state-2.md" >/dev/null; then
  pass "STATE.md is byte-identical across two consecutive projections"
else
  diff "$WORK/state-1.md" "$WORK/state-2.md" || true
  fail "STATE.md differs between projections"
fi

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
