#!/usr/bin/env bash
#
# WP Code Check - Test Utilities Library
# Version: 2.0.0
#
# Provides structured logging, assertions, and JSON parsing helpers.
# Designed for cross-platform compatibility (macOS, Ubuntu).
#

# ============================================================
# Log Levels
# ============================================================

# Log level priorities (lower number = higher priority)
declare -r LOG_LEVEL_ERROR=0
declare -r LOG_LEVEL_WARN=1
declare -r LOG_LEVEL_INFO=2
declare -r LOG_LEVEL_DEBUG=3
declare -r LOG_LEVEL_TRACE=4

# Default log level (can be overridden with LOG_LEVEL env var)
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Output format: "human" or "json"
LOG_FORMAT="${LOG_FORMAT:-human}"

# ============================================================
# Logging Functions
# ============================================================

# Get numeric priority for log level
_get_log_priority() {
  local level="$1"
  case "$level" in
    ERROR) echo "$LOG_LEVEL_ERROR" ;;
    WARN)  echo "$LOG_LEVEL_WARN" ;;
    INFO)  echo "$LOG_LEVEL_INFO" ;;
    DEBUG) echo "$LOG_LEVEL_DEBUG" ;;
    TRACE) echo "$LOG_LEVEL_TRACE" ;;
    *)     echo "$LOG_LEVEL_INFO" ;;
  esac
}

# Structured logging function
# Usage: log LEVEL "message"
log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")

  # Check if we should output this level
  local level_priority
  local current_priority
  level_priority=$(_get_log_priority "$level")
  current_priority=$(_get_log_priority "$LOG_LEVEL")

  if [ "$level_priority" -gt "$current_priority" ]; then
    return 0
  fi

  if [ "$LOG_FORMAT" = "json" ]; then
    # Structured JSON logging (great for CI log aggregation)
    # Escape quotes in message for valid JSON
    local escaped_message
    escaped_message=$(echo "$message" | sed 's/"/\\"/g')
    printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' \
      "$timestamp" "$level" "$escaped_message" >&2
  else
    # Human-readable with optional colors
    local color=""
    local reset=""

    if [ -z "${NO_COLOR:-}" ] && [ -t 2 ]; then
      case "$level" in
        ERROR) color='\033[0;31m' ;;  # Red
        WARN)  color='\033[1;33m' ;;  # Yellow
        INFO)  color='\033[0;32m' ;;  # Green
        DEBUG) color='\033[0;34m' ;;  # Blue
        TRACE) color='\033[0;90m' ;;  # Gray
      esac
      reset='\033[0m'
    fi

    printf "${color}[%s] %s${reset}\n" "$level" "$message" >&2
  fi
}

# ============================================================
# Assertion Helpers
# ============================================================

# Assert two values are equal
# Usage: assert_eq "name" "expected" "actual" ["context"]
assert_eq() {
  local name="$1"
  local expected="$2"
  local actual="$3"
  local context="${4:-}"

  if [ "$expected" = "$actual" ]; then
    log DEBUG "PASS: $name (expected=$expected, actual=$actual)"
    return 0
  else
    log ERROR "FAIL: $name"
    log ERROR "  Expected: $expected"
    log ERROR "  Actual:   $actual"
    [ -n "$context" ] && log ERROR "  Context:  $context"
    return 1
  fi
}

# Assert value is within range (inclusive)
# Usage: assert_range "name" "min" "max" "actual" ["context"]
assert_range() {
  local name="$1"
  local min="$2"
  local max="$3"
  local actual="$4"
  local context="${5:-}"

  if [ "$actual" -ge "$min" ] && [ "$actual" -le "$max" ]; then
    log DEBUG "PASS: $name (actual=$actual within [$min, $max])"
    return 0
  else
    log ERROR "FAIL: $name"
    log ERROR "  Expected: [$min, $max]"
    log ERROR "  Actual:   $actual"
    [ -n "$context" ] && log ERROR "  Context:  $context"
    return 1
  fi
}

# ============================================================
# JSON Parsing Helpers
# ============================================================

# Safe JSON extraction (single method, no fallbacks)
# Usage: parse_json "json_string" "jq_path" ["default_value"]
parse_json() {
  local json="$1"
  local path="$2"
  local default="${3:-0}"
  local result

  # Validate input is JSON
  if ! echo "$json" | jq empty 2>/dev/null; then
    log ERROR "parse_json: Input is not valid JSON"
    log DEBUG "parse_json: First 100 chars: ${json:0:100}"
    echo "$default"
    return 1
  fi

  result=$(echo "$json" | jq -r "$path // \"$default\"" 2>/dev/null)

  if [ -z "$result" ] || [ "$result" = "null" ]; then
    echo "$default"
  else
    echo "$result"
  fi
}

# Validate JSON string
# Usage: validate_json "json_string"
validate_json() {
  local json="$1"

  if echo "$json" | jq empty 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Strip ANSI color codes from text
# Usage: strip_ansi "text"
strip_ansi() {
  local text="$1"

  # Use perl for reliable ANSI stripping (works on macOS and Linux)
  echo "$text" | perl -pe 's/\e\[[0-9;]*[mGKH]//g; s/\r//g' 2>/dev/null || echo "$text"
}

