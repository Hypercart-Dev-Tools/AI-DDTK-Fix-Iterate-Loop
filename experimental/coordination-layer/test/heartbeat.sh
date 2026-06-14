#!/usr/bin/env bash
# Run 3: `tick ping` emits a task.heartbeat liveness event (ownership-guarded),
# and `tick analyze` flags a claim window with no heartbeat for longer than the
# parked-claim threshold (10 min) as a parked-claim suspect — the work-activity
# signal that does NOT depend on git author identity.
source "$(dirname "$0")/_setup.sh" heartbeat

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-1 --agent dispatcher --priority 10 --paths "src/http/**" >/dev/null
TICK_TS=2026-05-04T10:00:00.100Z tick_a log task.created TASK-2 --agent dispatcher --priority 10 --paths "src/store/**" >/dev/null

# alice claims both (cross-half, within the cap of 2).
TICK_TS=2026-05-04T10:00:01.000Z tick_a claim TASK-1 --agent alice --paths "src/http/**" >/dev/null
TICK_TS=2026-05-04T10:00:02.000Z tick_a claim TASK-2 --agent alice --paths "src/store/**" >/dev/null

# Ownership guard: a non-claimer cannot heartbeat the task.
if TICK_TS=2026-05-04T10:00:03.000Z tick_a ping TASK-1 --agent bob >"$WORK/bobping.out" 2>&1; then
  fail "bob (non-owner) was allowed to ping TASK-1: $(cat "$WORK/bobping.out")"
else
  pass "ping is ownership-guarded (non-owner rejected)"
fi

# alice heartbeats TASK-1 mid-window; emits a task.heartbeat event file.
TICK_TS=2026-05-04T10:05:01.000Z tick_a ping TASK-1 --agent alice >/dev/null
BEATS=$(ls "$A/.tick/events/" | grep -c "alice-heartbeat-TASK-1" || true)
if [ "$BEATS" = "1" ]; then
  pass "tick ping emitted a task.heartbeat event"
else
  fail "expected 1 alice-heartbeat-TASK-1 event, got $BEATS"
fi

# Close both windows. TASK-1: claimed 10:00:01, beat 10:05:01, done 10:08:01
# (max gap 5m < 10m → healthy). TASK-2: claimed 10:00:02, NO beats, done
# 10:20:02 (20m gap > 10m → parked suspect).
TICK_TS=2026-05-04T10:08:01.000Z tick_a done TASK-1 --agent alice >/dev/null
TICK_TS=2026-05-04T10:20:02.000Z tick_a done TASK-2 --agent alice >/dev/null

tick_a analyze --format json >"$WORK/analyze.json"
PARKED=$(node -e 'const r=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); console.log(r.parked_suspects.map(s=>s.task).sort().join(","))' "$WORK/analyze.json")

if [ "$PARKED" = "TASK-2" ]; then
  pass "analyze flags only the heartbeat-less claim as parked (TASK-2)"
else
  fail "expected parked_suspects=[TASK-2], got [$PARKED]"
fi

# The heartbeat-covered window must NOT be flagged.
if echo "$PARKED" | grep -q "TASK-1"; then
  fail "TASK-1 wrongly flagged parked despite an in-window heartbeat"
else
  pass "heartbeat-covered claim window is not flagged parked"
fi

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
