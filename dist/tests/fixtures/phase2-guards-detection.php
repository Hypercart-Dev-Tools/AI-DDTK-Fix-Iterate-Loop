<?php
/**
 * Phase 2 Test Fixture: Guard Detection
 * 
 * This fixture tests the detection of security guards (nonce checks, capability checks)
 * near superglobal access. The scanner should detect guards and downgrade severity.
 * 
 * Expected behavior:
 * - Lines with guards should be reported with LOWER severity
 * - Lines without guards should be reported with HIGHER severity
 * - Guards array should be populated in JSON output
 */

// ============================================================
// GUARDED SUPERGLOBAL ACCESS (Should downgrade severity)
// ============================================================

function test_nonce_protected_superglobal() {
    // Guard: wp_verify_nonce
    if ( ! wp_verify_nonce( $_POST['nonce'], 'my_action' ) ) {
        wp_die( 'Invalid nonce' );
    }
    
    // This should be detected with guards: ['wp_verify_nonce']
    $value = $_POST['user_input'];
    process_data( $value );
}

function test_ajax_referer_protected() {
    // Guard: check_ajax_referer
    check_ajax_referer( 'my_ajax_action' );
    
    // This should be detected with guards: ['check_ajax_referer']
    $data = $_POST['data'];
    return $data;
}

function test_admin_referer_protected() {
    // Guard: check_admin_referer
    check_admin_referer( 'my_admin_action' );
    
    // This should be detected with guards: ['check_admin_referer']
    $option = $_POST['option_value'];
    update_option( 'my_option', $option );
}

function test_capability_check_protected() {
    // Guard: current_user_can
    if ( ! current_user_can( 'manage_options' ) ) {
        wp_die( 'Insufficient permissions' );
    }
    
    // This should be detected with guards: ['current_user_can']
    $setting = $_POST['setting'];
    save_setting( $setting );
}

function test_multiple_guards() {
    // Multiple guards: nonce + capability
    if ( ! wp_verify_nonce( $_POST['nonce'], 'action' ) ) {
        wp_die( 'Invalid nonce' );
    }
    
    if ( ! current_user_can( 'edit_posts' ) ) {
        wp_die( 'No permission' );
    }
    
    // This should be detected with guards: ['wp_verify_nonce', 'current_user_can']
    $post_data = $_POST['post_data'];
    create_post( $post_data );
}

// ============================================================
// UNGUARDED SUPERGLOBAL ACCESS (Should keep high severity)
// ============================================================

function test_no_guards() {
    // NO GUARDS - This should be HIGH severity
    $user_input = $_POST['input'];
    echo $user_input;
}

function test_guards_too_far_away() {
    // Guard is here
    wp_verify_nonce( $_POST['nonce'], 'action' );
    
    // ... many lines of code ...
    $line1 = 'filler';
    $line2 = 'filler';
    $line3 = 'filler';
    $line4 = 'filler';
    $line5 = 'filler';
    $line6 = 'filler';
    $line7 = 'filler';
    $line8 = 'filler';
    $line9 = 'filler';
    $line10 = 'filler';
    $line11 = 'filler';
    $line12 = 'filler';
    $line13 = 'filler';
    $line14 = 'filler';
    $line15 = 'filler';
    $line16 = 'filler';
    $line17 = 'filler';
    $line18 = 'filler';
    $line19 = 'filler';
    $line20 = 'filler';
    $line21 = 'filler';
    $line22 = 'filler';
    
    // This is >20 lines away - should NOT detect guard
    $data = $_POST['data'];
    return $data;
}

// ============================================================
// EDGE CASES
// ============================================================

function test_guard_in_nonce_param() {
    // Special case: $_POST used as nonce parameter (SAFE - should skip)
    wp_verify_nonce( $_POST['_wpnonce'], 'my_action' );
}

function test_user_can_guard() {
    // Guard: user_can (less common variant)
    if ( ! user_can( get_current_user_id(), 'publish_posts' ) ) {
        return;
    }
    
    // This should be detected with guards: ['user_can']
    $title = $_POST['post_title'];
    create_post( $title );
}

function test_guard_after_access() {
    // Guard AFTER access - should NOT protect
    $value = $_POST['value'];
    
    // Guard comes too late
    wp_verify_nonce( $_POST['nonce'], 'action' );
    
    return $value;
}

