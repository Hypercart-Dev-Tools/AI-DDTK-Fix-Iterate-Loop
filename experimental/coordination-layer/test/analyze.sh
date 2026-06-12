#!/usr/bin/env bash
# `tick analyze` test: event-log-only metrics (Run 2 — git log analysis removed
# when the git transport was stripped). Drift/unclaimed detection is deferred.
source "$(dirname "$0")/_setup.sh" analyze

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-001 --agent dispatcher --priority 10 --paths "src/auth/**"    >/dev/null
TICK_TS=2026-05-04T10:00:01.000Z tick_a log task.created TASK-002 --agent dispatcher --priority  5 --paths "src/billing/**" >/dev/null
TICK_TS=2026-05-04T10:00:02.000Z tick_a log task.created TASK-003 --agent dispatcher --priority  1 --paths "src/poison/**"  >/dev/null

# alice: claims TASK-001 at 10:01, done at 10:15.
# bob:   claims TASK-002 at 10:05 (overlaps alice's window), done at 10:30.
# → concurrent-claim window = 10:05-10:15 (10 min out of ~40 min run window).
TICK_TS=2026-05-04T10:01:00.000Z tick_a claim TASK-001 --agent alice --paths "src/auth/**"    >/dev/null
TICK_TS=2026-05-04T10:05:00.000Z tick_b claim TASK-002 --agent bob   --paths "src/billing/**" >/dev/null
TICK_TS=2026-05-04T10:15:00.000Z tick_a done  TASK-001 --agent alice                          >/dev/null
TICK_TS=2026-05-04T10:30:00.000Z tick_b done  TASK-002 --agent bob                            >/dev/null

# alice: claims and breaks TASK-003 at 10:40-10:41.
TICK_TS=2026-05-04T10:40:00.000Z tick_a claim TASK-003 --agent alice --paths "src/poison/**" >/dev/null
TICK_TS=2026-05-04T10:41:00.000Z tick_a break TASK-003 --agent alice --reason "loop"         >/dev/null

HUMAN=$(tick_a analyze)
echo "$HUMAN" >"$WORK/human.txt"

# Event counts.
echo "$HUMAN" | grep -q "created:3" \
  && pass "event count: 3 created" \
  || fail "expected created:3 in: $(echo "$HUMAN" | head -3)"

echo "$HUMAN" | grep -q "claimed:3" \
  && pass "event count: 3 claimed" \
  || fail "expected claimed:3"

echo "$HUMAN" | grep -q "done:2" \
  && pass "event count: 2 done" \
  || fail "expected done:2"

echo "$HUMAN" | grep -q "circuit_break:1" \
  && pass "event count: 1 circuit_break" \
  || fail "expected circuit_break:1"

# Per-agent stats.
echo "$HUMAN" | grep -A2 "\[alice\]" | grep -q "claims: 2, done: 1" \
  && pass "alice: 2 claims, 1 done" \
  || fail "alice per-agent stats unexpected: $(echo "$HUMAN" | grep -A3 '\[alice\]')"

echo "$HUMAN" | grep -A2 "\[bob\]" | grep -q "claims: 1, done: 1" \
  && pass "bob: 1 claim, 1 done" \
  || fail "bob per-agent stats unexpected: $(echo "$HUMAN" | grep -A3 '\[bob\]')"

# Concurrent-claim time: alice (10:01-10:15) overlaps bob (10:05-10:30).
# Overlap = 10:05-10:15 = 10 min > 0. Expect a percentage like (24%).
if echo "$HUMAN" | grep "concurrent-claim time" | grep -qE "\([1-9][0-9]*%\)"; then
  pass "concurrent-claim time is non-zero (overlapping claim windows detected)"
else
  fail "expected non-zero concurrent-claim time; got: $(echo "$HUMAN" | grep concurrent)"
fi

# --write: appends auto-analyzed section to a target file.
TARGET="$WORK/obs.md"
echo "# Observations" >"$TARGET"
tick_a analyze --write "$TARGET" >/dev/null
grep -q "^## Auto-analyzed (tick analyze)" "$TARGET" \
  && pass "tick analyze --write appended the auto-analyzed section" \
  || { cat "$TARGET"; fail "missing auto-analyzed section in target"; }

# Second --write replaces, doesn't append twice.
tick_a analyze --write "$TARGET" >/dev/null
HITS=$(grep -c "^## Auto-analyzed (tick analyze)" "$TARGET")
[ "$HITS" = "1" ] \
  && pass "second --write replaces, doesn't duplicate" \
  || fail "expected 1 section, got $HITS"

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
