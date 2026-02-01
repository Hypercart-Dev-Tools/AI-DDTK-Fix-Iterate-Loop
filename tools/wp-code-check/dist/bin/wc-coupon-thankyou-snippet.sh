#!/usr/bin/env bash
# ============================================================================
# WooCommerce Coupon-in-Thank-You Detection (Minimal Copy-Paste Version)
# ============================================================================
# Detects coupon logic in WooCommerce thank-you/order-received contexts.
# This is a first-pass heuristic - may have false positives.
#
# Usage: bash wc-coupon-thankyou-snippet.sh
# Assumes: Run from project root, scans PHP files
# ============================================================================

# Step 1: Find files with thank-you/order-received context markers
echo "# Step 1: Finding files with thank-you/order-received context..."
rg -l -n -S --type php \
  -e '(add_action|do_action|apply_filters|add_filter)\([[:space:]]*['\''"]([a-z_]*woocommerce_thankyou[a-z_]*)['\''"]' \
  -e 'is_order_received_page\(' \
  -e 'is_wc_endpoint_url\([[:space:]]*['\''"]order-received['\''"]' \
  -e 'woocommerce/checkout/(thankyou|order-received)\.php' \
  --glob '!vendor/*' --glob '!node_modules/*' --glob '!tests/*' --glob '!*test*.php' \
  > /tmp/thankyou_context_files.txt

if [ ! -s /tmp/thankyou_context_files.txt ]; then
  echo "# No thank-you/order-received context files found."
  rm -f /tmp/thankyou_context_files.txt
  exit 0
fi

echo "# Found $(wc -l < /tmp/thankyou_context_files.txt) files with thank-you context."
echo ""
echo "# Step 2: Searching for coupon operations in those files..."
echo ""

# Step 2: Search those files for coupon operations
while IFS= read -r file; do
  rg -n -S --type php \
    -e '->apply_coupon\(' \
    -e '->remove_coupon\(' \
    -e '->has_coupon\(' \
    -e 'new[[:space:]]+WC_Coupon\(' \
    -e 'wc_get_coupon\(' \
    -e '->get_used_coupons\(' \
    -e '->get_coupon_codes\(' \
    -e '(add_filter|apply_filters)\([[:space:]]*['\''"]woocommerce_coupon_is_valid' \
    -e '(add_action|do_action)\([[:space:]]*['\''"]woocommerce_(applied|removed)_coupon' \
    "$file" 2>/dev/null && echo ""
done < /tmp/thankyou_context_files.txt

# Cleanup
rm -f /tmp/thankyou_context_files.txt

# ============================================================================
# Fallback using grep (if ripgrep not available)
# ============================================================================
# Uncomment below if you don't have ripgrep installed:
#
# # Step 1: Find thank-you/order-received context files
# grep -Rl -E \
#   '(add_action|do_action).*woocommerce_thankyou|is_order_received_page|is_wc_endpoint_url.*order-received|woocommerce/checkout/(thankyou|order-received)' \
#   --include='*.php' \
#   --exclude-dir=vendor \
#   --exclude-dir=node_modules \
#   --exclude-dir=tests \
#   . > /tmp/thankyou_context_files.txt
#
# if [ ! -s /tmp/thankyou_context_files.txt ]; then
#   echo "# No thank-you/order-received context files found."
#   rm -f /tmp/thankyou_context_files.txt
#   exit 0
# fi
#
# echo "# Found $(wc -l < /tmp/thankyou_context_files.txt) files with thank-you context."
# echo ""
# echo "# Step 2: Searching for coupon operations..."
# echo ""
#
# # Step 2: Search for coupon operations in those files
# while IFS= read -r file; do
#   grep -nE \
#     'apply_coupon|remove_coupon|has_coupon|WC_Coupon|wc_get_coupon|get_used_coupons|get_coupon_codes|woocommerce_coupon_is_valid|woocommerce_(applied|removed)_coupon' \
#     "$file" 2>/dev/null && echo ""
# done < /tmp/thankyou_context_files.txt
#
# rm -f /tmp/thankyou_context_files.txt

