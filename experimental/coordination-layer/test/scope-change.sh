#!/usr/bin/env bash
# AC #3: alice claims with src/auth/** then `tick scope` to add src/middleware/**.
# bob's `tick next` immediately stops returning tasks touching src/middleware/**.
source "$(dirname "$0")/_setup.sh" scope-change

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-007 --agent dispatcher --priority 5  --paths "src/auth/**" >/dev/null
TICK_TS=2026-05-04T10:00:01.000Z tick_a log task.created TASK-010 --agent dispatcher --priority 50 --paths "src/middleware/**" >/dev/null
TICK_TS=2026-05-04T10:00:02.000Z tick_a log task.created TASK-011 --agent dispatcher --priority 1  --paths "src/billing/**" >/dev/null
TICK_TS=2026-05-04T10:00:05.000Z tick_a claim TASK-007 --agent alice --paths "src/auth/**" >/dev/null

# tick_b shares TICK_REPO_ROOT with tick_a — no git pull needed.
NEXT1=$(tick_b next --agent bob)
echo "  before scope expansion, bob's next: $NEXT1"
if ! echo "$NEXT1" | grep -q "TASK-010"; then
  fail "bob should have seen TASK-010 (highest priority, no overlap yet)"
fi

# Alice expands scope to include middleware.
TICK_TS=2026-05-04T10:00:10.000Z tick_a scope TASK-007 --agent alice --paths "src/auth/**,src/middleware/**" >/dev/null

NEXT2=$(tick_b next --agent bob)
echo "  after scope expansion, bob's next: $NEXT2"
if echo "$NEXT2" | grep -q "TASK-010"; then
  fail "bob still got TASK-010 after alice expanded scope to src/middleware/**"
fi
if echo "$NEXT2" | grep -q "TASK-011"; then
  pass "bob now routed to TASK-011 after alice's scope expansion"
else
  fail "expected TASK-011, got: $NEXT2"
fi

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
