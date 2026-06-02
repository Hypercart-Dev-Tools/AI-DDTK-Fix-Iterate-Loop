#!/usr/bin/env bash
# AC #2: agent-A claims TASK-007 with paths src/auth/**.
# TASK-008 (higher priority) also touches src/auth/**.
# agent-B's `tick next` must NOT return TASK-008; should return next compatible.
source "$(dirname "$0")/_setup.sh" path-overlap

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-007 --agent dispatcher --priority 5  --paths "src/auth/**" >/dev/null
TICK_TS=2026-05-04T10:00:01.000Z tick_a log task.created TASK-008 --agent dispatcher --priority 99 --paths "src/auth/login.js" >/dev/null
TICK_TS=2026-05-04T10:00:02.000Z tick_a log task.created TASK-009 --agent dispatcher --priority 1  --paths "src/billing/**" >/dev/null
TICK_TS=2026-05-04T10:00:05.000Z tick_a claim TASK-007 --agent alice --paths "src/auth/**" >/dev/null

# tick_b shares TICK_REPO_ROOT with tick_a — no git pull needed.
NEXT_FOR_B=$(tick_b next --agent bob)
echo "  bob's next: $NEXT_FOR_B"

if echo "$NEXT_FOR_B" | grep -q "TASK-008"; then
  fail "bob got TASK-008 even though it overlaps src/auth/** claimed by alice"
fi
if echo "$NEXT_FOR_B" | grep -q "TASK-009"; then
  pass "bob routed to TASK-009 (non-overlapping) instead of higher-priority TASK-008"
else
  fail "bob should have received TASK-009 but got: $NEXT_FOR_B"
fi

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
