#!/usr/bin/env bash
#
# False Positive Filters Library
# Version: 1.3.0
#
# Shared library for detecting and filtering false positive patterns
# in WordPress code scanning.
#
# This library provides heuristic functions to identify code patterns
# that should not be flagged as violations (comments, configuration, etc.)
#
# Phase 2.1 additions:
# - Function scope detection (get_function_scope_range)
# - Function-scoped guard detection
# - Basic taint propagation for sanitizers
#
# Usage:
#   source "path/to/false-positive-filters.sh"
#   if is_line_in_comment "$file" "$line_num"; then
#     # Skip this finding
#   fi

# ============================================================
# COMMENT DETECTION
# ============================================================

# Check if a line is inside a comment or docblock
#
# This function uses multiple heuristics to detect if a line is part of
# a comment rather than executable code:
# 1. Line starts with comment markers (after whitespace)
# 2. Line is inside a multi-line comment block (/* ... */)
# 3. Inline comments on the same line
#
# Known limitations:
# - May be fooled by comment markers inside string literals
# - Backscan window is limited to 100 lines
# - Does not parse PHP syntax trees (intentionally lightweight)
#
# Returns: 0 (true) if line is in comment, 1 (false) otherwise
# Usage: is_line_in_comment "$file" "$line_number"
is_line_in_comment() {
  local file="$1"
  local line_num="$2"

  # Get the actual line content
  local line_content
  line_content=$(sed -n "${line_num}p" "$file" 2>/dev/null || echo "")

  # Check if line starts with comment markers (after whitespace)
  # Matches: // comment, /* comment, * comment (docblock line), */
  if echo "$line_content" | grep -qE "^[[:space:]]*(//|/\\*|\\*[^/]|\\*/|^\\*)"; then
    return 0  # true - is in comment
  fi

  # Check for inline block comment: code(); /* comment */ more_code();
  # If the line contains both /* and */ it's likely an inline comment
  # We still check if the match is INSIDE the comment portion
  if echo "$line_content" | grep -qE "/\\*.*\\*/"; then
    # Extract the position of /* and */ to see if our match is between them
    # This is a heuristic - we'll be conservative and mark as comment
    # TODO: More sophisticated inline comment detection
    return 0  # true - likely inline comment
  fi

  # Check if line is inside a multi-line comment block
  # Look backward to find /* without matching */
  # Increased from 50 to 100 lines to catch larger docblocks
  local check_start=$((line_num - 100))
  [ "$check_start" -lt 1 ] && check_start=1

  # Extract lines from check_start to current line
  local context
  context=$(sed -n "${check_start},${line_num}p" "$file" 2>/dev/null || echo "")

  # IMPROVEMENT: Filter out string literals before counting
  # Remove single-quoted strings: 'anything'
  # Remove double-quoted strings: "anything"
  # This prevents echo "/* not a comment */" from being counted
  local context_no_strings
  context_no_strings=$(echo "$context" | sed -E "s/'[^']*'//g" | sed -E 's/"[^"]*"//g')

  # Count /* and */ to determine if we're inside a block comment
  local open_count
  local close_count
  open_count=$(echo "$context_no_strings" | grep -c "/\\*" 2>/dev/null || echo "0")
  close_count=$(echo "$context_no_strings" | grep -c "\\*/" 2>/dev/null || echo "0")
  
  # Remove any whitespace/newlines
  open_count=$(echo "$open_count" | tr -d '[:space:]')
  close_count=$(echo "$close_count" | tr -d '[:space:]')

  # If more /* than */, we're inside a comment block
  if [ "$open_count" -gt "$close_count" ]; then
    return 0  # true - is in comment block
  fi

  return 1  # false - not in comment
}

# ============================================================
# HTML & REST CONFIGURATION DETECTION
# ============================================================

# Check if code is HTML form declaration or REST route config
#
# This function detects patterns that are configuration rather than
# executable code that accesses superglobals or makes HTTP requests.
#
# Patterns detected:
# 1. HTML form method attributes: <form method="POST">
# 2. REST route method configs: 'methods' => 'POST'
  # 3. JS/AJAX request descriptors in PHP views: jQuery $.ajax / jQuery.ajax POST blocks
#
# Returns: 0 (true) if it's a false positive pattern, 1 (false) otherwise
# Usage: is_html_or_rest_config "$code_line"
is_html_or_rest_config() {
  local code="$1"

  # Check for HTML form method attribute
  # Anchored pattern: <form ... method="POST"> or method='POST'
  # Case-insensitive to catch POST, post, Post, etc.
  if echo "$code" | grep -qiE "<form[^>]*\\bmethod\\s*=\\s*['\"]POST['\"]"; then
    return 0  # true - is HTML form
  fi

  # Also check for method attribute without <form on same line
  # (form tag might be on previous line)
  if echo "$code" | grep -qiE "^[[:space:]]*method\\s*=\\s*['\"]POST['\"]"; then
    return 0  # true - is HTML form attribute
  fi

  # Check for REST route methods config
  # Anchored pattern: 'methods' => 'POST' or "methods" => "POST"
  # Must have quotes around 'methods' key to avoid matching $methods variables
  if echo "$code" | grep -qiE "['\"]methods['\"][[:space:]]*=>.*POST"; then
    return 0  # true - is REST config
  fi

  # JS/AJAX-in-PHP: jQuery AJAX request descriptors inside PHP views
  # These are front-end HTTP requests, not PHP superglobal manipulation,
  # and should be handled by JS-facing rules instead of DSM.
  #
  # Heuristics:
  # - $.ajax({ ... }) or jQuery.ajax({ ... })
  # - $.post( ... ), $.get( ... )
  if echo "$code" | grep -qiE '\$\.(ajax|post|get)[[:space:]]*\(' || \
     echo "$code" | grep -qiE 'jQuery\.ajax[[:space:]]*\('; then
    return 0  # true - is JS/JQuery AJAX config
  fi

  return 1  # false - not a false positive pattern
}

# ============================================================
# FUNCTION SCOPE DETECTION (Phase 2.1)
# ============================================================

# Get the line range of the function containing a given line
#
# This function attempts to find the start and end of the PHP function
# that contains the specified line number. It uses brace counting to
# determine function boundaries.
#
# Algorithm:
# 1. Scan backward to find "function" keyword
# 2. Find opening brace after function declaration
# 3. Count braces forward to find matching closing brace
#
# Limitations:
# - Heuristic-based (not a full PHP parser)
# - May be confused by braces in strings or comments
# - Assumes standard formatting (function keyword on same/previous line as brace)
# - Does not handle anonymous functions perfectly
#
# Returns: "start_line end_line" or empty string if not in function
# Usage: scope=$(get_function_scope_range "$file" "$line_number")
get_function_scope_range() {
  local file="$1"
  local line_num="$2"
  local func_start
  local func_end
  local search_start
  local brace_line
  local brace_count
  local total_lines
  local i
  local line_content
  local open_count
  local close_count

  # Scan backward to find function declaration (max 100 lines)
  func_start=""
  search_start=$((line_num - 100))
  [ "$search_start" -lt 1 ] && search_start=1

  # Find the last "function" keyword before our line
  local func_line
  func_line=$(sed -n "${search_start},${line_num}p" "$file" | \
    grep -n "^[[:space:]]*function[[:space:]]" | \
    tail -1)

  if [ -z "$func_line" ]; then
    # Not in a function
    echo ""
    return
  fi

  # Extract line number (before the colon)
  func_start=$(echo "$func_line" | cut -d: -f1)

  # Convert relative line number to absolute
  func_start=$((search_start + func_start - 1))

  # Find opening brace (should be within 5 lines of function keyword)
  brace_line=""
  for i in $(seq "$func_start" $((func_start + 5))); do
    if sed -n "${i}p" "$file" | grep -q "{"; then
      brace_line="$i"
      break
    fi
  done

  if [ -z "$brace_line" ]; then
    # No opening brace found
    echo ""
    return
  fi

  # Count braces to find matching closing brace
  brace_count=0
  func_end=""
  total_lines=$(wc -l < "$file")

  for i in $(seq "$brace_line" "$total_lines"); do
    line_content=$(sed -n "${i}p" "$file")

    # Count opening braces
    open_count=$(echo "$line_content" | grep -o "{" | wc -l | tr -d ' ')
    brace_count=$((brace_count + open_count))

    # Count closing braces
    close_count=$(echo "$line_content" | grep -o "}" | wc -l | tr -d ' ')
    brace_count=$((brace_count - close_count))

    # If brace count returns to 0, we found the end
    if [ "$brace_count" -eq 0 ]; then
      func_end="$i"
      break
    fi
  done

  if [ -z "$func_end" ]; then
    # Couldn't find end of function
    echo ""
    return
  fi

  # Return range
  echo "$func_start $func_end"
}

# ============================================================
# GUARD DETECTION (Phase 2)
# ============================================================

# Detect security guards (nonce checks, capability checks) near a line
#
# Phase 2.1 Enhancement (Issue #1 fix):
# - Scoped to same function (uses get_function_scope_range)
# - Only detects guards BEFORE the access line (not after)
# - Prevents branch misattribution (guards in different if/else)
#
# This function scans backward from a given line to detect WordPress
# security guards that protect superglobal access:
# - Nonce verification: wp_verify_nonce, check_ajax_referer, check_admin_referer
# - Capability checks: current_user_can
#
# Note: user_can() is NOT detected (Phase 2.1 Issue #4 fix)
# Reason: user_can($user_id, 'cap') checks OTHER users' capabilities,
# not access control for current request. It's often used for display logic
# or checking permissions of arbitrary users, not as a guard for the current
# user's access. Detecting it creates false confidence (noise).
#
# Returns: Space-separated list of detected guards (empty if none)
# Usage: guards=$(detect_guards "$file" "$line_number")
detect_guards() {
  local file="$1"
  local line_num="$2"

  local guards=""
  local start_line
  local func_scope

  # PHASE 2.1: Get function scope to limit search range
  func_scope=$(get_function_scope_range "$file" "$line_num")

  if [ -z "$func_scope" ]; then
    # Not in a function - fall back to window-based search
    # (for top-level code, though this is rare in WordPress)
    start_line=$((line_num - 20))
    [ "$start_line" -lt 1 ] && start_line=1
  else
    # In a function - only search within function scope
    # func_scope is "start end", extract start
    start_line=$(echo "$func_scope" | awk '{print $1}')

    # Safety check: ensure start_line is a valid integer
    if ! [[ "$start_line" =~ ^[0-9]+$ ]]; then
      # Fallback to window-based search if parsing failed
      start_line=$((line_num - 20))
      [ "$start_line" -lt 1 ] && start_line=1
    fi
  fi

  # PHASE 2.1: Scan BEFORE or ON the access line
  # Guards after access are too late to protect it
  end_line=$line_num

  if [ "$end_line" -lt "$start_line" ]; then
    # Access is at the very start of function - no guards possible
    echo ""
    return
  fi

  # Get context (only lines BEFORE access)
  context=$(sed -n "${start_line},${end_line}p" "$file" 2>/dev/null || echo "")

  # Detect nonce checks
  if echo "$context" | grep -qE "wp_verify_nonce[[:space:]]*\\("; then
    guards="${guards}wp_verify_nonce "
  fi

  if echo "$context" | grep -qE "check_ajax_referer[[:space:]]*\\("; then
    guards="${guards}check_ajax_referer "
  fi

  if echo "$context" | grep -qE "check_admin_referer[[:space:]]*\\("; then
    guards="${guards}check_admin_referer "
  fi

  # Detect capability checks (current_user_can only)
  if echo "$context" | grep -qE "current_user_can[[:space:]]*\\("; then
    guards="${guards}current_user_can "
  fi

  # Detect admin gating (weak guard)
  if echo "$context" | grep -qE "is_admin[[:space:]]*\\("; then
    guards="${guards}is_admin "
  fi

  # Note: user_can() deliberately excluded (see function header comment)

  # Trim trailing space
  guards=$(echo "$guards" | sed 's/[[:space:]]*$//')

  echo "$guards"
}

# ============================================================
# SANITIZER DETECTION (Phase 2)
# ============================================================

# Detect sanitizers wrapping superglobal access
#
# This function checks if a code line contains WordPress sanitization
# functions wrapping superglobal reads ($_GET, $_POST, $_REQUEST, $_COOKIE).
#
# Common sanitizers detected:
# - sanitize_text_field, sanitize_email, sanitize_key, sanitize_url
# - esc_url_raw, esc_url, esc_html, esc_attr
# - absint, intval, floatval
# - wp_unslash, stripslashes_deep
# - wc_clean (WooCommerce)
#
# Returns: Space-separated list of detected sanitizers (empty if none)
# Usage: sanitizers=$(detect_sanitizers "$code_line")
detect_sanitizers() {
  local code="$1"
  local sanitizers=""

  # Check if code contains superglobal access
  if ! echo "$code" | grep -qE '\$_(GET|POST|REQUEST|COOKIE)\['; then
    # No superglobal access, return empty
    echo ""
    return
  fi

  # Detect sanitize_* functions
  if echo "$code" | grep -qE "sanitize_text_field[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}sanitize_text_field "
  fi

  if echo "$code" | grep -qE "sanitize_email[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}sanitize_email "
  fi

  if echo "$code" | grep -qE "sanitize_key[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}sanitize_key "
  fi

  if echo "$code" | grep -qE "sanitize_url[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}sanitize_url "
  fi

  # Detect esc_* functions
  if echo "$code" | grep -qE "esc_url_raw[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}esc_url_raw "
  fi

  if echo "$code" | grep -qE "esc_url[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}esc_url "
  fi

  if echo "$code" | grep -qE "esc_html[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}esc_html "
  fi

  if echo "$code" | grep -qE "esc_attr[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}esc_attr "
  fi

  # Detect type casters
  if echo "$code" | grep -qE "absint[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}absint "
  fi

  if echo "$code" | grep -qE "intval[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}intval "
  fi

  if echo "$code" | grep -qE "floatval[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}floatval "
  fi

  # Detect wp_unslash and stripslashes
  if echo "$code" | grep -qE "wp_unslash[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}wp_unslash "
  fi

  if echo "$code" | grep -qE "stripslashes_deep[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}stripslashes_deep "
  fi

  # Detect WooCommerce sanitizer
  if echo "$code" | grep -qE "wc_clean[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)\\["; then
    sanitizers="${sanitizers}wc_clean "
  fi

  # Trim trailing space
  sanitizers=$(echo "$sanitizers" | sed 's/[[:space:]]*$//')

  echo "$sanitizers"
}

# Detect sanitizers applied in the same line as a superglobal write
#
# For DSM (direct superglobal manipulation) we treat write-side
# sanitization as a local signal only. Rather than introducing a new
# pattern set, we reuse the same heuristics as detect_sanitizers(),
# but keep this helper separate so DSM call sites stay self-documenting.
#
# Returns: Space-separated list of detected sanitizers (empty if none)
detect_write_sanitizers() {
  local code="$1"

  # Reuse existing read-side sanitizer heuristics; DSM only cares
  # about the immediate write context, so we stay line-local here.
  detect_sanitizers "$code"
}

# Check if a variable was sanitized earlier in the function
#
# Phase 2.1 Enhancement (Issue #3 fix):
# Implements basic taint propagation to track sanitized variables.
#
# This function checks if a variable (e.g., $name, $email) was assigned
# a sanitized value earlier in the same function. It detects patterns like:
#   $name = sanitize_text_field($_POST['name']);
#   $data = wp_unslash($_GET['data']);
#
# Then later uses of $name or $data are considered sanitized.
#
# Limitations:
# - Only tracks 1-step assignments (doesn't follow $a = $b; $c = $a;)
# - Function-scoped only (doesn't track across functions)
# - Doesn't handle array elements ($data['key'])
# - Doesn't handle reassignments that remove sanitization
#
# Returns: Space-separated list of sanitizers used (empty if not sanitized)
# Usage: sanitizers=$(is_variable_sanitized "$file" "$line_num" "$variable_name")
is_variable_sanitized() {
  local file="$1"
  local line_num="$2"
  local var_name="$3"  # e.g., "name" (without $)
  local func_scope
  local start_line
  local end_line

  # Get function scope
  func_scope=$(get_function_scope_range "$file" "$line_num")

  if [ -z "$func_scope" ]; then
    # Not in a function - can't track
    echo ""
    return
  fi

  # func_scope is "start end", extract start
  start_line=$(echo "$func_scope" | awk '{print $1}')

  # Safety check: ensure start_line is a valid integer
  if ! [[ "$start_line" =~ ^[0-9]+$ ]]; then
    # Can't parse function scope - bail out
    echo ""
    return
  fi

  # Only search BEFORE current line (not after)
  end_line=$((line_num - 1))

  if [ "$end_line" -lt "$start_line" ]; then
    # At start of function - no prior assignments
    echo ""
    return
  fi

  # Get context (lines before current line in same function)
  context=$(sed -n "${start_line},${end_line}p" "$file" 2>/dev/null || echo "")

  # Look for assignment pattern: $var_name = sanitizer(...$_GET/POST/REQUEST/COOKIE...)
  # Pattern: \$var_name\s*=\s*sanitizer_function(...$_...)

  sanitizers=""

  # Check each sanitizer type
  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*sanitize_text_field[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}sanitize_text_field "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*sanitize_email[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}sanitize_email "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*sanitize_key[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}sanitize_key "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*sanitize_url[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}sanitize_url "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*esc_url_raw[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}esc_url_raw "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*esc_url[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}esc_url "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*esc_html[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}esc_html "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*esc_attr[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}esc_attr "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*absint[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}absint "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*intval[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}intval "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*floatval[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}floatval "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*wp_unslash[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}wp_unslash "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*stripslashes_deep[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}stripslashes_deep "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*wc_clean[[:space:]]*\\([^)]*\\\$_(GET|POST|REQUEST|COOKIE)"; then
    sanitizers="${sanitizers}wc_clean "
  fi

  # Also check for two-step sanitization: $var = $_POST['x']; $var = sanitize($var);
  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*sanitize_text_field[[:space:]]*\\([[:space:]]*\\\$${var_name}"; then
    sanitizers="${sanitizers}sanitize_text_field "
  fi

  if echo "$context" | grep -qE "\\\$${var_name}[[:space:]]*=[[:space:]]*sanitize_email[[:space:]]*\\([[:space:]]*\\\$${var_name}"; then
    sanitizers="${sanitizers}sanitize_email "
  fi

  # Trim trailing space
  sanitizers=$(echo "$sanitizers" | sed 's/[[:space:]]*$//')

  echo "$sanitizers"
}

# ============================================================
# SQL SAFETY DETECTION (Phase 2)
# ============================================================

# Detect if SQL query is a safe literal vs potentially tainted
#
# This function analyzes SQL code to determine if it's:
# 1. A literal string with only safe identifiers ($wpdb->prefix, $wpdb->options, etc.)
# 2. Concatenated with user input (superglobals, variables)
#
# Safe patterns:
# - "SELECT * FROM {$wpdb->posts} WHERE post_type = 'page'"
# - "DELETE FROM {$wpdb->options} WHERE option_name = 'my_option'"
#
# Unsafe patterns:
# - "SELECT * FROM {$wpdb->posts} WHERE ID = " . $_GET['id']
# - "SELECT * FROM {$wpdb->posts} WHERE title LIKE '%" . $search . "%'"
#
# Returns: "safe" or "unsafe"
# Usage: safety=$(detect_sql_safety "$code_line")
detect_sql_safety() {
  local code="$1"

  # Check for superglobal concatenation (definitely unsafe)
  if echo "$code" | grep -qE '\$_(GET|POST|REQUEST|COOKIE)\['; then
    echo "unsafe"
    return
  fi

  # Check for string concatenation with variables (potentially unsafe)
  # Pattern: . $var or . "$var" or . '$var'
  if echo "$code" | grep -qE '\.[[:space:]]*\$[a-zA-Z_]'; then
    # Check if it's ONLY concatenating safe wpdb identifiers
    # Safe: . $wpdb->prefix or . $wpdb->posts or {$wpdb->options}
    if echo "$code" | grep -qE '\.[[:space:]]*\$wpdb->(prefix|posts|postmeta|users|usermeta|options|terms|term_taxonomy|term_relationships|comments|commentmeta|links)'; then
      # Still check if there are OTHER variables being concatenated
      # Remove wpdb identifiers and check if any $ remains
      local code_no_wpdb
      code_no_wpdb=$(echo "$code" | sed -E 's/\$wpdb->(prefix|posts|postmeta|users|usermeta|options|terms|term_taxonomy|term_relationships|comments|commentmeta|links)//g')

      if echo "$code_no_wpdb" | grep -qE '\.[[:space:]]*\$[a-zA-Z_]'; then
        # Other variables found - unsafe
        echo "unsafe"
        return
      fi
    else
      # Concatenating non-wpdb variables - unsafe
      echo "unsafe"
      return
    fi
  fi

  # Check for variable interpolation in double-quoted strings
  # Safe: "{$wpdb->posts}"
  # Unsafe: "$user_input" or "${search_term}"
  if echo "$code" | grep -qE '"[^"]*\$[a-zA-Z_]'; then
    # Check if it's ONLY wpdb identifiers
    local interpolated_vars
    interpolated_vars=$(echo "$code" | grep -oE '\$[a-zA-Z_][a-zA-Z0-9_]*(->[a-zA-Z_][a-zA-Z0-9_]*)?' | grep -v '\$wpdb->' || true)

    if [ -n "$interpolated_vars" ]; then
      # Non-wpdb variables interpolated - unsafe
      echo "unsafe"
      return
    fi
  fi

  # If we got here, it's likely a safe literal query
  echo "safe"
}

# ============================================================
# LIBRARY METADATA
# ============================================================

# Export library version for debugging
FALSE_POSITIVE_FILTERS_VERSION="1.2.0"
