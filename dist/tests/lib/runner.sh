#!/usr/bin/env bash
#
# WP Code Check - Test Runner Library
# Version: 2.0.0
#
# Executes individual fixture tests and validates results.
# Designed for cross-platform compatibility (macOS, Ubuntu).
#

# ============================================================
# Test Execution
# ============================================================

# Run a single fixture test
# Usage: run_single_test "fixture_path" "expected_errors" "expected_warnings_min" "expected_warnings_max"
# Returns: 0 = pass, 1 = fail
run_single_test() {
  local fixture_path="$1"
  local expected_errors="$2"
  local expected_warnings_min="$3"
  local expected_warnings_max="$4"
  local fixture_name
  fixture_name=$(basename "$fixture_path")

  log INFO "Testing: $fixture_name"
  log DEBUG "Expected: errors=$expected_errors, warnings=$expected_warnings_min-$expected_warnings_max"

  # Create temp file for output capture
  local tmp_output
  tmp_output=$(mktemp)
  trap "rm -f '$tmp_output'" RETURN

  # Execute scanner with EXPLICIT format
  # - --format json: Explicit contract, not relying on default
  # - --no-log: Suppress log file creation
  # - Capture ONLY stdout (JSON), discard stderr (pattern library manager noise)
  log DEBUG "Executing: ./bin/check-performance.sh --paths \"$fixture_path\" --format json --no-log"

  # Run scanner directly (not through bash -c to avoid quoting issues)
  ./bin/check-performance.sh --paths "$fixture_path" --format json --no-log > "$tmp_output" 2>/dev/null
  local exit_code=$?

  log DEBUG "Scanner exit code: $exit_code"

  local output_size
  output_size=$(wc -c < "$tmp_output" | tr -d ' ')
  log DEBUG "Output size: $output_size bytes"

  # Read and clean output (strip any ANSI codes that leaked through)
  local raw_output
  raw_output=$(cat "$tmp_output")

  local clean_output
  clean_output=$(strip_ansi "$raw_output")

  log DEBUG "First 200 chars of raw output: ${clean_output:0:200}"

  # WORKAROUND: Scanner pollutes stdout with pattern library manager output
  # jq can parse JSON even with leading garbage, so let's use that
  # First, try to parse as-is
  if ! validate_json "$clean_output"; then
    log DEBUG "Output has non-JSON content, attempting to extract JSON with jq"

    # Try to extract JSON by finding the first { and parsing from there
    local json_start
    json_start=$(echo "$clean_output" | grep -n '^{' | head -1 | cut -d: -f1)

    if [ -n "$json_start" ]; then
      clean_output=$(echo "$clean_output" | tail -n +$json_start)
      log DEBUG "Extracted JSON starting from line $json_start"
    else
      log ERROR "Could not find JSON start marker in output"
      log ERROR "First 200 chars: ${clean_output:0:200}"
      return 1
    fi

    # Validate again
    if ! validate_json "$clean_output"; then
      log ERROR "Extracted output is still not valid JSON"
      log ERROR "First 200 chars: ${clean_output:0:200}"
      return 1
    fi
  fi

  log DEBUG "Output is valid JSON, parsing with jq"

  # Extract counts using parse_json helper
  local actual_errors
  local actual_warnings
  actual_errors=$(parse_json "$clean_output" '.summary.total_errors')
  actual_warnings=$(parse_json "$clean_output" '.summary.total_warnings')

  log DEBUG "Parsed: errors=$actual_errors, warnings=$actual_warnings"

  # Validate counts
  local errors_ok=false
  local warnings_ok=false

  if assert_eq "errors" "$expected_errors" "$actual_errors" "$fixture_name" 2>/dev/null; then
    errors_ok=true
  fi

  if assert_range "warnings" "$expected_warnings_min" "$expected_warnings_max" "$actual_warnings" "$fixture_name" 2>/dev/null; then
    warnings_ok=true
  fi

  if [ "$errors_ok" = true ] && [ "$warnings_ok" = true ]; then
    log INFO "✓ PASS: $fixture_name"
    return 0
  else
    log ERROR "✗ FAIL: $fixture_name"
    [ "$errors_ok" = false ] && \
      log ERROR "  Errors: expected $expected_errors, got $actual_errors"
    [ "$warnings_ok" = false ] && \
      log ERROR "  Warnings: expected $expected_warnings_min-$expected_warnings_max, got $actual_warnings"
    return 1
  fi
}

# ============================================================
# Batch Test Execution
# ============================================================

# Run all fixtures from expectations file
# Usage: run_all_tests "fixtures_dir" "expectations_file"
# Returns: JSON string with results: {"total":N,"passed":N,"failed":N}
run_all_tests() {
  local fixtures_dir="$1"
  local expectations_file="$2"

  local total=0
  local passed=0
  local failed=0

  log INFO "Running all fixture tests..."
  log INFO ""

  # Iterate through expectations file
  while IFS= read -r fixture; do
    # Skip meta key
    [ "$fixture" = "_meta" ] && continue

    local expected_errors
    local expected_warnings_min
    local expected_warnings_max

    expected_errors=$(jq -r ".[\"$fixture\"].errors" "$expectations_file")
    expected_warnings_min=$(jq -r ".[\"$fixture\"].warnings.min" "$expectations_file")
    expected_warnings_max=$(jq -r ".[\"$fixture\"].warnings.max" "$expectations_file")

    ((total++))

    if run_single_test "$fixtures_dir/$fixture" \
        "$expected_errors" "$expected_warnings_min" "$expected_warnings_max"; then
      ((passed++))
    else
      ((failed++))
    fi

    log INFO ""  # Blank line between tests

  done < <(jq -r 'keys[]' "$expectations_file")

  # Return results as JSON for structured reporting
  printf '{"total":%d,"passed":%d,"failed":%d}' "$total" "$passed" "$failed"

  [ "$failed" -eq 0 ]
}

