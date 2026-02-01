<?php
/**
 * Test Fixture: Unsanitized $_GET/$_POST Read
 * 
 * This file contains examples of unsanitized superglobal access
 * that should be detected by the check-performance.sh script.
 * 
 * WordPress requires all superglobal access to be sanitized
 * to prevent XSS and parameter tampering attacks.
 */

// ============================================================
// VIOLATIONS - These should be detected
// ============================================================

// Direct $_GET access without sanitization - VIOLATION
if ( $_GET['tab'] === 'subscriptions' ) {
    // Missing sanitization
}

// Direct $_POST access without sanitization - VIOLATION
$value = $_POST['setting'];

// Direct $_REQUEST access without sanitization - VIOLATION
$action = $_REQUEST['action'];

// Using in comparison without sanitization - VIOLATION
if ( $_GET['status'] == 'active' ) {
    // Missing sanitization
}

// Using in array access without sanitization - VIOLATION
$data = $my_array[ $_GET['key'] ];

// Using in function call without sanitization - VIOLATION
do_action( $_GET['hook_name'] );

// Multiple accesses without sanitization - VIOLATION
$tab = $_GET['tab'];
$section = $_GET['section'];

// ============================================================
// VALID CODE - These should NOT be detected
// ============================================================

// Properly sanitized with sanitize_key - VALID
if ( isset( $_GET['tab'] ) && sanitize_key( $_GET['tab'] ) === 'subscriptions' ) {
    // Properly sanitized
}

// Properly sanitized with sanitize_text_field - VALID
$value = isset( $_POST['setting'] ) ? sanitize_text_field( $_POST['setting'] ) : '';

// Properly sanitized with absint - VALID
$id = isset( $_GET['id'] ) ? absint( $_GET['id'] ) : 0;

// Properly sanitized with intval - VALID
$page = isset( $_GET['page'] ) ? intval( $_GET['page'] ) : 1;

// Properly sanitized with esc_attr - VALID
$class = isset( $_GET['class'] ) ? esc_attr( $_GET['class'] ) : '';

// Properly sanitized with esc_html - VALID
$message = isset( $_POST['message'] ) ? esc_html( $_POST['message'] ) : '';

// Properly sanitized with wp_unslash - VALID
$data = isset( $_POST['data'] ) ? wp_unslash( $_POST['data'] ) : '';

// WooCommerce sanitization - VALID
$product_id = isset( $_GET['product_id'] ) ? wc_clean( $_GET['product_id'] ) : 0;

// isset check (defensive programming) - VALID
if ( isset( $_GET['tab'] ) ) {
    // Just checking existence
}

// empty check (defensive programming) - VALID
if ( ! empty( $_GET['tab'] ) ) {
    // Just checking existence
}

// Checking against allowed keys - VALID
$allowed_keys = array( 'tab', 'section', 'action' );
if ( in_array( $_GET['key'], $allowed_keys, true ) ) {
    // Validating against whitelist
}

// Comment mentioning $_GET - VALID (should be ignored)
// This function uses $_GET to retrieve the tab parameter

