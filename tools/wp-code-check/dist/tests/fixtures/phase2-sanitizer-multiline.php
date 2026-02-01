<?php
/**
 * Phase 2.1 Test Fixture: Multi-line Sanitizer Detection
 *
 * Tests that sanitizers applied in variable assignments are properly detected.
 *
 * Expected Behavior (Phase 2.1):
 * - Sanitizer in variable assignment: Should be detected
 * - Later uses of sanitized variable: Should NOT be flagged
 *
 * Current Implementation (Phase 2): WILL FAIL these tests (single-line only)
 * Phase 2.1 Goal: PASS these tests (basic taint propagation)
 */

// ============================================================
// TEST CASE 1: Variable Assignment with Sanitizer
// ============================================================

function test_sanitizer_variable_assignment() {
    // Sanitizer applied to variable assignment
    // EXPECTED (Phase 2.1): Variable $name is marked as sanitized
    $name = sanitize_text_field( $_POST['name'] );

    // Later use of sanitized variable
    // EXPECTED (Phase 2.1): Should NOT be flagged (variable is sanitized)
    // CURRENT (Phase 2): Flagged as unsanitized (doesn't track variable)
    echo $name;
    return $name;
}

function test_sanitizer_multiple_assignments() {
    // Multiple sanitized assignments
    $email = sanitize_email( $_POST['email'] );
    $url = esc_url_raw( $_GET['url'] );
    $id = absint( $_POST['id'] );

    // Later uses - all should be safe
    // EXPECTED (Phase 2.1): None flagged
    // CURRENT (Phase 2): All flagged
    send_email( $email );
    redirect_to( $url );
    get_post( $id );
}

// ============================================================
// TEST CASE 2: Two-Step Sanitization
// ============================================================

function test_two_step_sanitization() {
    // Step 1: Get raw input
    $raw_data = $_POST['data'];

    // Step 2: Sanitize
    // EXPECTED (Phase 2.1): Variable $raw_data is now marked as sanitized
    $raw_data = sanitize_text_field( $raw_data );

    // Step 3: Use sanitized variable
    // EXPECTED (Phase 2.1): Should NOT be flagged
    // CURRENT (Phase 2): Flagged (doesn't track reassignment)
    echo $raw_data;
}

function test_unslash_then_sanitize() {
    // Common WordPress pattern: unslash then sanitize
    $data = wp_unslash( $_POST['data'] );
    $data = sanitize_text_field( $data );

    // EXPECTED (Phase 2.1): Should NOT be flagged
    return $data;
}

// ============================================================
// TEST CASE 3: Sanitizer in Conditional
// ============================================================

function test_sanitizer_in_conditional() {
    if ( isset( $_POST['name'] ) ) {
        $name = sanitize_text_field( $_POST['name'] );
        // EXPECTED (Phase 2.1): Should NOT be flagged
        echo $name;
    }
}

function test_sanitizer_in_ternary() {
    // Ternary with sanitizer
    $value = isset( $_GET['value'] ) ? sanitize_text_field( $_GET['value'] ) : '';

    // EXPECTED (Phase 2.1): Should NOT be flagged
    // CURRENT (Phase 2): May be flagged (complex pattern)
    return $value;
}

// ============================================================
// TEST CASE 4: Array Element Sanitization
// ============================================================

function test_array_element_sanitization() {
    // Sanitize array element
    $data = array();
    $data['name'] = sanitize_text_field( $_POST['name'] );
    $data['email'] = sanitize_email( $_POST['email'] );

    // EXPECTED (Phase 2.1): Should NOT be flagged (array elements sanitized)
    // CURRENT (Phase 2): Flagged (doesn't track array elements)
    echo $data['name'];
    send_email( $data['email'] );
}

// ============================================================
// TEST CASE 5: Sanitizer with Type Casting
// ============================================================

function test_type_casting_sanitization() {
    // Type casting as sanitization
    $id = absint( $_GET['id'] );
    $count = intval( $_POST['count'] );
    $price = floatval( $_POST['price'] );

    // EXPECTED (Phase 2.1): Should NOT be flagged (type-casted)
    // CURRENT (Phase 2): Flagged
    get_post( $id );
    set_count( $count );
    set_price( $price );
}

// ============================================================
// TEST CASE 6: WooCommerce wc_clean()
// ============================================================

function test_wc_clean_sanitization() {
    // WooCommerce sanitizer
    $product_name = wc_clean( $_POST['product_name'] );

    // EXPECTED (Phase 2.1): Should NOT be flagged
    // CURRENT (Phase 2): Flagged
    echo $product_name;
}

// ============================================================
// TEST CASE 7: Unsanitized Variable (Should Still Flag)
// ============================================================

function test_unsanitized_variable_assignment() {
    // NO sanitizer - just assignment
    $data = $_POST['data'];

    // EXPECTED: Should STILL be flagged (not sanitized)
    echo $data;
}

function test_partial_sanitization() {
    // Only one variable sanitized
    $safe = sanitize_text_field( $_POST['safe'] );
    $unsafe = $_POST['unsafe'];

    // EXPECTED: $safe should NOT be flagged, $unsafe SHOULD be flagged
    echo $safe;   // OK
    echo $unsafe; // NOT OK
}

// ============================================================
// TEST CASE 8: Sanitizer Scope Limits
// ============================================================

function test_sanitizer_scope_limit() {
    $data = sanitize_text_field( $_POST['data'] );
    echo $data; // OK - same function

    // Call another function
    other_function();
}

function other_function() {
    // EXPECTED: Should be flagged (different function scope)
    // $data from test_sanitizer_scope_limit() is NOT in scope here
    echo $data; // Should flag if $data is used here
}

