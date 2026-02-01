#!/usr/bin/env bash
#
# WP Code Check - AI Triage Simple Smoke Test
# Version: 1.0.0
#
# Simple regression test for ai-triage.py to ensure it writes ai_triage data.
#
# Usage:
#   ./test-ai-triage-simple.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/../bin"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
TEMP_JSON=$(mktemp)

echo "================================================"
echo "  WP Code Check - AI Triage Simple Smoke Test"
echo "================================================"
echo ""

# Step 1: Generate a scan log
echo "Step 1: Generating scan log..."
"$BIN_DIR/check-performance.sh" \
  --paths "$FIXTURES_DIR/antipatterns.php" \
  --format json \
  --no-log 2>&1 | sed -n '/^{/,/^}$/p' > "$TEMP_JSON"

if [ ! -s "$TEMP_JSON" ]; then
  echo "✗ FAIL: Could not generate JSON log"
  rm -f "$TEMP_JSON"
  exit 1
fi

echo "✓ Generated JSON log"

# Step 2: Run AI triage
echo "Step 2: Running AI triage..."
python3 "$BIN_DIR/ai-triage.py" "$TEMP_JSON" --max-findings 50 > /dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "✗ FAIL: ai-triage.py exited with non-zero code"
  rm -f "$TEMP_JSON"
  exit 1
fi

echo "✓ AI triage completed"

# Step 3: Verify ai_triage exists
echo "Step 3: Verifying ai_triage data..."

if command -v jq &> /dev/null; then
  HAS_AI_TRIAGE=$(jq 'has("ai_triage")' "$TEMP_JSON" 2>/dev/null)
  if [ "$HAS_AI_TRIAGE" != "true" ]; then
    echo "✗ FAIL: ai_triage key not found in JSON"
    rm -f "$TEMP_JSON"
    exit 1
  fi
  
  PERFORMED=$(jq -r '.ai_triage.performed' "$TEMP_JSON" 2>/dev/null)
  if [ "$PERFORMED" != "true" ]; then
    echo "✗ FAIL: ai_triage.performed is not true"
    rm -f "$TEMP_JSON"
    exit 1
  fi
  
  TRIAGED_COUNT=$(jq '.ai_triage.triaged_findings | length' "$TEMP_JSON" 2>/dev/null)
  echo "✓ ai_triage data verified ($TRIAGED_COUNT findings triaged)"
else
  if grep -q '"ai_triage"' "$TEMP_JSON" 2>/dev/null && grep -q '"performed": true' "$TEMP_JSON" 2>/dev/null; then
    echo "✓ ai_triage data verified (jq not available, used grep)"
  else
    echo "✗ FAIL: ai_triage data not found"
    rm -f "$TEMP_JSON"
    exit 1
  fi
fi

# Cleanup
rm -f "$TEMP_JSON"

echo ""
echo "================================================"
echo "✓ All tests passed!"
echo "================================================"
exit 0

