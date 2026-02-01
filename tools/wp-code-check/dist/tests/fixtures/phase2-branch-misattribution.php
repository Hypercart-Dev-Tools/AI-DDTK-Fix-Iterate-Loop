<?php
/**
 * Phase 2.1 Test Fixture: Branch Misattribution Cases
 *
 * Tests that guards in different branches, functions, or checking different
 * parameters are NOT incorrectly attributed to superglobal access.
 *
 * Expected Behavior:
 * - Guards in different if/else branches: Should NOT be counted
 * - Guards in different functions: Should NOT be counted
 * - Guards checking different parameters: Should NOT be counted
 * - Guards after access: Should NOT be counted
 * - Guards in unreachable code: Should NOT be counted
 *
 * Current Implementation (Phase 2): WILL FAIL these tests (window-based)
 * Phase 2.1 Goal: PASS these tests (function-scoped, before-access only)
 */

// ============================================================
// TEST CASE 1: Guard in Different Branch (if/else)
// ============================================================

function test_guard_different_branch_if() {
    if ( isset( $_POST['action'] ) && $_POST['action'] === 'verify' ) {
        // Guard in this branch
        wp_verify_nonce( $_POST['nonce'], 'verify_action' );
        echo "Verified";
    } else {
        // Access in different branch - NOT PROTECTED
        // EXPECTED: Should be flagged as HIGH severity (no guard)
        // CURRENT (Phase 2): Incorrectly marked as guarded (window-based)
        $data = $_POST['data'];
        echo $data;
    }
}

function test_guard_different_branch_nested() {
    if ( current_user_can( 'manage_options' ) ) {
        if ( isset( $_POST['nonce'] ) ) {
            wp_verify_nonce( $_POST['nonce'], 'admin_action' );
        }
    } else {
        // Access in completely different branch - NOT PROTECTED
        // EXPECTED: Should be flagged as HIGH severity
        $user_input = $_GET['user_input'];
        process_data( $user_input );
    }
}

// ============================================================
// TEST CASE 2: Guard in Different Function
// ============================================================

function verify_nonce_separate() {
    // Guard in separate function
    wp_verify_nonce( $_POST['nonce'], 'my_action' );
}

function process_data_separate() {
    // Access in different function - NOT PROTECTED
    // EXPECTED: Should be flagged as HIGH severity
    // CURRENT (Phase 2): May be marked as guarded if functions are close
    $data = $_POST['data'];
    return sanitize_text_field( $data );
}

function check_capability_separate() {
    current_user_can( 'edit_posts' );
}

function handle_request_separate() {
    // Access in different function - NOT PROTECTED
    // EXPECTED: Should be flagged as HIGH severity
    $post_id = $_GET['post_id'];
    return get_post( $post_id );
}

// ============================================================
// TEST CASE 3: Guard Checking Different Parameter
// ============================================================

function test_guard_different_parameter() {
    // Guard checks 'nonce1' parameter
    wp_verify_nonce( $_POST['nonce1'], 'action1' );

    // Access uses 'data2' parameter - DIFFERENT PARAMETER
    // EXPECTED: Should be flagged as HIGH severity (guard doesn't protect this)
    // CURRENT (Phase 2): Incorrectly marked as guarded
    $data = $_POST['data2'];
    echo $data;
}

function test_guard_different_superglobal() {
    // Guard checks $_POST['nonce']
    check_ajax_referer( $_POST['nonce'], 'ajax_action' );

    // Access uses $_GET - DIFFERENT SUPERGLOBAL
    // EXPECTED: Should be flagged as HIGH severity
    $search = $_GET['search'];
    return $search;
}

// ============================================================
// TEST CASE 4: Guard After Access (Too Late)
// ============================================================

function test_guard_after_access() {
    // Access BEFORE guard - NOT PROTECTED
    // EXPECTED: Should be flagged as HIGH severity
    $data = $_POST['data'];
    echo $data;

    // Guard comes AFTER - too late!
    wp_verify_nonce( $_POST['nonce'], 'my_action' );
}

function test_guard_after_multiple_access() {
    $input1 = $_GET['input1'];
    $input2 = $_POST['input2'];
    process( $input1, $input2 );

    // Guard after all access - too late!
    current_user_can( 'manage_options' );
}

// ============================================================
// TEST CASE 5: Guard in Unreachable Code
// ============================================================

function test_guard_after_return() {
    // Access before return
    $data = $_POST['data'];
    return $data;

    // Guard after return - UNREACHABLE
    wp_verify_nonce( $_POST['nonce'], 'action' );
}

function test_guard_in_dead_code() {
    if ( false ) {
        // Guard in dead code - never executes
        wp_verify_nonce( $_POST['nonce'], 'action' );
    }

    // Access outside dead code - NOT PROTECTED
    $value = $_GET['value'];
    return $value;
}

// ============================================================
// TEST CASE 6: Guard in Callback (Different Execution Context)
// ============================================================

function test_guard_in_callback() {
    // Guard in callback - different execution context
    add_action( 'init', function() {
        wp_verify_nonce( $_POST['nonce'], 'init_action' );
    });

    // Access outside callback - NOT PROTECTED
    // EXPECTED: Should be flagged as HIGH severity
    $data = $_POST['callback_data'];
    echo $data;
}

