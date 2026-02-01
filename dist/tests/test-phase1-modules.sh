#!/usr/bin/env bash
#
# Phase 1 Module Tests
# Tests the utils.sh and precheck.sh libraries independently
#

set -e  # Exit on error for this test script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."  # Change to dist directory

# Source the libraries
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/precheck.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Phase 1 Module Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper
run_test() {
  local test_name="$1"
  shift
  
  ((TESTS_RUN++))
  echo "▸ Testing: $test_name"
  
  if "$@"; then
    echo "  ✓ PASSED"
    ((TESTS_PASSED++))
    return 0
  else
    echo "  ✗ FAILED"
    ((TESTS_FAILED++))
    return 1
  fi
}

# ============================================================
# Test utils.sh
# ============================================================

echo "Testing utils.sh..."
echo ""

# Test 1: Logging functions
test_logging() {
  log INFO "Test info message" 2>/dev/null
  log DEBUG "Test debug message" 2>/dev/null
  log ERROR "Test error message" 2>/dev/null
  return 0
}
run_test "Logging functions" test_logging

# Test 2: assert_eq with matching values
test_assert_eq_pass() {
  assert_eq "test" "5" "5" >/dev/null 2>&1
}
run_test "assert_eq (pass)" test_assert_eq_pass

# Test 3: assert_eq with non-matching values
test_assert_eq_fail() {
  ! assert_eq "test" "5" "10" >/dev/null 2>&1
}
run_test "assert_eq (fail)" test_assert_eq_fail

# Test 4: assert_range with value in range
test_assert_range_pass() {
  assert_range "test" 1 10 5 >/dev/null 2>&1
}
run_test "assert_range (pass)" test_assert_range_pass

# Test 5: assert_range with value out of range
test_assert_range_fail() {
  ! assert_range "test" 1 10 15 >/dev/null 2>&1
}
run_test "assert_range (fail)" test_assert_range_fail

# Test 6: parse_json with valid JSON
test_parse_json() {
  local json='{"foo":"bar","count":42}'
  local result
  result=$(parse_json "$json" '.count')
  [ "$result" = "42" ]
}
run_test "parse_json (valid)" test_parse_json

# Test 7: parse_json with invalid JSON
test_parse_json_invalid() {
  local json='not json'
  local result
  result=$(parse_json "$json" '.foo' "default" 2>/dev/null)
  [ "$result" = "default" ]
}
run_test "parse_json (invalid)" test_parse_json_invalid

# Test 8: validate_json
test_validate_json() {
  local json='{"valid":"json"}'
  validate_json "$json"
}
run_test "validate_json (valid)" test_validate_json

# Test 9: strip_ansi
test_strip_ansi() {
  local text=$'\033[0;31mRed text\033[0m'
  local result
  result=$(strip_ansi "$text")
  [ "$result" = "Red text" ]
}
run_test "strip_ansi" test_strip_ansi

# ============================================================
# Test precheck.sh
# ============================================================

echo ""
echo "Testing precheck.sh..."
echo ""

# Test 10: precheck_dependencies
test_precheck_dependencies() {
  precheck_dependencies >/dev/null 2>&1
}
run_test "precheck_dependencies" test_precheck_dependencies

# Test 11: precheck_environment
test_precheck_environment() {
  precheck_environment >/dev/null 2>&1
}
run_test "precheck_environment" test_precheck_environment

# Test 12: precheck_working_directory
test_precheck_working_directory() {
  precheck_working_directory >/dev/null 2>&1
}
run_test "precheck_working_directory" test_precheck_working_directory

# Test 13: precheck_fixtures
test_precheck_fixtures() {
  precheck_fixtures "./tests/fixtures" "./tests/expected/fixture-expectations.json" >/dev/null 2>&1
}
run_test "precheck_fixtures" test_precheck_fixtures

# ============================================================
# Summary
# ============================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Tests Run:    $TESTS_RUN"
echo "  Passed:       $TESTS_PASSED"
echo "  Failed:       $TESTS_FAILED"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
  echo "✓ All Phase 1 module tests passed!"
  echo ""
  exit 0
else
  echo "✗ $TESTS_FAILED test(s) failed"
  echo ""
  exit 1
fi

