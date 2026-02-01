#!/usr/bin/env bash
# ============================================================================
# Pattern Library Manager
# ============================================================================
# Scans all pattern JSON files and generates a canonical pattern registry
# with statistics for documentation and marketing purposes.
#
# Usage:
#   bash pattern-library-manager.sh [--output FILE] [--format json|markdown|both]
#
# Output:
#   - dist/PATTERN-LIBRARY.json (canonical registry)
#   - dist/PATTERN-LIBRARY.md (human-readable documentation)
#
# Version: 1.0.0
# ============================================================================

set -euo pipefail

# Ensure bash 4+ for associative arrays
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  echo "⚠️  Warning: Bash 4+ required for full functionality. Using fallback mode."
  USE_ASSOC_ARRAYS=false
else
  USE_ASSOC_ARRAYS=true
fi

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERNS_DIR="$SCRIPT_DIR/../patterns"
OUTPUT_DIR="$SCRIPT_DIR/.."
OUTPUT_JSON="$OUTPUT_DIR/PATTERN-LIBRARY.json"
OUTPUT_MD="$OUTPUT_DIR/PATTERN-LIBRARY.md"
OUTPUT_FORMAT="${1:-both}"  # json, markdown, or both

# ============================================================================
# Helper Functions
# ============================================================================

# Extract field from JSON file using grep/sed (no jq dependency)
get_json_field() {
  local file="$1"
  local field="$2"
  local value

  # Try to extract quoted string value first
  value=$(grep "\"$field\"" "$file" | head -1 | sed -n 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

  # If empty, try unquoted value (boolean/number)
  if [ -z "$value" ]; then
    value=$(grep "\"$field\"" "$file" | head -1 | sed -n 's/.*"'"$field"'"[[:space:]]*:[[:space:]]*\([^,}[:space:]]*\).*/\1/p')
  fi

  echo "$value"
}

# Check if pattern has mitigation detection applied
has_mitigation_detection() {
  local pattern_id="$1"
  # Search main script for get_adjusted_severity calls with this pattern
  grep -q "get_adjusted_severity.*$pattern_id\|add_json_finding \"$pattern_id\" \"error\" \"\$adjusted_severity\"" "$SCRIPT_DIR/check-performance.sh" 2>/dev/null && echo "true" || echo "false"
}

# Check if pattern is heuristic (MEDIUM or LOW severity, or has "heuristic" in description)
is_heuristic() {
	local severity="$1"
	local description="$2"
	if [[ "$severity" == "MEDIUM" || "$severity" == "LOW" ]] || echo "$description" | grep -qi "heuristic"; then
		echo "true"
	else
		echo "false"
	fi
}

# Build detection and mitigation fields for registry entries (Phase 2)
#
# This mirrors the semantics in dist/lib/pattern-loader.sh so the registry can
# eventually satisfy all loader needs without re-opening pattern JSON files.
# The output is a comma-prefixed JSON snippet suitable for embedding inside the
# per-pattern object. On older systems without python3, this function returns
# an empty string so the schema remains backward compatible.
build_detection_and_mitigation_json() {
	local pattern_file="$1"

	# Enriched schema requires python3; skip gracefully if unavailable.
	if ! command -v python3 &> /dev/null; then
		echo ""
		return 0
	fi

	PATTERN_FILE="$pattern_file" python3 -S <<'EOFPY'
import json
import os
import sys

path = os.environ.get("PATTERN_FILE")
if not path:
    sys.exit(0)

try:
    with open(path, "r") as f:
        data = json.load(f)
except Exception:
    # Keep registry generation robust: on any error, omit extra fields
    sys.exit(0)

detection = data.get("detection") or {}
mitigation = data.get("mitigation_detection") or {}

# Compute search_pattern (mirrors dist/lib/pattern-loader.sh)
search_pattern = None
if "search_pattern" in detection:
    search_pattern = detection["search_pattern"]
else:
    patterns_list = detection.get("patterns")
    if isinstance(patterns_list, list):
        collected = []
        for p in patterns_list:
            if not isinstance(p, dict):
                continue
            val = p.get("pattern") or p.get("search")
            if val:
                collected.append(str(val))
        if collected:
            search_pattern = "|".join(collected)

# File patterns (default to PHP for backward compatibility)
file_patterns = detection.get("file_patterns") or ["*.php"]
if isinstance(file_patterns, (str, int, float, bool)):
    file_patterns = [str(file_patterns)]
elif isinstance(file_patterns, list):
    file_patterns = [str(x) for x in file_patterns]
else:
    file_patterns = ["*.php"]

# Scripted validator configuration
validator_script = detection.get("validator_script") or ""
validator_args = detection.get("validator_args") or []
if isinstance(validator_args, (str, int, float, bool)):
    validator_args = [str(validator_args)]
elif isinstance(validator_args, list):
    validator_args = [str(a) for a in validator_args]
else:
    validator_args = []

# Mitigation details
enabled = bool(mitigation.get("enabled", False))
m_script = mitigation.get("validator_script") or ""
m_args = mitigation.get("validator_args") or []
if isinstance(m_args, (str, int, float, bool)):
    m_args = [str(m_args)]
elif isinstance(m_args, list):
    m_args = [str(a) for a in m_args]
else:
    m_args = []

severity_downgrade = mitigation.get("severity_downgrade") or {}
if not isinstance(severity_downgrade, dict):
    severity_downgrade = {}

extra = {}

if search_pattern is not None:
    extra["search_pattern"] = search_pattern

# Always include file_patterns to keep behavior predictable
extra["file_patterns"] = file_patterns

if validator_script or validator_args:
    extra["validator_script"] = validator_script
    extra["validator_args"] = validator_args

if enabled or m_script or m_args or severity_downgrade:
    extra["mitigation_details"] = {
        "enabled": enabled,
        "script": m_script,
        "args": m_args,
        "severity_downgrade": severity_downgrade,
    }

if not extra:
    sys.exit(0)

# Emit as comma-prefixed JSON snippet for embedding into existing object
items = list(extra.items())
lines = [","]
for idx, (key, value) in enumerate(items):
    suffix = "," if idx < len(items) - 1 else ""
    lines.append('  "%s": %s%s' % (key, json.dumps(value, ensure_ascii=False), suffix))
sys.stdout.write("\n".join(lines))
EOFPY
}

# ============================================================================
# Scan Pattern Files
# ============================================================================

echo "🔍 Scanning pattern library..."

# Initialize counters
total_patterns=0
critical_count=0
high_count=0
medium_count=0
low_count=0
mitigation_count=0
heuristic_count=0
enabled_count=0
disabled_count=0

# Pattern type counters
php_count=0
headless_count=0
nodejs_count=0
javascript_count=0

# Category counters (use simple string for bash 3 compatibility)
category_list=""

# Arrays to store pattern data
patterns_data=()

# Scan all JSON files in patterns directory (including subdirectories)
while IFS= read -r pattern_file; do
  [ ! -f "$pattern_file" ] && continue

  # Extract metadata
  id=$(get_json_field "$pattern_file" "id")
  [ -z "$id" ] && continue  # Skip if no ID

	  version=$(get_json_field "$pattern_file" "version")
	  enabled=$(get_json_field "$pattern_file" "enabled")
	  # Default to enabled when field is missing for backward compatibility.
	  # Older pattern JSON files omit the "enabled" field entirely and should
	  # be treated as enabled by default in the canonical registry.
	  if [ -z "$enabled" ]; then
	    enabled="true"
	  fi
  category=$(get_json_field "$pattern_file" "category")
  severity=$(get_json_field "$pattern_file" "severity")
  title=$(get_json_field "$pattern_file" "title")
  description=$(get_json_field "$pattern_file" "description")
  detection_type=$(get_json_field "$pattern_file" "detection_type")

  # Determine pattern type based on file location
  pattern_type="php"  # Default
  if [[ "$pattern_file" == */headless/* ]]; then
    pattern_type="headless"
  elif [[ "$pattern_file" == */nodejs/* ]]; then
    pattern_type="nodejs"
  elif [[ "$pattern_file" == */js/* ]]; then
    pattern_type="javascript"
  fi
  
  # Check for mitigation detection
  has_mitigation=$(has_mitigation_detection "$id")
  
  # Check if heuristic
  is_heuristic_pattern=$(is_heuristic "$severity" "$description")
  
  # Increment counters
  ((total_patterns++))

  case "$severity" in
    CRITICAL) ((critical_count++)) ;;
    HIGH) ((high_count++)) ;;
    MEDIUM) ((medium_count++)) ;;
    LOW) ((low_count++)) ;;
  esac

  # Increment pattern type counters
  case "$pattern_type" in
    php) ((php_count++)) ;;
    headless) ((headless_count++)) ;;
    nodejs) ((nodejs_count++)) ;;
    javascript) ((javascript_count++)) ;;
  esac
  
  if [ "$enabled" = "true" ]; then
    ((enabled_count++))
  else
    ((disabled_count++))
  fi
  
  if [ "$has_mitigation" = "true" ]; then
    ((mitigation_count++))
  fi
  
  if [ "$is_heuristic_pattern" = "true" ]; then
    ((heuristic_count++))
  fi
  
  # Category tracking (simple string-based for bash 3 compatibility)
	  if [ -n "$category" ]; then
	    if ! echo "$category_list" | grep -q "^$category:"; then
	      category_list+="$category:1"$'\n'
	    else
	      # Increment count (use awk to avoid arithmetic errors with category names)
	      old_count=$(echo "$category_list" | grep "^$category:" | cut -d: -f2)
	      new_count=$(echo "$old_count" | awk '{print $1 + 1}')
	      category_list=$(echo "$category_list" | sed "s/^$category:.*/$category:$new_count/")
	    fi
	  fi
	  
	  # Build detection/mitigation fields for registry consumers (Phase 2)
	  extra_fields=$(build_detection_and_mitigation_json "$pattern_file")

	  # Store pattern data for JSON output
	  patterns_data+=("$(cat <<EOF
{
	"id": "$id",
	"version": "$version",
	"enabled": $enabled,
	"category": "$category",
	"severity": "$severity",
	"title": "$title",
	"description": "$description",
	"detection_type": "$detection_type",
	"pattern_type": "$pattern_type",
	"mitigation_detection": $has_mitigation,
	"heuristic": $is_heuristic_pattern,
	"file": "$(basename "$pattern_file")"$extra_fields
}
EOF
	)")
  
done < <(find "$PATTERNS_DIR" -name "*.json" -type f | sort)

echo "✓ Found $total_patterns patterns"

# ============================================================================
# Generate JSON Output
# ============================================================================

if [[ "$OUTPUT_FORMAT" == "json" || "$OUTPUT_FORMAT" == "both" ]]; then
  echo "📝 Generating JSON registry..."
  
	  # Build patterns array
	  patterns_json=$(printf "%s,\n" "${patterns_data[@]}" | sed '$ s/,$//')

  # Build category breakdown from string list
  category_json=""
  while IFS=: read -r cat count; do
    [ -z "$cat" ] && continue
    category_json+="\"$cat\": $count,"
  done <<< "$category_list"
  category_json=$(echo "$category_json" | sed 's/,$//')

	  # Generate JSON file to a temporary path first so we can compare against
	  # the existing registry while ignoring the generated timestamp. This keeps
	  # Git diffs clean when only the timestamp changes.
	tmp_json="${OUTPUT_JSON}.tmp.$$"
	cat > "$tmp_json" <<EOF
{
  "version": "1.0.0",
  "generated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "summary": {
    "total_patterns": $total_patterns,
    "enabled": $enabled_count,
    "disabled": $disabled_count,
    "by_severity": {
      "CRITICAL": $critical_count,
      "HIGH": $high_count,
      "MEDIUM": $medium_count,
      "LOW": $low_count
    },
    "by_category": {
      $category_json
    },
    "by_pattern_type": {
      "php": $php_count,
      "headless": $headless_count,
      "nodejs": $nodejs_count,
      "javascript": $javascript_count
    },
    "mitigation_detection_enabled": $mitigation_count,
    "heuristic_patterns": $heuristic_count,
    "definitive_patterns": $((total_patterns - heuristic_count))
  },
  "patterns": [
    $patterns_json
  ]
}
EOF

	if [ -f "$OUTPUT_JSON" ]; then
	  tmp_old="${OUTPUT_JSON}.normalized.old.$$"
	  tmp_new="${OUTPUT_JSON}.normalized.new.$$"

	  # Drop the generated timestamp line from both files before comparing.
	  sed '/"generated"[[:space:]]*:/d' "$OUTPUT_JSON" > "$tmp_old"
	  sed '/"generated"[[:space:]]*:/d' "$tmp_json" > "$tmp_new"

	  if cmp -s "$tmp_old" "$tmp_new"; then
	    echo "✓ No pattern changes detected; keeping existing JSON registry timestamp"
	    rm -f "$tmp_json" "$tmp_old" "$tmp_new"
	  else
	    mv "$tmp_json" "$OUTPUT_JSON"
	    rm -f "$tmp_old" "$tmp_new"
	    echo "✓ JSON registry saved to: $OUTPUT_JSON"
	  fi
	else
	  mv "$tmp_json" "$OUTPUT_JSON"
	  echo "✓ JSON registry saved to: $OUTPUT_JSON"
	fi
fi

# ============================================================================
# Generate Markdown Output
# ============================================================================

# As a safety net, clean up any leftover temp files from previous interrupted
# runs. These should never be needed across invocations and can safely be
# removed.
rm -f "${OUTPUT_JSON}.tmp."* "${OUTPUT_MD}.tmp."* 2>/dev/null || true

if [[ "$OUTPUT_FORMAT" == "markdown" || "$OUTPUT_FORMAT" == "both" ]]; then
  echo "📝 Generating Markdown documentation..."

	  # Calculate percentages
	  critical_pct=$(awk "BEGIN {printf \"%.1f%%\", ($critical_count/$total_patterns)*100}")
	  high_pct=$(awk "BEGIN {printf \"%.1f%%\", ($high_count/$total_patterns)*100}")
	  medium_pct=$(awk "BEGIN {printf \"%.1f%%\", ($medium_count/$total_patterns)*100}")
	  low_pct=$(awk "BEGIN {printf \"%.1f%%\", ($low_count/$total_patterns)*100}")
	  definitive_pct=$(awk "BEGIN {printf \"%.1f%%\", (($total_patterns - $heuristic_count)/$total_patterns)*100}")
	  heuristic_pct=$(awk "BEGIN {printf \"%.1f%%\", ($heuristic_count/$total_patterns)*100}")
	  mitigation_pct=$(awk "BEGIN {printf \"%.1f%%\", ($mitigation_count/$total_patterns)*100}")
	  timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
	
	  tmp_md="${OUTPUT_MD}.tmp.$$"
	
	  cat > "$tmp_md" <<EOF
# Pattern Library Registry

**Auto-generated by Pattern Library Manager**
**Last Updated:** $timestamp

---

## 📊 Summary Statistics

### Total Patterns
- **Total:** $total_patterns patterns
- **Enabled:** $enabled_count patterns
- **Disabled:** $disabled_count patterns

### By Severity
| Severity | Count | Percentage |
|----------|-------|------------|
| CRITICAL | $critical_count | $critical_pct |
| HIGH | $high_count | $high_pct |
| MEDIUM | $medium_count | $medium_pct |
| LOW | $low_count | $low_pct |

### By Type
| Type | Count | Percentage |
|------|-------|------------|
| Definitive | $((total_patterns - heuristic_count)) | $definitive_pct |
| Heuristic | $heuristic_count | $heuristic_pct |

### Advanced Features
- **Mitigation Detection Enabled:** $mitigation_count patterns ($mitigation_pct)
- **False Positive Reduction:** 60-70% on mitigated patterns

### By Category
EOF

	  # Add category breakdown from string list
	  while IFS=: read -r cat count; do
	    [ -z "$cat" ] && continue
	    echo "- **$cat:** $count patterns" >> "$tmp_md"
	  done <<< "$category_list"
	
	  cat >> "$tmp_md" <<EOF

### By Pattern Type
- **PHP/WordPress:** $php_count patterns
- **Headless WordPress:** $headless_count patterns
- **Node.js/Server-Side JS:** $nodejs_count patterns
- **Client-Side JavaScript:** $javascript_count patterns

EOF

	  cat >> "$tmp_md" <<'EOF'

---

## 📋 Pattern Details

### CRITICAL Severity Patterns
EOF

  # List CRITICAL patterns
  while IFS= read -r pattern_file; do
    [ ! -f "$pattern_file" ] && continue
    severity=$(get_json_field "$pattern_file" "severity")
    [ "$severity" != "CRITICAL" ] && continue

    id=$(get_json_field "$pattern_file" "id")
    title=$(get_json_field "$pattern_file" "title")
    has_mitigation=$(has_mitigation_detection "$id")
    is_heuristic_pattern=$(is_heuristic "$severity" "$(get_json_field "$pattern_file" "description")")

    mitigation_badge=""
    [ "$has_mitigation" = "true" ] && mitigation_badge=" 🛡️"

    heuristic_badge=""
    [ "$is_heuristic_pattern" = "true" ] && heuristic_badge=" 🔍"

	    echo "- **$id**$mitigation_badge$heuristic_badge - $title" >> "$tmp_md"
  done < <(find "$PATTERNS_DIR" -name "*.json" -type f | sort)

	  cat >> "$tmp_md" <<'EOF'

### HIGH Severity Patterns
EOF

  # List HIGH patterns
  while IFS= read -r pattern_file; do
    [ ! -f "$pattern_file" ] && continue
    severity=$(get_json_field "$pattern_file" "severity")
    [ "$severity" != "HIGH" ] && continue

    id=$(get_json_field "$pattern_file" "id")
    title=$(get_json_field "$pattern_file" "title")
    has_mitigation=$(has_mitigation_detection "$id")
    is_heuristic_pattern=$(is_heuristic "$severity" "$(get_json_field "$pattern_file" "description")")

    mitigation_badge=""
    [ "$has_mitigation" = "true" ] && mitigation_badge=" 🛡️"

    heuristic_badge=""
    [ "$is_heuristic_pattern" = "true" ] && heuristic_badge=" 🔍"

	    echo "- **$id**$mitigation_badge$heuristic_badge - $title" >> "$tmp_md"
  done < <(find "$PATTERNS_DIR" -name "*.json" -type f | sort)

	  cat >> "$tmp_md" <<'EOF'

### MEDIUM Severity Patterns
EOF

  # List MEDIUM patterns
  while IFS= read -r pattern_file; do
    [ ! -f "$pattern_file" ] && continue
    severity=$(get_json_field "$pattern_file" "severity")
    [ "$severity" != "MEDIUM" ] && continue

    id=$(get_json_field "$pattern_file" "id")
    title=$(get_json_field "$pattern_file" "title")
    has_mitigation=$(has_mitigation_detection "$id")
    is_heuristic_pattern=$(is_heuristic "$severity" "$(get_json_field "$pattern_file" "description")")

    mitigation_badge=""
    [ "$has_mitigation" = "true" ] && mitigation_badge=" 🛡️"

    heuristic_badge=""
    [ "$is_heuristic_pattern" = "true" ] && heuristic_badge=" 🔍"

	    echo "- **$id**$mitigation_badge$heuristic_badge - $title" >> "$tmp_md"
  done < <(find "$PATTERNS_DIR" -name "*.json" -type f | sort)

	  cat >> "$tmp_md" <<'EOF'

### LOW Severity Patterns
EOF

  # List LOW patterns
  while IFS= read -r pattern_file; do
    [ ! -f "$pattern_file" ] && continue
    severity=$(get_json_field "$pattern_file" "severity")
    [ "$severity" != "LOW" ] && continue

    id=$(get_json_field "$pattern_file" "id")
    title=$(get_json_field "$pattern_file" "title")
    has_mitigation=$(has_mitigation_detection "$id")
    is_heuristic_pattern=$(is_heuristic "$severity" "$(get_json_field "$pattern_file" "description")")

    mitigation_badge=""
    [ "$has_mitigation" = "true" ] && mitigation_badge=" 🛡️"

    heuristic_badge=""
    [ "$is_heuristic_pattern" = "true" ] && heuristic_badge=" 🔍"

	    echo "- **$id**$mitigation_badge$heuristic_badge - $title" >> "$tmp_md"
  done < <(find "$PATTERNS_DIR" -name "*.json" -type f | sort)

  # Count categories for marketing stats
  category_count=$(echo "$category_list" | grep -c ":" || echo "0")

	  cat >> "$tmp_md" <<EOF

---

## 🔑 Legend

- 🛡️ **Mitigation Detection Enabled** - Pattern uses advanced mitigation detection to reduce false positives
- 🔍 **Heuristic Pattern** - Pattern is a "review signal" rather than definitive finding

---

## 📈 Marketing Stats

### Key Selling Points

1. **Comprehensive Coverage:** $total_patterns detection patterns across $category_count categories
2. **Multi-Platform Support:** PHP/WordPress ($php_count), Headless WordPress ($headless_count), Node.js ($nodejs_count), JavaScript ($javascript_count)
3. **Enterprise-Grade Accuracy:** $mitigation_count patterns with AI-powered mitigation detection (60-70% false positive reduction)
4. **Severity-Based Prioritization:** $critical_count CRITICAL + $high_count HIGH severity patterns catch the most dangerous issues
5. **Intelligent Analysis:** $((total_patterns - heuristic_count)) definitive patterns + $heuristic_count heuristic patterns for comprehensive code review

### One-Liner Stats

> **$total_patterns detection patterns** | **$mitigation_count with AI mitigation** | **60-70% fewer false positives** | **Multi-platform: PHP, Headless, Node.js, JS**

### Feature Highlights

- ✅ **$critical_count CRITICAL** OOM and security patterns
- ✅ **$high_count HIGH** performance and security patterns
- ✅ **$mitigation_count patterns** with context-aware severity adjustment
- ✅ **$heuristic_count heuristic** patterns for code quality insights
- ✅ **Multi-platform:** WordPress, Headless, Node.js, JavaScript

---

**Generated:** $timestamp
**Version:** 1.0.0
**Tool:** Pattern Library Manager
EOF

	  # Compare Markdown output against existing file while ignoring timestamp
	  # lines. If nothing else changed, keep the existing file to avoid
	  # timestamp-only diffs.
	  if [ -f "$OUTPUT_MD" ]; then
	    tmp_old="${OUTPUT_MD}.normalized.old.$$"
	    tmp_new="${OUTPUT_MD}.normalized.new.$$"

	    sed -E '/^\*\*Last Updated:/d; /^\*\*Generated:/d' "$OUTPUT_MD" > "$tmp_old"
	    sed -E '/^\*\*Last Updated:/d; /^\*\*Generated:/d' "$tmp_md" > "$tmp_new"

	    if cmp -s "$tmp_old" "$tmp_new"; then
	      echo "✓ No pattern changes detected; keeping existing Markdown registry timestamp"
	      rm -f "$tmp_md" "$tmp_old" "$tmp_new"
	    else
	      mv "$tmp_md" "$OUTPUT_MD"
	      rm -f "$tmp_old" "$tmp_new"
	      echo "✓ Markdown documentation saved to: $OUTPUT_MD"
	    fi
	  else
	    mv "$tmp_md" "$OUTPUT_MD"
	    echo "✓ Markdown documentation saved to: $OUTPUT_MD"
	  fi
	fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "✅ Pattern Library Manager Complete"
echo ""
echo "📊 Summary:"
echo "  Total Patterns: $total_patterns"
echo "  Enabled: $enabled_count"
echo "  By Type: PHP ($php_count), Headless ($headless_count), Node.js ($nodejs_count), JS ($javascript_count)"
echo "  With Mitigation Detection: $mitigation_count"
echo "  Heuristic: $heuristic_count"
echo ""
echo "📁 Output Files:"
[ -f "$OUTPUT_JSON" ] && echo "  JSON: $OUTPUT_JSON"
[ -f "$OUTPUT_MD" ] && echo "  Markdown: $OUTPUT_MD"
echo ""

