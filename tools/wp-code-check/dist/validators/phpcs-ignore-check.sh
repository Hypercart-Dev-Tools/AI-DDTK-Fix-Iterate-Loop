#!/usr/bin/env bash
#
# PHPCS Ignore Comment Validator
#
# Checks if a matched line has a phpcs:ignore suppression comment
# on the same line or the line immediately before it.
#
# Exit codes:
#   0 - No suppression comment found (confirmed issue)
#   1 - Suppression comment found (false positive)
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
  echo "[DEBUG] phpcs-ignore-check: Checking $FILE:$LINE_NUMBER" >&2
  echo "[DEBUG] Line: $current_line" >&2
fi

# Skip comment lines (PHP comments: //, /*, */)
if echo "$current_line" | grep -qE '^\s*(//|/\*|\*)'; then
  [ "${NEOCHROME_DEBUG:-}" = "1" ] && echo "[DEBUG] Skipping comment line" >&2
  exit 1
fi

# Check for phpcs:ignore comment on the line before or same line
prev_line=$((LINE_NUMBER - 1))

# Ensure we don't go below line 1
if [ "$prev_line" -lt 1 ]; then
  prev_line=1
fi

# Read the previous line and current line
context=$(sed -n "${prev_line},${LINE_NUMBER}p" "$FILE" 2>/dev/null || true)

# Debug output for context
if [ "${NEOCHROME_DEBUG:-}" = "1" ]; then
  echo "[DEBUG] Context:" >&2
  echo "$context" | sed 's/^/[DEBUG]   /' >&2
fi

# Check if context contains phpcs:ignore comment
if echo "$context" | grep -q "phpcs:ignore"; then
  # Found suppression comment - this is a false positive
  [ "${NEOCHROME_DEBUG:-}" = "1" ] && echo "[DEBUG] Found phpcs:ignore - suppressing" >&2
  exit 1
fi

# Special case: Exclude gmdate() which is timezone-safe (always UTC)
# Only suppress if the actual function call is gmdate(), not if it's mentioned in a comment
# Remove comments first, then check for gmdate()
code_without_comments=$(echo "$current_line" | sed 's|//.*$||')
if echo "$code_without_comments" | grep -qE "gmdate[[:space:]]*\("; then
  # This is gmdate(), not date() - safe to use
  [ "${NEOCHROME_DEBUG:-}" = "1" ] && echo "[DEBUG] Found gmdate() - suppressing (timezone-safe)" >&2
  exit 1
fi

# No suppression comment found - this is a confirmed issue
[ "${NEOCHROME_DEBUG:-}" = "1" ] && echo "[DEBUG] No suppression comment - confirmed issue" >&2
exit 0

