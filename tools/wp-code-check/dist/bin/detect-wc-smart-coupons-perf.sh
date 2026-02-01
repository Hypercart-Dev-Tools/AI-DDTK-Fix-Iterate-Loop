#!/usr/bin/env bash
# ============================================================================
# WooCommerce Smart Coupons Thank-You Performance Detector
# ============================================================================
# Detects WooCommerce Smart Coupons plugin and warns about potential
# thank-you page performance issues caused by slow coupon lookup queries.
#
# Pattern ID: wc-smart-coupons-thankyou-perf
# Version: 1.0.0
# Category: performance
# Severity: HIGH
#
# Usage:
#   bash detect-wc-smart-coupons-perf.sh [path]
#
# Arguments:
#   path - Directory to scan (default: current directory)
#
# Requirements:
#   - ripgrep (rg) preferred, falls back to grep if not available
#
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCAN_PATH="${1:-.}"
TEMP_FILE_STEP1="/tmp/smart_coupons_files_$$.txt"
TEMP_FILE_STEP2="/tmp/smart_coupons_hooks_$$.txt"
HAS_RG=false

# Check if ripgrep is available
if command -v rg &> /dev/null; then
  HAS_RG=true
fi

# ============================================================================
# Cleanup
# ============================================================================

cleanup() {
  rm -f "$TEMP_FILE_STEP1" "$TEMP_FILE_STEP2"
}
trap cleanup EXIT

# ============================================================================
# Detection Logic
# ============================================================================

echo "🔍 WooCommerce Smart Coupons Performance Detector"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$HAS_RG" = true ]; then
  echo "✓ Using ripgrep (fast mode)"
else
  echo "⚠️  ripgrep not found, using grep (slower)"
fi
echo ""

# ============================================================================
# Step 1: Detect Smart Coupons Plugin
# ============================================================================

echo "# Step 1: Detecting WooCommerce Smart Coupons plugin..."

if [ "$HAS_RG" = true ]; then
  rg -l -n -S --type php \
    -e 'Plugin Name:[[:space:]]*WooCommerce Smart Coupons' \
    -e 'class[[:space:]]+WC_Smart_Coupons|class[[:space:]]+Smart_Coupons' \
    -e 'namespace[[:space:]]+WooCommerce\\SmartCoupons' \
    -e 'define\([[:space:]]*['\''"]WC_SC_' \
    --glob '!vendor/*' --glob '!node_modules/*' --glob '!tests/*' \
    "$SCAN_PATH" > "$TEMP_FILE_STEP1" 2>/dev/null || true
else
  grep -Rl -E \
    'Plugin Name:[[:space:]]*WooCommerce Smart Coupons|class[[:space:]]+WC_Smart_Coupons|class[[:space:]]+Smart_Coupons|namespace[[:space:]]+WooCommerce\\SmartCoupons|define\([[:space:]]*['\''"]WC_SC_' \
    --include='*.php' \
    --exclude-dir=vendor \
    --exclude-dir=node_modules \
    --exclude-dir=tests \
    "$SCAN_PATH" > "$TEMP_FILE_STEP1" 2>/dev/null || true
fi

if [ ! -s "$TEMP_FILE_STEP1" ]; then
  echo "✓ WooCommerce Smart Coupons plugin not detected."
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ No issues - Smart Coupons plugin not found"
  exit 0
fi

PLUGIN_FILE_COUNT=$(wc -l < "$TEMP_FILE_STEP1" | tr -d ' ')
echo "⚠️  Found WooCommerce Smart Coupons plugin ($PLUGIN_FILE_COUNT file(s))"
echo ""

# ============================================================================
# Step 2: Check for Thank-You Hooks or Coupon Lookups
# ============================================================================

echo "# Step 2: Checking for thank-you page hooks and coupon lookups..."
echo ""

FOUND_PERF_RISK=false

while IFS= read -r file; do
  if [ "$HAS_RG" = true ]; then
    if rg -n -S --type php \
      -e 'add_action\([[:space:]]*['\''"]woocommerce_thankyou' \
      -e 'add_action\([[:space:]]*['\''"]woocommerce_order_details_after' \
      -e 'wc_get_coupon_id_by_code\(' \
      -e 'get_page_by_title\([^,]+,[^,]+,[[:space:]]*['\''"]shop_coupon' \
      "$file" 2>/dev/null; then
      FOUND_PERF_RISK=true
      echo ""
    fi
  else
    if grep -nE \
      'add_action\([[:space:]]*['\''"]woocommerce_thankyou|add_action\([[:space:]]*['\''"]woocommerce_order_details_after|wc_get_coupon_id_by_code\(|get_page_by_title\([^,]+,[^,]+,[[:space:]]*['\''"]shop_coupon' \
      "$file" 2>/dev/null; then
      FOUND_PERF_RISK=true
      echo ""
    fi
  fi
done < "$TEMP_FILE_STEP1"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$FOUND_PERF_RISK" = true ]; then
  echo "⚠️  HIGH RISK: Smart Coupons uses thank-you hooks or coupon lookups"
  echo ""
  echo "📊 Performance Impact:"
  echo "   • Typical delay: 15-30 seconds per thank-you page load"
  echo "   • Cause: LOWER(post_title) query scans entire wp_posts table"
  echo "   • Affected: Thank-you page, order received page"
  echo ""
  echo "🔧 Immediate Fix (Database Index):"
  echo "   Run this SQL query to add an optimized index:"
  echo ""
  echo "   ALTER TABLE wp_posts ADD INDEX idx_coupon_lookup (post_title(50), post_type, post_status);"
  echo ""
  echo "   Expected improvement: 15-30s → <100ms"
  echo ""
  echo "📋 Additional Recommendations:"
  echo "   1. Install Query Monitor plugin to confirm slow queries"
  echo "   2. Check Smart Coupons settings - disable thank-you features if unused"
  echo "   3. Implement object caching (Redis/Memcached) for coupon lookups"
  echo "   4. Consider alternative coupon plugins with better performance"
  echo ""
  exit 1
else
  echo "ℹ️  MEDIUM RISK: Smart Coupons detected but no obvious thank-you hooks found"
  echo ""
  echo "   The plugin may still cause performance issues depending on configuration."
  echo "   Recommended: Monitor thank-you page performance with Query Monitor."
  echo ""
  exit 0
fi

