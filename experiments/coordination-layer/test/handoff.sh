#!/usr/bin/env bash
# AC #4: alice releases TASK-007 with --to bob. Bob's `tick next` returns
# TASK-007 even when other tasks have higher base priority.
source "$(dirname "$0")/_setup.sh" handoff

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-007 --agent dispatcher --priority 1   --paths "src/auth/**" >/dev/null
TICK_TS=2026-05-04T10:00:01.000Z tick_a log task.created TASK-099 --agent dispatcher --priority 100 --paths "src/billing/**" >/dev/null
# Without handoff, bob would pick TASK-099 (priority 100).
# tick_b shares TICK_REPO_ROOT with tick_a — no git pull needed.
PRE=$(tick_b next --agent bob)
echo "  pre-handoff, bob's next: $PRE"
if ! echo "$PRE" | grep -q "TASK-099"; then
  fail "expected TASK-099 pre-handoff, got: $PRE"
fi

# Alice claims and immediately hands off TASK-007 to bob.
TICK_TS=2026-05-04T10:00:05.000Z tick_a claim TASK-007 --agent alice --paths "src/auth/**" >/dev/null
TICK_TS=2026-05-04T10:00:06.000Z tick_a release TASK-007 --agent alice --to bob >/dev/null

POST=$(tick_b next --agent bob)
echo "  post-handoff, bob's next: $POST"
if echo "$POST" | grep -q "TASK-007" && echo "$POST" | grep -q "handoff"; then
  pass "bob's next returns TASK-007 with handoff marker, despite TASK-099 having higher priority"
else
  fail "expected handoff TASK-007 to win for bob, got: $POST"
fi

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
