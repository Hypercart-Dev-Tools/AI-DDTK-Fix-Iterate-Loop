#!/usr/bin/env bash
# ============================================================================
# WooCommerce Coupon-in-Thank-You Detector
# ============================================================================
# Detects coupon logic running in WooCommerce thank-you/order-received context.
# This is a reliability anti-pattern - coupon operations should happen during
# checkout, not after the order is complete.
#
# Pattern ID: wc-coupon-in-thankyou
# Version: 1.0.0
# Category: reliability
# Severity: HIGH
#
# Usage:
#   bash detect-wc-coupon-in-thankyou.sh [path]
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
TEMP_FILE="/tmp/thankyou_context_files_$$.txt"
HAS_RG=false

# Check if ripgrep is available
if command -v rg &> /dev/null; then
  HAS_RG=true
fi

# ============================================================================
# Cleanup
# ============================================================================

cleanup() {
  rm -f "$TEMP_FILE"
}
trap cleanup EXIT

# ============================================================================
# Detection Logic
# ============================================================================

echo "🔍 WooCommerce Coupon-in-Thank-You Detector"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$HAS_RG" = true ]; then
  echo "✓ Using ripgrep (fast mode)"
  echo ""
  
  # ============================================================================
  # Step 1: Find files with thank-you/order-received context markers
  # ============================================================================
  
  echo "# Step 1: Finding files with thank-you/order-received context..."
  rg -l -n -S --type php \
    -e '(add_action|do_action|apply_filters|add_filter)\([[:space:]]*['\''"]([a-z_]*woocommerce_thankyou[a-z_]*)['\''"]' \
    -e 'is_order_received_page\(' \
    -e 'is_wc_endpoint_url\([[:space:]]*['\''"]order-received['\''"]' \
    -e 'woocommerce/checkout/(thankyou|order-received)\.php' \
    --glob '!vendor/*' --glob '!node_modules/*' --glob '!tests/*' --glob '!*test*.php' \
    "$SCAN_PATH" > "$TEMP_FILE" 2>/dev/null || true
  
  if [ ! -s "$TEMP_FILE" ]; then
    echo "✓ No thank-you/order-received context files found."
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ No issues detected - no coupon logic in thank-you context"
    exit 0
  fi
  
  FILE_COUNT=$(wc -l < "$TEMP_FILE" | tr -d ' ')
  echo "✓ Found $FILE_COUNT file(s) with thank-you/order-received context."
  echo ""
  
  # ============================================================================
  # Step 2: Search those files for coupon operations
  # ============================================================================
  
  echo "# Step 2: Searching for coupon operations in those files..."
  echo ""
  
  FOUND_ISSUES=false
  
  while IFS= read -r file; do
    # Search for coupon operations in this file
    if rg -n -S --type php \
      -e '->apply_coupon\(' \
      -e '->remove_coupon\(' \
      -e '->has_coupon\(' \
      -e 'new[[:space:]]+WC_Coupon\(' \
      -e 'wc_get_coupon\(' \
      -e 'wc_get_coupon_id_by_code\(' \
      -e '->get_used_coupons\(' \
      -e '->get_coupon_codes\(' \
      -e '(add_filter|apply_filters)\([[:space:]]*['\''"]woocommerce_coupon_is_valid' \
      -e '(add_action|do_action)\([[:space:]]*['\''"]woocommerce_(applied|removed)_coupon' \
      "$file" 2>/dev/null; then
      FOUND_ISSUES=true
      echo ""
    fi
  done < "$TEMP_FILE"
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  if [ "$FOUND_ISSUES" = true ]; then
    echo "⚠️  Issues detected - coupon logic found in thank-you/order-received context"
    echo ""
    echo "📋 Remediation:"
    echo "   Move coupon operations to appropriate cart/checkout hooks:"
    echo "   - woocommerce_before_calculate_totals"
    echo "   - woocommerce_checkout_order_processed"
    echo "   - woocommerce_add_to_cart"
    echo ""
    echo "   The thank-you page should only DISPLAY order info, not modify it."
    exit 1
  else
    echo "✅ No issues detected - no coupon operations in thank-you context"
    exit 0
  fi

else
  # ============================================================================
  # Fallback: Use grep if ripgrep not available
  # ============================================================================

  echo "⚠️  ripgrep not found, using grep (slower)"
  echo ""

  echo "# Step 1: Finding files with thank-you/order-received context..."

  grep -Rl -E \
    '(add_action|do_action|apply_filters|add_filter)\([[:space:]]*['\''"]([a-z_]*woocommerce_thankyou[a-z_]*)['\''"]|is_order_received_page\(|is_wc_endpoint_url\([[:space:]]*['\''"]order-received['\''"]|woocommerce/checkout/(thankyou|order-received)\.php' \
    --include='*.php' \
    --exclude-dir=vendor \
    --exclude-dir=node_modules \
    --exclude-dir=tests \
    "$SCAN_PATH" > "$TEMP_FILE" 2>/dev/null || true

  if [ ! -s "$TEMP_FILE" ]; then
    echo "✓ No thank-you/order-received context files found."
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ No issues detected - no coupon logic in thank-you context"
    exit 0
  fi

  FILE_COUNT=$(wc -l < "$TEMP_FILE" | tr -d ' ')
  echo "✓ Found $FILE_COUNT file(s) with thank-you/order-received context."
  echo ""

  echo "# Step 2: Searching for coupon operations in those files..."
  echo ""

  FOUND_ISSUES=false

  while IFS= read -r file; do
    # Search for coupon operations in this file
    if grep -nE \
      'apply_coupon\(|remove_coupon\(|has_coupon\(|new[[:space:]]+WC_Coupon\(|wc_get_coupon\(|wc_get_coupon_id_by_code\(|get_used_coupons\(|get_coupon_codes\(|woocommerce_coupon_is_valid|woocommerce_(applied|removed)_coupon' \
      "$file" 2>/dev/null; then
      FOUND_ISSUES=true
      echo ""
    fi
  done < "$TEMP_FILE"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [ "$FOUND_ISSUES" = true ]; then
    echo "⚠️  Issues detected - coupon logic found in thank-you/order-received context"
    echo ""
    echo "📋 Remediation:"
    echo "   Move coupon operations to appropriate cart/checkout hooks:"
    echo "   - woocommerce_before_calculate_totals"
    echo "   - woocommerce_checkout_order_processed"
    echo "   - woocommerce_add_to_cart"
    echo ""
    echo "   The thank-you page should only DISPLAY order info, not modify it."
    exit 1
  else
    echo "✅ No issues detected - no coupon operations in thank-you context"
    exit 0
  fi
fi

