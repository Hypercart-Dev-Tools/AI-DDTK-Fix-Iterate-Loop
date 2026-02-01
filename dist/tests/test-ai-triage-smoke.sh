#!/usr/bin/env bash
#
# WP Code Check - AI Triage Smoke Test
# Version: 1.0.0
#
# Tests that ai-triage.py correctly injects ai_triage data into JSON logs.
# This is a regression test to prevent silent failures where the script
# runs successfully but doesn't persist the triage data.
#
# Usage:
#   ./test-ai-triage-smoke.sh

set -eu

# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/../bin"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
TEMP_DIR=$(mktemp -d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================
# Helper Functions
# ============================================================

print_header() {
  echo -e "${BOLD}${BLUE}================================================${NC}"
  echo -e "${BOLD}${BLUE}  WP Code Check - AI Triage Smoke Test${NC}"
  echo -e "${BOLD}${BLUE}================================================${NC}"
  echo ""
}

pass_test() {
  echo -e "${GREEN}✓ PASS:${NC} $1"
  ((TESTS_PASSED++))
  ((TESTS_RUN++))
}

fail_test() {
  echo -e "${RED}✗ FAIL:${NC} $1"
  ((TESTS_FAILED++))
  ((TESTS_RUN++))
}

print_summary() {
  echo ""
  echo -e "${BOLD}${BLUE}================================================${NC}"
  echo -e "${BOLD}Test Summary${NC}"
  echo -e "${BOLD}${BLUE}================================================${NC}"
  echo -e "Total Tests: ${TESTS_RUN}"
  echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
  echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
  echo ""
  
  if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ All tests passed!${NC}"
    return 0
  else
    echo -e "${RED}${BOLD}✗ Some tests failed${NC}"
    return 1
  fi
}

cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}

# Don't cleanup on EXIT during test execution
# We'll cleanup manually at the end
# trap cleanup EXIT

# ============================================================
# Test Setup
# ============================================================

print_header

echo -e "${BOLD}Setup:${NC}"
echo -e "  Script Dir: $SCRIPT_DIR"
echo -e "  Bin Dir: $BIN_DIR"
echo -e "  Temp Dir: $TEMP_DIR"
echo ""

# Verify required files exist
if [ ! -f "$BIN_DIR/check-performance.sh" ]; then
  echo -e "${RED}Error: check-performance.sh not found${NC}"
  exit 1
fi

if [ ! -f "$BIN_DIR/ai-triage.py" ]; then
  echo -e "${RED}Error: ai-triage.py not found${NC}"
  exit 1
fi

if [ ! -f "$FIXTURES_DIR/antipatterns.php" ]; then
  echo -e "${RED}Error: antipatterns.php fixture not found${NC}"
  exit 1
fi

# ============================================================
# Test 1: Generate a scan log with findings
# ============================================================

echo -e "${BOLD}Test 1: Generate scan log with findings${NC}"
echo ""

# Run scan and capture output
set +e
SCAN_OUTPUT=$("$BIN_DIR/check-performance.sh" \
  --paths "$FIXTURES_DIR/antipatterns.php" \
  --format json \
  --no-log 2>&1)
SCAN_EXIT_CODE=$?
set -e

# Save to temp file
TEST_JSON="$TEMP_DIR/test-scan.json"

# Extract JSON (from first { to last })
# The JSON is output first, then other messages follow
# Just take everything from first { to first standalone }
echo "$SCAN_OUTPUT" | sed -n '/^{/,/^}$/p' > "$TEST_JSON"

# Verify JSON is valid
if command -v jq &> /dev/null; then
  if jq empty "$TEST_JSON" 2>/dev/null; then
    pass_test "Generated valid JSON log"
  else
    fail_test "Generated JSON is invalid"
    exit 1
  fi
else
  # Fallback: check if file contains findings
  if grep -q '"findings"' "$TEST_JSON" 2>/dev/null; then
    pass_test "Generated JSON log (jq not available for validation)"
  else
    fail_test "Generated JSON does not contain findings"
    exit 1
  fi
fi

# Verify findings exist
if [ ! -f "$TEST_JSON" ]; then
  fail_test "JSON file does not exist at $TEST_JSON"
  exit 1
fi

FINDINGS_COUNT=$(grep -c '"findings"' "$TEST_JSON" 2>/dev/null || echo "0")
if [ "$FINDINGS_COUNT" -gt 0 ]; then
  pass_test "JSON contains findings array"
else
  fail_test "JSON does not contain findings"
  exit 1
fi

echo ""

# ============================================================
# Test 2: Run AI triage on the log
# ============================================================

echo -e "${BOLD}Test 2: Run AI triage${NC}"
echo ""

# Run ai-triage.py
TRIAGE_OUTPUT=$(python3 "$BIN_DIR/ai-triage.py" "$TEST_JSON" --max-findings 50 2>&1)
TRIAGE_EXIT_CODE=$?

echo "$TRIAGE_OUTPUT"
echo ""

if [ $TRIAGE_EXIT_CODE -eq 0 ]; then
  pass_test "ai-triage.py exited with code 0"
else
  fail_test "ai-triage.py exited with code $TRIAGE_EXIT_CODE"
fi

# ============================================================
# Test 3: Verify ai_triage key exists
# ============================================================

echo -e "${BOLD}Test 3: Verify ai_triage data persisted${NC}"
echo ""

if command -v jq &> /dev/null; then
  HAS_AI_TRIAGE=$(jq 'has("ai_triage")' "$TEST_JSON")
  if [ "$HAS_AI_TRIAGE" = "true" ]; then
    pass_test "ai_triage key exists in JSON"
  else
    fail_test "ai_triage key NOT found in JSON"
  fi
else
  # Fallback: grep for ai_triage
  if grep -q '"ai_triage"' "$TEST_JSON"; then
    pass_test "ai_triage key exists in JSON (grep check)"
  else
    fail_test "ai_triage key NOT found in JSON"
  fi
fi

# ============================================================
# Test 4: Verify ai_triage.performed is true
# ============================================================

if command -v jq &> /dev/null; then
  PERFORMED=$(jq -r '.ai_triage.performed' "$TEST_JSON")
  if [ "$PERFORMED" = "true" ]; then
    pass_test "ai_triage.performed is true"
  else
    fail_test "ai_triage.performed is not true (got: $PERFORMED)"
  fi
else
  if grep -q '"performed": true' "$TEST_JSON"; then
    pass_test "ai_triage.performed is true (grep check)"
  else
    fail_test "ai_triage.performed is not true"
  fi
fi

# ============================================================
# Test 5: Verify summary fields exist
# ============================================================

if command -v jq &> /dev/null; then
  CONFIRMED=$(jq -r '.ai_triage.summary.confirmed_issues' "$TEST_JSON")
  FALSE_POS=$(jq -r '.ai_triage.summary.false_positives' "$TEST_JSON")
  NEEDS_REVIEW=$(jq -r '.ai_triage.summary.needs_review' "$TEST_JSON")
  CONFIDENCE=$(jq -r '.ai_triage.summary.confidence_level' "$TEST_JSON")

  if [ "$CONFIRMED" != "null" ] && [ "$FALSE_POS" != "null" ] && [ "$NEEDS_REVIEW" != "null" ] && [ "$CONFIDENCE" != "null" ]; then
    pass_test "All summary fields exist (confirmed: $CONFIRMED, false_pos: $FALSE_POS, needs_review: $NEEDS_REVIEW, confidence: $CONFIDENCE)"
  else
    fail_test "Some summary fields are missing"
  fi
else
  if grep -q '"confirmed_issues"' "$TEST_JSON" && grep -q '"false_positives"' "$TEST_JSON" && grep -q '"needs_review"' "$TEST_JSON" && grep -q '"confidence_level"' "$TEST_JSON"; then
    pass_test "All summary fields exist (grep check)"
  else
    fail_test "Some summary fields are missing"
  fi
fi

# ============================================================
# Test 6: Verify triaged_findings array exists
# ============================================================

if command -v jq &> /dev/null; then
  TRIAGED_COUNT=$(jq '.ai_triage.triaged_findings | length' "$TEST_JSON")
  if [ "$TRIAGED_COUNT" -gt 0 ]; then
    pass_test "triaged_findings array has $TRIAGED_COUNT items"
  else
    fail_test "triaged_findings array is empty"
  fi
else
  if grep -q '"triaged_findings"' "$TEST_JSON"; then
    pass_test "triaged_findings array exists (grep check)"
  else
    fail_test "triaged_findings array not found"
  fi
fi

# ============================================================
# Test 7: Verify JSON is still valid after triage
# ============================================================

echo ""
echo -e "${BOLD}Test 7: Verify JSON validity after triage${NC}"
echo ""

if command -v jq &> /dev/null; then
  if jq empty "$TEST_JSON" 2>/dev/null; then
    pass_test "JSON is still valid after triage injection"
  else
    fail_test "JSON is INVALID after triage injection"
  fi
else
  # Basic check: file is not empty and contains closing brace
  if [ -s "$TEST_JSON" ] && tail -1 "$TEST_JSON" | grep -q '}'; then
    pass_test "JSON appears valid (basic check)"
  else
    fail_test "JSON may be corrupted"
  fi
fi

# ============================================================
# Print Summary
# ============================================================

print_summary
EXIT_CODE=$?

# Cleanup temp directory
cleanup

exit $EXIT_CODE


