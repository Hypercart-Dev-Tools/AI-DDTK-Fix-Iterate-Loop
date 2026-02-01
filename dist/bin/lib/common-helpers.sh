# shellcheck shell=bash
#!/usr/bin/env bash
#
# Neochrome WP Toolkit - Common Helper Functions
#
# Shared utility functions for bash-based tooling. Source this file rather
# than duplicating logic across scripts.

# Generate UTC timestamp for filenames (e.g., reports, logs)
# Usage: timestamp_filename
# Returns: 2025-12-30-164339-UTC
timestamp_filename() {
  date -u +"%Y-%m-%d-%H%M%S-UTC"
}

# Generate ISO 8601 UTC timestamp for JSON payloads
# Usage: timestamp_iso8601
# Returns: 2025-12-30T16:43:39Z
timestamp_iso8601() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Generate local timestamp with timezone for display/logs
# Usage: timestamp_local
# Returns: 2025-12-31 11:27:32 PST
timestamp_local() {
  date +"%Y-%m-%d %H:%M:%S %Z"
}

# ============================================================
# FILE PATH HANDLING HELPERS
# ============================================================
# These functions provide centralized, DRY-compliant handling of file paths
# with spaces, special characters, and Unicode. Always use these helpers
# instead of inline logic to ensure consistency and maintainability.
#
# Added: 2026-01-02 (v1.0.77)
# Fixes: File paths with spaces breaking loops, HTML link encoding issues

# Safely iterate over newline-separated file paths (handles spaces)
# Usage: safe_file_iterator "$FILES_LIST" | while IFS= read -r file; do ... done
# Returns: Stream of file paths, one per line
#
# SAFEGUARD: Always use this instead of "for file in $FILES" which breaks on spaces
# Example: safe_file_iterator "$AJAX_FILES" | while IFS= read -r file; do
safe_file_iterator() {
  local files="$1"
  if [ -n "$files" ]; then
    printf '%s\n' "$files"
  fi
}

# URL-encode a file path for file:// links (RFC 3986)
# Usage: url_encode_path "/path/with spaces/file.php"
# Returns: /path/with%20spaces/file.php
#
# SAFEGUARD: Always use this for file:// URLs instead of raw paths
# Example: encoded=$(url_encode_path "$file_path")
url_encode_path() {
  local path="$1"
  # Use jq's @uri filter for robust RFC 3986 encoding
  printf '%s' "$path" | jq -sRr @uri
}

# HTML-escape a string for safe display in HTML
# Usage: html_escape_string "Code with <tags> & \"quotes\""
# Returns: Code with &lt;tags&gt; &amp; &quot;quotes&quot;
#
# SAFEGUARD: Always use this for HTML output instead of raw strings
# Example: escaped=$(html_escape_string "$display_text")
html_escape_string() {
  local str="$1"
  # Escape HTML special characters (& must be first to avoid double-escaping)
  str="${str//&/&amp;}"
  str="${str//</&lt;}"
  str="${str//>/&gt;}"
  str="${str//\"/&quot;}"
  str="${str//\'/&#39;}"
  printf '%s' "$str"
}

# Create a clickable file:// link for HTML reports
# Usage: create_file_link "/path/to/file.php" "Optional Display Text"
# Returns: <a href="file:///path/to/file.php">Display Text</a>
#
# SAFEGUARD: Use this instead of manually constructing file:// links
# Example: link=$(create_file_link "$file_path")
create_file_link() {
  local file_path="$1"
  local display_text="${2:-$file_path}"  # Use file path as display if not provided

  local encoded_path=$(url_encode_path "$file_path")
  local escaped_text=$(html_escape_string "$display_text")

  printf '<a href="file://%s" style="color: #667eea; text-decoration: none;" title="Click to open file">%s</a>' \
    "$encoded_path" "$escaped_text"
}

# Create a clickable directory link for HTML reports
# Usage: create_directory_link "/path/to/directory" "Optional Display Text"
# Returns: <a href="file:///path/to/directory">Display Text</a>
#
# SAFEGUARD: Use this instead of manually constructing directory links
# Example: link=$(create_directory_link "$dir_path")
create_directory_link() {
  local dir_path="$1"
  local display_text="${2:-$dir_path}"

  local encoded_path=$(url_encode_path "$dir_path")
  local escaped_text=$(html_escape_string "$display_text")

  printf '<a href="file://%s" style="color: #fff; text-decoration: underline;" title="Click to open directory">%s</a>' \
    "$encoded_path" "$escaped_text"
}

# Validate that a file path exists and is readable
# Usage: if validate_file_path "$file"; then ... fi
# Returns: 0 if valid, 1 if invalid
#
# SAFEGUARD: Use this for consistent path validation
# Example: if validate_file_path "$file"; then process_file "$file"; fi
validate_file_path() {
  local file_path="$1"

  if [ -z "$file_path" ]; then
    return 1  # Empty path
  fi

  if [ ! -e "$file_path" ]; then
    return 1  # Path doesn't exist
  fi

  if [ ! -r "$file_path" ]; then
    return 1  # Path not readable
  fi

  return 0  # Valid
}
