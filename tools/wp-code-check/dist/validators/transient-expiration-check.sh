#!/usr/bin/env bash
#
# Transient Expiration Validator
#
# Validates that set_transient() calls include the expiration parameter.
# set_transient( $key, $value, $expiration ) requires 3 parameters (2 commas).
#
# Exit codes:
#   0 - Missing expiration parameter (confirmed issue)
#   1 - Has expiration parameter (false positive)
#

set -euo pipefail

# ============================================================================
# Input Validation
# ============================================================================

if [ $# -lt 3 ]; then
  echo "ERROR: Missing required arguments" >&2
  echo "Usage: $0 <file> <line_number> <matched_code> [context_lines]" >&2
  exit 1
fi

FILE="$1"
LINE_NUMBER="$2"
MATCHED_CODE="$3"
CONTEXT_LINES="${4:-10}"  # Not used, but accepted for interface compatibility

# Validate file exists and is readable
if [ ! -f "$FILE" ]; then
  echo "ERROR: File not found: $FILE" >&2
  exit 1
fi

if [ ! -r "$FILE" ]; then
  echo "ERROR: File not readable: $FILE" >&2
  exit 1
fi

# Validate line number is numeric
if ! [[ "$LINE_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Invalid line number: $LINE_NUMBER" >&2
  exit 1
fi

# ============================================================================
# Validation Logic
# ============================================================================

# Read the current line
current_line=$(sed -n "${LINE_NUMBER}p" "$FILE" 2>/dev/null || true)

# Debug output
if [ "${NEOCHROME_DEBUG:-}" = "1" ]; then
  echo "[DEBUG] transient-expiration-check: Checking $FILE:$LINE_NUMBER" >&2
  echo "[DEBUG] Line: $current_line" >&2
fi

# Count commas in the line
# set_transient( $key, $value, $expiration ) needs 2 commas minimum
comma_count=$(echo "$current_line" | tr -cd ',' | wc -c | tr -d ' ')

if [ "${NEOCHROME_DEBUG:-}" = "1" ]; then
  echo "[DEBUG] Comma count: $comma_count" >&2
fi

# If there are at least 2 commas, the expiration parameter is likely present
if [ "$comma_count" -ge 2 ]; then
  # Has expiration parameter - this is a false positive
  [ "${NEOCHROME_DEBUG:-}" = "1" ] && echo "[DEBUG] Found $comma_count commas - has expiration parameter" >&2
  exit 1
fi

# Less than 2 commas - missing expiration parameter
[ "${NEOCHROME_DEBUG:-}" = "1" ] && echo "[DEBUG] Only $comma_count comma(s) - missing expiration parameter" >&2
exit 0

