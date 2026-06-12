#!/usr/bin/env bash
# Run 2 P1/P2: per-agent claim cap (MAX_ACTIVE_CLAIMS_PER_AGENT = 2).
# An agent may hold at most 2 active claims. The 3rd claim is refused and
# writes ZERO events; `tick next` reports the limit; after `tick done` frees a
# slot, the 3rd claim succeeds. Tasks have non-overlapping paths so the cap —
# not path-routing — is what blocks the 3rd claim.
source "$(dirname "$0")/_setup.sh" claim-cap

git -C "$A" config user.name alice

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-1 --agent dispatcher --priority 10 --paths "src/one/**"   >/dev/null
TICK_TS=2026-05-04T10:00:00.100Z tick_a log task.created TASK-2 --agent dispatcher --priority 10 --paths "src/two/**"   >/dev/null
TICK_TS=2026-05-04T10:00:00.200Z tick_a log task.created TASK-3 --agent dispatcher --priority 10 --paths "src/three/**" >/dev/null
git -C "$A" add .tick && git -C "$A" commit -q -m "seed tasks" && git -C "$A" push -q origin main

# alice claims two — both win (non-overlapping paths, under the cap).
TICK_TS=2026-05-04T10:00:01.000Z tick_a claim TASK-1 --agent alice --paths "src/one/**" >"$WORK/c1.out"
TICK_TS=2026-05-04T10:00:02.000Z tick_a claim TASK-2 --agent alice --paths "src/two/**" >"$WORK/c2.out"
if grep -q "^won:" "$WORK/c1.out" && grep -q "^won:" "$WORK/c2.out"; then
  pass "alice claimed two tasks (under cap)"
else
  fail "alice could not claim two tasks: $(cat "$WORK/c1.out" "$WORK/c2.out")"
fi

# Snapshot event count before the capped claim attempt.
BEFORE=$(ls "$A/.tick/events/" | wc -l | tr -d ' ')

# Third claim must be refused with the limit message.
TICK_TS=2026-05-04T10:00:03.000Z tick_a claim TASK-3 --agent alice --paths "src/three/**" >"$WORK/c3.out"
if grep -q "claim limit reached" "$WORK/c3.out"; then
  pass "third claim refused with limit message"
else
  fail "third claim was not refused: $(cat "$WORK/c3.out")"
fi

# ...and must have written ZERO events.
AFTER=$(ls "$A/.tick/events/" | wc -l | tr -d ' ')
if [ "$BEFORE" = "$AFTER" ]; then
  pass "refused claim wrote zero events ($BEFORE == $AFTER)"
else
  fail "refused claim wrote events ($BEFORE -> $AFTER)"
fi

# `tick next` must report the limit, not hand out TASK-3.
tick_a next --agent alice >"$WORK/n.out" 2>/dev/null
if grep -q "claim limit reached" "$WORK/n.out"; then
  pass "tick next reports the claim limit"
else
  fail "tick next did not report the limit: $(cat "$WORK/n.out")"
fi

# Finish one task — frees a slot.
TICK_TS=2026-05-04T10:00:04.000Z tick_a done TASK-1 --agent alice >/dev/null

# Now the third claim should succeed.
TICK_TS=2026-05-04T10:00:05.000Z tick_a claim TASK-3 --agent alice --paths "src/three/**" >"$WORK/c3b.out"
if grep -q "^won:" "$WORK/c3b.out"; then
  pass "third claim succeeds after a slot is freed"
else
  fail "third claim still refused after done: $(cat "$WORK/c3b.out")"
fi

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
