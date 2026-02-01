<?php
/**
 * Phase 2 Test Fixture: Sanitizer Detection
 * 
 * This fixture tests the detection of sanitizers wrapping superglobal access.
 * The scanner should detect sanitizers and downgrade severity.
 * 
 * Expected behavior:
 * - Lines with sanitizers should be reported with LOWER severity
 * - Lines without sanitizers should be reported with HIGHER severity
 * - Sanitizers array should be populated in JSON output
 */

// ============================================================
// SANITIZED SUPERGLOBAL ACCESS (Should downgrade severity)
// ============================================================

function test_sanitize_text_field() {
    // Sanitizer: sanitize_text_field
    $name = sanitize_text_field( $_POST['user_name'] );
    return $name;
}

function test_sanitize_email() {
    // Sanitizer: sanitize_email
    $email = sanitize_email( $_POST['user_email'] );
    return $email;
}

function test_sanitize_key() {
    // Sanitizer: sanitize_key
    $key = sanitize_key( $_GET['option_key'] );
    return $key;
}

function test_sanitize_url() {
    // Sanitizer: sanitize_url
    $url = sanitize_url( $_POST['website'] );
    return $url;
}

function test_esc_url_raw() {
    // Sanitizer: esc_url_raw
    $redirect = esc_url_raw( $_GET['redirect_to'] );
    wp_redirect( $redirect );
}

function test_esc_url() {
    // Sanitizer: esc_url
    $link = esc_url( $_POST['external_link'] );
    echo '<a href="' . $link . '">Link</a>';
}

function test_esc_html() {
    // Sanitizer: esc_html
    $message = esc_html( $_POST['message'] );
    echo $message;
}

function test_esc_attr() {
    // Sanitizer: esc_attr
    $class = esc_attr( $_GET['css_class'] );
    echo '<div class="' . $class . '">Content</div>';
}

function test_absint() {
    // Sanitizer: absint (type caster)
    $post_id = absint( $_GET['post_id'] );
    return get_post( $post_id );
}

function test_intval() {
    // Sanitizer: intval (type caster)
    $page = intval( $_GET['page'] );
    return $page;
}

function test_floatval() {
    // Sanitizer: floatval (type caster)
    $price = floatval( $_POST['price'] );
    return $price;
}

function test_wp_unslash() {
    // Sanitizer: wp_unslash
    $data = wp_unslash( $_POST['data'] );
    return $data;
}

function test_stripslashes_deep() {
    // Sanitizer: stripslashes_deep
    $array = stripslashes_deep( $_POST['array_data'] );
    return $array;
}

function test_wc_clean() {
    // Sanitizer: wc_clean (WooCommerce)
    $product_name = wc_clean( $_POST['product_name'] );
    return $product_name;
}

// ============================================================
// COMBINED: GUARDS + SANITIZERS (Should skip - fully protected)
// ============================================================

function test_guards_and_sanitizers() {
    // Guard: wp_verify_nonce
    if ( ! wp_verify_nonce( $_POST['nonce'], 'action' ) ) {
        wp_die( 'Invalid nonce' );
    }
    
    // Sanitizer: sanitize_text_field
    // This should be SKIPPED (fully protected)
    $value = sanitize_text_field( $_POST['value'] );
    return $value;
}

function test_capability_and_sanitizer() {
    // Guard: current_user_can
    if ( ! current_user_can( 'manage_options' ) ) {
        return;
    }
    
    // Sanitizer: absint
    // This should be SKIPPED (fully protected)
    $option_id = absint( $_POST['option_id'] );
    return $option_id;
}

// ============================================================
// UNSANITIZED SUPERGLOBAL ACCESS (Should keep high severity)
// ============================================================

function test_no_sanitizer() {
    // NO SANITIZER - This should be HIGH severity
    $raw_input = $_POST['raw_input'];
    echo $raw_input;
}

function test_insufficient_sanitizer() {
    // isset() is NOT a sanitizer - just checks existence
    if ( isset( $_POST['data'] ) ) {
        $data = $_POST['data']; // Still unsanitized
        echo $data;
    }
}

// ============================================================
// EDGE CASES
// ============================================================

function test_nested_sanitizers() {
    // Multiple sanitizers (belt and suspenders)
    $url = esc_url( sanitize_url( $_POST['url'] ) );
    return $url;
}

function test_sanitizer_on_different_var() {
    // Sanitizer on different variable - should NOT protect
    $safe = sanitize_text_field( $_POST['safe_field'] );
    $unsafe = $_POST['unsafe_field']; // Not sanitized
    return $unsafe;
}

