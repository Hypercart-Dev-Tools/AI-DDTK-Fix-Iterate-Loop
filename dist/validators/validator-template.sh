#!/usr/bin/env bash
#
# Validator Template
# 
# This is a template for creating new scripted validators.
# Copy this file and modify the validation logic section.
#
# Exit codes:
#   0 - Confirmed issue (real violation)
#   1 - False positive (suppress finding)
#   2 - Needs manual review (flag as warning)
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
CONTEXT_LINES="${4:-10}"  # Default to 10 lines of context

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

# Validate context lines is numeric
if ! [[ "$CONTEXT_LINES" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Invalid context_lines: $CONTEXT_LINES" >&2
  exit 1
fi

# ============================================================================
# Validation Logic (CUSTOMIZE THIS SECTION)
# ============================================================================

# Example: Check if there's a suppression comment on the previous line
prev_line=$((LINE_NUMBER - 1))

# Ensure we don't go below line 1
if [ "$prev_line" -lt 1 ]; then
  prev_line=1
fi

# Read the previous line and current line
context=$(sed -n "${prev_line},${LINE_NUMBER}p" "$FILE" 2>/dev/null || true)

# Debug output (optional - remove in production)
if [ "${NEOCHROME_DEBUG:-}" = "1" ]; then
  echo "[DEBUG] Validator: $(basename "$0")" >&2
  echo "[DEBUG] File: $FILE" >&2
  echo "[DEBUG] Line: $LINE_NUMBER" >&2
  echo "[DEBUG] Code: $MATCHED_CODE" >&2
  echo "[DEBUG] Context lines: $CONTEXT_LINES" >&2
  echo "[DEBUG] Context:" >&2
  echo "$context" | sed 's/^/[DEBUG]   /' >&2
fi

# Example validation: Check for suppression comment
if echo "$context" | grep -q "phpcs:ignore"; then
  # Found suppression comment - this is a false positive
  [ "${NEOCHROME_DEBUG:-}" = "1" ] && echo "[DEBUG] Found suppression comment - suppressing" >&2
  exit 1
fi

# Example validation: Check for specific pattern in context
if echo "$context" | grep -q "some_safe_pattern"; then
  # Found safe pattern - this is a false positive
  [ "${NEOCHROME_DEBUG:-}" = "1" ] && echo "[DEBUG] Found safe pattern - suppressing" >&2
  exit 1
fi

# If we get here, it's a confirmed issue
[ "${NEOCHROME_DEBUG:-}" = "1" ] && echo "[DEBUG] Confirmed issue" >&2
exit 0

# ============================================================================
# Alternative: Exit 2 for "needs manual review"
# ============================================================================

# Uncomment this section if you want to flag uncertain cases for review:
#
# if echo "$context" | grep -q "uncertain_pattern"; then
#   echo "[REVIEW] This finding needs manual inspection" >&2
#   exit 2
# fi

