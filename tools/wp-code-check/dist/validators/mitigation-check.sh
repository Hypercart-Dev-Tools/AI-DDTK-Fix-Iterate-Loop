#!/usr/bin/env bash
#
# Mitigation Detection Validator
# Checks for mitigating factors that reduce the severity of a finding
#
# Usage: mitigation-check.sh <file> <line_number> [context_lines]
#
# Exit codes:
#   0 = No mitigations found (full severity)
#   1 = Mitigations found (reduced severity)
#   2 = Error (invalid input)
#
# Output format (when mitigations found):
#   Prints comma-separated list of mitigations to stdout
#   Example: "caching,pagination,guard"
#
# Detects:
#   - Caching: get_transient, wp_cache_get, update_meta_cache
#   - Pagination: LIMIT, per_page, posts_per_page, number
#   - Guards: if statements, early returns, capability checks
#   - Rate limiting: wp_schedule_event, transient-based throttling

FILE="$1"
LINE_NUMBER="$2"
CONTEXT_LINES="${3:-20}"

# Validate inputs
if [ -z "$FILE" ] || [ -z "$LINE_NUMBER" ]; then
    echo "Error: Missing required arguments" >&2
    echo "Usage: $0 <file> <line_number> [context_lines]" >&2
    exit 2
fi

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE" >&2
    exit 2
fi

if ! [[ "$LINE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid line number: $LINE_NUMBER" >&2
    exit 2
fi

# Calculate context window (check before and after)
start_line=$((LINE_NUMBER - CONTEXT_LINES))
[ "$start_line" -lt 1 ] && start_line=1
end_line=$((LINE_NUMBER + CONTEXT_LINES))

# Extract context
context=$(sed -n "${start_line},${end_line}p" "$FILE" 2>/dev/null || true)

if [ -z "$context" ]; then
    echo "Error: Could not extract context from file" >&2
    exit 2
fi

# Detect mitigations
mitigations=()

# 1. Caching detection
if echo "$context" | grep -qiE "get_transient|set_transient|wp_cache_get|wp_cache_set|update_meta_cache|update_postmeta_cache|wp_cache_add"; then
    mitigations+=("caching")
fi

# 2. Pagination detection
if echo "$context" | grep -qiE "LIMIT[[:space:]]+[0-9]|'per_page'|\"per_page\"|'posts_per_page'|\"posts_per_page\"|'number'[[:space:]]*=>|\"number\"[[:space:]]*=>"; then
    mitigations+=("pagination")
fi

# 3. Guard detection (conditional checks)
if echo "$context" | grep -qiE "if[[:space:]]*\(|return[[:space:]]+false|return[[:space:]]+null|wp_die|exit"; then
    mitigations+=("conditional guard")
fi

# 4. Capability check detection
if echo "$context" | grep -qiE "current_user_can|user_can|is_admin|is_user_logged_in"; then
    mitigations+=("capability check")
fi

# 5. Rate limiting detection
if echo "$context" | grep -qiE "wp_schedule_event|wp_schedule_single_event|set_transient.*throttle|set_transient.*rate"; then
    mitigations+=("rate limiting")
fi

# 6. Hard cap detection (min/max functions)
if echo "$context" | grep -qiE "min[[:space:]]*\(|max[[:space:]]*\(|array_slice.*[0-9]"; then
    mitigations+=("hard cap")
fi

# Return results
if [ ${#mitigations[@]} -eq 0 ]; then
    # No mitigations found
    exit 0
else
    # Mitigations found - print comma-separated list
    IFS=','
    echo "${mitigations[*]}"
    exit 1
fi

