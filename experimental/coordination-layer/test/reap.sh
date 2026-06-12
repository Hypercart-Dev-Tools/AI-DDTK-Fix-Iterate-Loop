#!/usr/bin/env bash
# Run 2 P5: `tick reap <agent>` releases every active claim held by a
# (presumed crashed) agent so peers can pick the work back up. Manual,
# logged liveness lever — not auto-recovery.
source "$(dirname "$0")/_setup.sh" reap

git -C "$A" config user.name alice
git -C "$B" config user.name bob

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-1 --agent dispatcher --priority 10 --paths "src/one/**" >/dev/null
TICK_TS=2026-05-04T10:00:00.100Z tick_a log task.created TASK-2 --agent dispatcher --priority 10 --paths "src/two/**" >/dev/null

# alice claims both, then "crashes" (just stops).
TICK_TS=2026-05-04T10:00:01.000Z tick_a claim TASK-1 --agent alice --paths "src/one/**" >/dev/null
TICK_TS=2026-05-04T10:00:02.000Z tick_a claim TASK-2 --agent alice --paths "src/two/**" >/dev/null

# Coordinator reaps alice's claims. tick_b shares TICK_REPO_ROOT with tick_a.
TICK_TS=2026-05-04T10:00:05.000Z tick_b reap alice --by coordinator >"$WORK/reap.out"
if grep -q "reaped 2 claim(s) from alice" "$WORK/reap.out"; then
  pass "reap released both of alice's claims"
else
  fail "reap output unexpected: $(cat "$WORK/reap.out")"
fi

# Two task.released events for alice must exist in the log.
RELEASED=$(ls "$A/.tick/events/" | grep -c "alice-released" || true)
if [ "$RELEASED" = "2" ]; then
  pass "two task.released events emitted for alice"
else
  fail "expected 2 alice-released events, got $RELEASED"
fi

# STATE.md: tasks must no longer be claimed by alice.
tick_b project >/dev/null
if grep -qE "^- TASK-1 by alice" "$A/.tick/STATE.md"; then
  fail "TASK-1 still claimed by alice after reap"
else
  pass "TASK-1 no longer claimed by alice after reap"
fi

# A peer can now claim a reaped task.
TICK_TS=2026-05-04T10:00:10.000Z tick_b claim TASK-1 --agent bob --paths "src/one/**" >"$WORK/bob.out"
if grep -q "^won:" "$WORK/bob.out"; then
  pass "a peer can claim a reaped task"
else
  fail "peer could not claim reaped task: $(cat "$WORK/bob.out")"
fi

# Reaping an agent with no active claims is a clean no-op.
TICK_TS=2026-05-04T10:00:11.000Z tick_b reap alice --by coordinator >"$WORK/reap2.out"
if grep -q "no active claims held by alice" "$WORK/reap2.out"; then
  pass "reap of an agent with no claims is a clean no-op"
else
  fail "reap no-op output unexpected: $(cat "$WORK/reap2.out")"
fi

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
