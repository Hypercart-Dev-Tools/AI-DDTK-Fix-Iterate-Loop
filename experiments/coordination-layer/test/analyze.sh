#!/usr/bin/env bash
# `tick analyze` test: synthetic two-agent run with deliberate drift, an
# unclaimed-work commit, and a circuit-broken task. Asserts the analyzer
# correctly identifies all three.
source "$(dirname "$0")/_setup.sh" analyze

# Helper: commit work files with controlled author/committer date so the
# git timestamp lands inside our synthetic claim windows.
work_commit() {
  local clone="$1" who="$2" ts="$3" msg="$4"; shift 4
  GIT_AUTHOR_DATE="$ts" GIT_COMMITTER_DATE="$ts" \
    git -C "$clone" -c user.name="$who" -c user.email="${who}@t" \
    commit -q -m "$msg"
}

tick_a init >/dev/null
TICK_TS=2026-05-04T10:00:00.000Z tick_a log task.created TASK-001 --agent dispatcher --priority 10 --paths "src/auth/**" >/dev/null
TICK_TS=2026-05-04T10:00:01.000Z tick_a log task.created TASK-002 --agent dispatcher --priority  5 --paths "src/billing/**" >/dev/null
TICK_TS=2026-05-04T10:00:02.000Z tick_a log task.created TASK-003 --agent dispatcher --priority  1 --paths "src/poison/**" >/dev/null
git -C "$A" add .tick && git -C "$A" commit -q -m "seed" && git -C "$A" push -q origin main
git -C "$B" pull -q --rebase origin main

# Agent alice: clean run on TASK-001, all work in scope, completes with `tick done`.
TICK_TS=2026-05-04T10:01:00.000Z tick_a claim TASK-001 --agent alice --paths "src/auth/**" >/dev/null
mkdir -p "$A/src/auth"
echo "// auth login" > "$A/src/auth/login.js"
git -C "$A" add src/auth/login.js
work_commit "$A" alice "2026-05-04T10:05:00 +0000" "implement login"
mkdir -p "$A/src/auth"
echo "// auth logout" > "$A/src/auth/logout.js"
git -C "$A" add src/auth/logout.js
work_commit "$A" alice "2026-05-04T10:10:00 +0000" "implement logout"
git -C "$A" push -q origin main
TICK_TS=2026-05-04T10:15:00.000Z tick_a done TASK-001 --agent alice >/dev/null

# Agent bob: claims TASK-002, drifts into src/shared during the claim window,
# then completes. Should be flagged as path-drift.
git -C "$B" pull -q --rebase origin main
TICK_TS=2026-05-04T10:20:00.000Z tick_b claim TASK-002 --agent bob --paths "src/billing/**" >/dev/null
mkdir -p "$B/src/billing"
echo "// billing" > "$B/src/billing/charge.js"
git -C "$B" add src/billing/charge.js
work_commit "$B" bob "2026-05-04T10:25:00 +0000" "implement charge"
mkdir -p "$B/src/shared"
echo "// drifted helper" > "$B/src/shared/util.js"
git -C "$B" add src/shared/util.js
work_commit "$B" bob "2026-05-04T10:26:00 +0000" "drift: edit shared util outside declared scope"
git -C "$B" push -q origin main
TICK_TS=2026-05-04T10:30:00.000Z tick_b done TASK-002 --agent bob >/dev/null

# Agent bob commits something outside any active claim window — pure unclaimed work.
git -C "$B" pull -q --rebase origin main
mkdir -p "$B/src/random"
echo "// random" > "$B/src/random/oops.js"
git -C "$B" add src/random/oops.js
work_commit "$B" bob "2026-05-04T10:35:00 +0000" "no claim before this edit"
git -C "$B" push -q origin main

# Agent alice circuit-breaks TASK-003.
git -C "$A" pull -q --rebase origin main
TICK_TS=2026-05-04T10:40:00.000Z tick_a claim TASK-003 --agent alice --paths "src/poison/**" >/dev/null
TICK_TS=2026-05-04T10:41:00.000Z tick_a break TASK-003 --agent alice --reason "infinite loop in tests" >/dev/null

# Run analyzer (JSON output for deterministic assertions).
git -C "$A" pull -q --rebase origin main
JSON=$(tick_a analyze --format json)
echo "$JSON" >"$WORK/report.json"

# Helper: jq if available, else node fallback.
jget() {
  if command -v jq >/dev/null 2>&1; then
    echo "$JSON" | jq -r "$1"
  else
    node -e "const r = JSON.parse(require('fs').readFileSync('$WORK/report.json','utf8')); const path = require('path'); const _get = (o,p) => p.split(/[.\[\]]/).filter(Boolean).reduce((a,k)=> a==null?a:a[k.match(/^\d+$/)?Number(k):k], o); process.stdout.write(String(_get(r, ${1@Q}.replace(/^\./,''))));"
  fi
}

ALICE_DRIFT=$(jget '.agents[] | select(.agent=="alice") | .work_commits_drift')
ALICE_IN=$(jget '.agents[] | select(.agent=="alice") | .work_commits_in_scope')
ALICE_UNCLAIMED=$(jget '.agents[] | select(.agent=="alice") | .work_commits_unclaimed')
ALICE_DONES=$(jget '.agents[] | select(.agent=="alice") | .dones')
ALICE_BREAKS=$(jget '.agents[] | select(.agent=="alice") | .breaks')

BOB_DRIFT=$(jget '.agents[] | select(.agent=="bob") | .work_commits_drift')
BOB_IN=$(jget '.agents[] | select(.agent=="bob") | .work_commits_in_scope')
BOB_UNCLAIMED=$(jget '.agents[] | select(.agent=="bob") | .work_commits_unclaimed')
BOB_DONES=$(jget '.agents[] | select(.agent=="bob") | .dones')

echo "  alice: in_scope=$ALICE_IN drift=$ALICE_DRIFT unclaimed=$ALICE_UNCLAIMED dones=$ALICE_DONES breaks=$ALICE_BREAKS"
echo "  bob:   in_scope=$BOB_IN drift=$BOB_DRIFT unclaimed=$BOB_UNCLAIMED dones=$BOB_DONES"

# Alice: 2 in-scope commits, no drift, no unclaimed, 1 done, 1 break.
[ "$ALICE_IN" = "2" ]       && pass "alice has 2 in-scope work commits" || fail "expected alice in_scope=2 got $ALICE_IN"
[ "$ALICE_DRIFT" = "0" ]    && pass "alice has no drift"                || fail "expected alice drift=0 got $ALICE_DRIFT"
[ "$ALICE_UNCLAIMED" = "0" ] && pass "alice has no unclaimed work"      || fail "expected alice unclaimed=0 got $ALICE_UNCLAIMED"
[ "$ALICE_DONES" = "1" ]    && pass "alice has 1 done"                  || fail "expected alice dones=1 got $ALICE_DONES"
[ "$ALICE_BREAKS" = "1" ]   && pass "alice has 1 break"                 || fail "expected alice breaks=1 got $ALICE_BREAKS"

# Bob: 1 in-scope, 1 drift, 1 unclaimed, 1 done.
[ "$BOB_IN" = "1" ]       && pass "bob has 1 in-scope work commit"   || fail "expected bob in_scope=1 got $BOB_IN"
[ "$BOB_DRIFT" = "1" ]    && pass "bob has 1 drift commit"           || fail "expected bob drift=1 got $BOB_DRIFT"
[ "$BOB_UNCLAIMED" = "1" ] && pass "bob has 1 unclaimed work commit" || fail "expected bob unclaimed=1 got $BOB_UNCLAIMED"
[ "$BOB_DONES" = "1" ]    && pass "bob has 1 done"                   || fail "expected bob dones=1 got $BOB_DONES"

# Markdown render: --write should append/replace a section in a target file.
TARGET="$WORK/observations.md"
echo "# Observations" >"$TARGET"
tick_a analyze --write "$TARGET" >/dev/null
if grep -q "^## Auto-analyzed (tick analyze)" "$TARGET"; then
  pass "tick analyze --write appended the auto-analyzed section"
else
  cat "$TARGET"; fail "missing auto-analyzed section in target file"
fi
# Replace, not append twice.
tick_a analyze --write "$TARGET" >/dev/null
HITS=$(grep -c "^## Auto-analyzed (tick analyze)" "$TARGET")
[ "$HITS" = "1" ] && pass "second --write replaces, doesn't duplicate" || fail "expected 1 section, got $HITS"

echo "  $TEST_NAME: $PASS pass, $FAIL fail"
exit 0
