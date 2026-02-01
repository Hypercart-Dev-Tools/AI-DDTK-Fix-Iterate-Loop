#!/usr/bin/env bash
#
# Validator: pre-get-posts-unbounded-check.sh
# Purpose: Check if file with pre_get_posts hook sets unbounded query parameters
# Usage: pre-get-posts-unbounded-check.sh <file> <line_number> <context_lines>
#
# Returns:
#   0 = Validation FAILED (unbounded query detected)
#   1 = Validation PASSED (no unbounded query)

set -euo pipefail

# Input parameters
FILE="${1:-}"
LINE_NUMBER="${2:-0}"
CONTEXT_LINES="${3:-50}"

# Validation
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
  echo "ERROR: File not provided or does not exist: $FILE" >&2
  exit 1
fi

# Check if file sets posts_per_page to -1 or nopaging to true
# Pattern 1: $query->set('posts_per_page', -1)
# Pattern 2: $query->set('nopaging', true)

if grep -q "set[[:space:]]*([[:space:]]*['\"]posts_per_page['\"][[:space:]]*,[[:space:]]*-1" "$FILE" 2>/dev/null; then
  # Found posts_per_page => -1
  exit 0
fi

if grep -q "set[[:space:]]*([[:space:]]*['\"]nopaging['\"][[:space:]]*,[[:space:]]*true" "$FILE" 2>/dev/null; then
  # Found nopaging => true
  exit 0
fi

# No unbounded query detected
exit 1

