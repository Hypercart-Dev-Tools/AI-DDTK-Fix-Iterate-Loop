#!/usr/bin/env bash
# AC #5: alice breaks TASK-007. No agent's `tick next` returns it.
# STATE.md shows it as broken with reason and breaking agent.
source "$(dirname "$0")/_setup.sh" circuit-break

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-007 --agent dispatcher --priority 100 --paths "src/auth/**" >/dev/null
TICK_TS=2026-05-04T10:00:01.000Z tick_a log task.created TASK-008 --agent dispatcher --priority 1   --paths "src/billing/**" >/dev/null
git -C "$A" add .tick && git -C "$A" commit -q -m "seed" && git -C "$A" push -q origin main
git -C "$B" pull -q --rebase origin main

# Pre-break: bob would pick TASK-007 (priority 100).
PRE=$(tick_b next --agent bob)
if ! echo "$PRE" | grep -q "TASK-007"; then
  fail "expected TASK-007 pre-break, got: $PRE"
fi

TICK_TS=2026-05-04T10:00:05.000Z tick_a break TASK-007 --agent alice --reason "infinite loop in auth tests" >/dev/null
git -C "$B" pull -q --rebase origin main

POST=$(tick_b next --agent bob)
echo "  post-break, bob's next: $POST"
if echo "$POST" | grep -q "TASK-007"; then
  fail "bob still got TASK-007 after circuit break"
fi
if echo "$POST" | grep -q "TASK-008"; then
  pass "bob skipped broken TASK-007 and got TASK-008"
else
  fail "expected TASK-008, got: $POST"
fi

# Verify STATE.md shows it under Circuit-Broken with reason and agent.
if grep -E "^- TASK-007 by alice — reason: \"infinite loop in auth tests\"" "$B/.tick/STATE.md" >/dev/null; then
  pass "STATE.md shows TASK-007 broken by alice with reason"
else
  echo "--- STATE.md ---"; cat "$B/.tick/STATE.md"
  fail "STATE.md missing expected circuit-break entry"
fi

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
