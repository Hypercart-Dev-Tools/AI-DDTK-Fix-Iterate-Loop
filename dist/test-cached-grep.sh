#!/usr/bin/env bash
# Test the cached_grep function

cached_grep() {
  local grep_args=()
  local pattern=""

  # Parse arguments to extract pattern (last arg) and options
  while [ $# -gt 0 ]; do
    if [ $# -eq 1 ]; then
      # Last argument is the pattern
      pattern="$1"
      shift
    else
      # All other arguments are grep options
      grep_args+=("$1")
      shift
    fi
  done

  # If single file mode, just use regular grep
  if [ "$PHP_FILE_COUNT" -eq 1 ]; then
    grep -Hn "${grep_args[@]}" "$pattern" "$PHP_FILE_LIST" 2>/dev/null || true
  else
    # Use cached file list with xargs for parallel processing
    # -Hn adds filename and line number (like -rHn but without recursion)
    cat "$PHP_FILE_LIST" | xargs grep -Hn "${grep_args[@]}" "$pattern" 2>/dev/null || true
  fi
}

# Set up test environment
PATHS="../temp/framework"
PHP_FILE_LIST_CACHE=$(mktemp)
find "$PATHS" -name "*.php" -type f 2>/dev/null | grep -v "/vendor/" | grep -v "/node_modules/" > "$PHP_FILE_LIST_CACHE"
PHP_FILE_COUNT=$(wc -l < "$PHP_FILE_LIST_CACHE" | tr -d " ")
PHP_FILE_LIST="$PHP_FILE_LIST_CACHE"

echo "PHP_FILE_COUNT: $PHP_FILE_COUNT"
echo "PHP_FILE_LIST: $PHP_FILE_LIST"
echo ""

echo "Testing cached_grep with pattern 'function'..."
result=$(cached_grep --include="*.php" -E "function")
count=$(echo "$result" | grep -c . 2>/dev/null || echo "0")
echo "Found $count matches"
echo ""

echo "First 5 matches:"
echo "$result" | head -5

rm -f "$PHP_FILE_LIST_CACHE"

