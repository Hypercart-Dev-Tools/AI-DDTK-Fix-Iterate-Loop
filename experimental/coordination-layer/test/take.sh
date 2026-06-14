#!/usr/bin/env bash
# Run 3: `tick take --agent <id>` is the atomic next+claim verb that replaced the
# `tick next` + `tick claim` two-step (closing the TOCTOU race). This test covers
# the two properties the Run 3 plan gates on — atomic selection+claim, and the
# same-half double-claim refusal — plus the claim cap and cross-agent lane
# separation that fall out of the same candidate filter.
source "$(dirname "$0")/_setup.sh" take

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-A1 --agent dispatcher --priority 10 --paths "src/http/**" >/dev/null
TICK_TS=2026-05-04T10:00:00.100Z tick_a log task.created TASK-A2 --agent dispatcher --priority 8  --paths "src/http/**" >/dev/null
TICK_TS=2026-05-04T10:00:00.200Z tick_a log task.created TASK-B1 --agent dispatcher --priority 5  --paths "src/store/**" >/dev/null

# 1. Atomic next+claim: take selects the highest-priority available task AND
#    claims it in one call. The claim event must exist immediately after.
TICK_TS=2026-05-04T10:00:01.000Z tick_a take --agent alice >"$WORK/t1.out"
if grep -q "^won: TASK-A1 " "$WORK/t1.out"; then
  pass "take selects highest-priority task and reports a win (TASK-A1)"
else
  fail "take did not win TASK-A1: $(cat "$WORK/t1.out")"
fi
CLAIMED=$(ls "$A/.tick/events/" | grep -c "alice-claimed-TASK-A1" || true)
if [ "$CLAIMED" = "1" ]; then
  pass "take atomically emitted the task.claimed event"
else
  fail "expected 1 alice-claimed-TASK-A1 event, got $CLAIMED"
fi

# 2. Same-half double-claim refusal + cross-half allowed: alice already holds the
#    http lane (A1). Her next take must SKIP A2 (http, overlaps her own claim)
#    and instead get B1 (store, no overlap).
TICK_TS=2026-05-04T10:00:02.000Z tick_a take --agent alice >"$WORK/t2.out"
if grep -q "^won: TASK-B1 " "$WORK/t2.out"; then
  pass "take skips the overlapping same-half task and crosses to the free lane (B1)"
else
  fail "take should have won TASK-B1 (not A2): $(cat "$WORK/t2.out")"
fi
if grep -q "TASK-A2" "$WORK/t2.out"; then
  fail "take handed alice TASK-A2, which overlaps her own active claim"
else
  pass "take refused the same-half overlapping task (A2 not granted)"
fi

# 3. Claim cap via take: alice now holds 2 (A1, B1). A third take is refused even
#    though A2 is still open.
TICK_TS=2026-05-04T10:00:03.000Z tick_a take --agent alice >"$WORK/t3.out"
if grep -q "claim limit reached" "$WORK/t3.out"; then
  pass "take enforces the per-agent claim cap (2)"
else
  fail "take did not enforce the claim cap: $(cat "$WORK/t3.out")"
fi

# 4. Cross-agent lane separation: only A2 (http) is open, and it overlaps alice's
#    A1 claim — so bob gets nothing rather than colliding into the http lane.
TICK_TS=2026-05-04T10:00:04.000Z tick_a take --agent bob >"$WORK/t4.out"
if grep -q "no available task" "$WORK/t4.out"; then
  pass "take keeps a second agent out of a lane already claimed by the first"
else
  fail "bob should have gotten no task (A2 overlaps alice's lane): $(cat "$WORK/t4.out")"
fi

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
