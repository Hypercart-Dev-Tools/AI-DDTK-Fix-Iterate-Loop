#!/usr/bin/env bash
# Run 2: git auto-sync (push-per-verb) was removed with the local transport.
# This test verifies the O_EXCL claim lock: concurrent shell-level claim calls
# serialise correctly — exactly one wins, exactly one event written.
source "$(dirname "$0")/_setup.sh" auto-sync

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-L1 --agent dispatcher --priority 10 --paths "src/lock/**" >/dev/null
TICK_TS=2026-05-04T10:00:01.000Z tick_a log task.created TASK-L2 --agent dispatcher --priority  8 --paths "src/other/**" >/dev/null

# Fire two claim attempts in parallel; lock serialises them.
# Capture stdout+stderr: the lock loser exits 1 with an error on stderr
# ("another tick claim in progress"), not a "lost:" on stdout.
tick_a claim TASK-L1 --agent alice --paths "src/lock/**" >"$WORK/a.out" 2>&1 &
tick_b claim TASK-L1 --agent bob   --paths "src/lock/**" >"$WORK/b.out" 2>&1 &
wait

A_OUT=$(cat "$WORK/a.out")
B_OUT=$(cat "$WORK/b.out")
echo "  alice: $A_OUT"
echo "  bob:   $B_OUT"

is_winner() { echo "$1" | grep -q "^won:"; }
is_loser()  { echo "$1" | grep -qE "^lost:|another tick claim is in progress"; }

WINS=0
is_winner "$A_OUT" && WINS=$((WINS+1)) || true
is_winner "$B_OUT" && WINS=$((WINS+1)) || true
LOSSES=0
is_loser "$A_OUT" && LOSSES=$((LOSSES+1)) || true
is_loser "$B_OUT" && LOSSES=$((LOSSES+1)) || true

[ "$WINS" = "1" ]   && pass "exactly one agent won the concurrent claim" \
                    || fail "expected 1 winner, got $WINS"
[ "$LOSSES" = "1" ] && pass "exactly one agent lost the concurrent claim" \
                    || fail "expected 1 loser, got $LOSSES"

# Exactly one task.claimed event must exist for TASK-L1 (no double-write).
CLAIMED_COUNT=$(grep -rl '"task":"TASK-L1"' "$A/.tick/events/" 2>/dev/null \
  | xargs grep -l '"type":"task.claimed"' 2>/dev/null | wc -l | tr -d ' ')
[ "$CLAIMED_COUNT" = "1" ] \
  && pass "exactly one task.claimed event written (lock integrity)" \
  || fail "expected 1 claimed event for TASK-L1, got $CLAIMED_COUNT"

# Projection must succeed after the concurrent race.
tick_a project >/dev/null
pass "projection succeeded after concurrent claims (no corrupted state)"

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
