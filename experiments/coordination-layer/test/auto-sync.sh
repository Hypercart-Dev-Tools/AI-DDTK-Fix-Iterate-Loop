#!/usr/bin/env bash
# AC #7: each critical-event verb produces exactly one push to origin.
# `tick log task.commented` produces zero pushes.
source "$(dirname "$0")/_setup.sh" auto-sync

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-001 --agent dispatcher --priority 1 --paths "src/foo/**" >/dev/null
TICK_TS=2026-05-04T10:00:01.000Z tick_a log task.created TASK-002 --agent dispatcher --priority 1 --paths "src/bar/**" >/dev/null
git -C "$A" add .tick && git -C "$A" commit -q -m "seed" && git -C "$A" push -q origin main

count_remote_commits() {
  git -C "$REMOTE" rev-list --count main 2>/dev/null || echo 0
}

# Each critical verb increments remote commit count by exactly 1.
for verb in claim scope release done_ break_; do
  before=$(count_remote_commits)
  case "$verb" in
    claim)    TICK_TS=2026-05-04T11:00:00.000Z tick_a claim TASK-001 --agent alice --paths "src/foo/**" >/dev/null ;;
    scope)    TICK_TS=2026-05-04T11:00:01.000Z tick_a scope TASK-001 --agent alice --paths "src/foo/**,src/foo2/**" >/dev/null ;;
    release)  TICK_TS=2026-05-04T11:00:02.000Z tick_a release TASK-001 --agent alice >/dev/null ;;
    done_)    TICK_TS=2026-05-04T11:00:03.000Z tick_a claim TASK-002 --agent alice --paths "src/bar/**" >/dev/null
              before=$(count_remote_commits)
              TICK_TS=2026-05-04T11:00:04.000Z tick_a done TASK-002 --agent alice >/dev/null ;;
    break_)   TICK_TS=2026-05-04T11:00:05.000Z tick_a log task.created TASK-003 --agent dispatcher --priority 1 --paths "src/baz/**" >/dev/null
              git -C "$A" add .tick && git -C "$A" commit -q -m "create T3" && git -C "$A" push -q origin main
              before=$(count_remote_commits)
              TICK_TS=2026-05-04T11:00:06.000Z tick_a break TASK-003 --agent alice --reason "test" >/dev/null ;;
  esac
  after=$(count_remote_commits)
  delta=$((after - before))
  if [ "$delta" -eq 1 ]; then
    pass "$verb produced exactly 1 remote commit (delta=$delta)"
  else
    fail "$verb produced $delta remote commits (expected 1)"
  fi
done

# task.commented: zero pushes.
before=$(count_remote_commits)
TICK_TS=2026-05-04T12:00:00.000Z tick_a log task.commented TASK-001 --agent alice --note "FYI just a note" >/dev/null
after=$(count_remote_commits)
delta=$((after - before))
if [ "$delta" -eq 0 ]; then
  pass "task.commented produced 0 remote commits (event written locally only)"
else
  fail "task.commented produced $delta remote commits (expected 0)"
fi

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
