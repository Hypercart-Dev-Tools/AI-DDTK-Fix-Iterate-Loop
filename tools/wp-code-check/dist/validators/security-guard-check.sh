#!/usr/bin/env bash
#
# Security Guard Detection Validator
# Checks for security guards (nonce verification, capability checks) in context
#
# Usage: security-guard-check.sh <file> <line_number> [context_lines]
#
# Exit codes:
#   0 = No guards found (full severity)
#   1 = Guards found (reduced severity)
#   2 = Error (invalid input)
#
# Output format (when guards found):
#   Prints comma-separated list of guards to stdout
#   Example: "nonce verification,capability check"
#
# Detects:
#   - Nonce verification: wp_verify_nonce, check_admin_referer, check_ajax_referer
#   - Capability checks: current_user_can, user_can, is_admin
#   - Input validation: sanitize_*, wp_unslash, esc_*
#   - CSRF protection: wp_nonce_field, wp_create_nonce

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

# Calculate context window (check before the line - guards usually come before risky code)
start_line=$((LINE_NUMBER - CONTEXT_LINES))
[ "$start_line" -lt 1 ] && start_line=1
end_line=$LINE_NUMBER

# Extract context
context=$(sed -n "${start_line},${end_line}p" "$FILE" 2>/dev/null || true)

if [ -z "$context" ]; then
    echo "Error: Could not extract context from file" >&2
    exit 2
fi

# Detect security guards
guards=()

# 1. Nonce verification
if echo "$context" | grep -qiE "wp_verify_nonce|check_admin_referer|check_ajax_referer"; then
    guards+=("nonce verification")
fi

# 2. Capability checks
if echo "$context" | grep -qiE "current_user_can|user_can|is_admin|is_super_admin"; then
    guards+=("capability check")
fi

# 3. Input sanitization
if echo "$context" | grep -qiE "sanitize_text_field|sanitize_email|sanitize_url|wp_unslash|absint|intval"; then
    guards+=("input sanitization")
fi

# 4. Early returns / validation
if echo "$context" | grep -qiE "if[[:space:]]*\(.*\)[[:space:]]*\{[[:space:]]*(return|wp_die|exit)"; then
    guards+=("validation guard")
fi

# 5. CSRF protection
if echo "$context" | grep -qiE "wp_nonce_field|wp_create_nonce|wp_nonce_url"; then
    guards+=("CSRF protection")
fi

# Return results
if [ ${#guards[@]} -eq 0 ]; then
    # No guards found
    exit 0
else
    # Guards found - print comma-separated list
    IFS=','
    echo "${guards[*]}"
    exit 1
fi

