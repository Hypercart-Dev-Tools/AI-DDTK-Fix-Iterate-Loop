#!/usr/bin/env bash
# AC #1: two agents race to claim the same task. The O_EXCL lock serialises
# them — first writer wins, second gets "lost". No timestamp tie-breaker
# exists in local transport; the lock is the sole arbiter.
source "$(dirname "$0")/_setup.sh" concurrent-claim

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-007 --agent dispatcher --priority 10 --paths "src/auth/**" >/dev/null

# Alice claims first.
tick_a claim TASK-007 --agent alice --paths "src/auth/**" >"$WORK/a.out"
if grep -q "^won:" "$WORK/a.out"; then
  pass "alice won the claim"
else
  fail "expected alice to win; got: $(cat "$WORK/a.out")"
fi

# Bob tries to claim the same task — must lose.
tick_b claim TASK-007 --agent bob --paths "src/auth/**" >"$WORK/b.out"
if grep -q "^lost:" "$WORK/b.out"; then
  pass "bob lost the claim (task already held by alice)"
else
  fail "expected bob to lose; got: $(cat "$WORK/b.out")"
fi

# STATE.md must show exactly alice as claimer.
tick_a project >/dev/null
if grep -E "^- TASK-007 by alice" "$A/.tick/STATE.md" >/dev/null; then
  pass "STATE.md shows TASK-007 claimed by alice"
else
  cat "$A/.tick/STATE.md"; fail "STATE.md does not show alice as winner"
fi

# Idempotent re-claim by alice returns won.
tick_a claim TASK-007 --agent alice --paths "src/auth/**" >"$WORK/a2.out"
if grep -q "^won:" "$WORK/a2.out"; then
  pass "alice's idempotent re-claim returns won"
else
  fail "idempotent re-claim failed: $(cat "$WORK/a2.out")"
fi

# Terminal task can't be claimed.
tick_a done TASK-007 --agent alice >/dev/null
tick_a claim TASK-007 --agent bob --paths "src/auth/**" >"$WORK/done.out"
if grep -q "^lost:.*done" "$WORK/done.out"; then
  pass "done task returns lost with unavailable=done"
else
  fail "done task claim unexpected: $(cat "$WORK/done.out")"
fi

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
