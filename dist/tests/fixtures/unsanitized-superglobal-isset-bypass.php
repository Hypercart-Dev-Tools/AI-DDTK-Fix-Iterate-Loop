<?php
/**
 * Test fixture: Unsanitized superglobal read with isset() bypass
 *
 * This file tests the edge case where isset() is used to check if a superglobal
 * exists, but then the value is used directly without sanitization.
 *
 * Expected: 5 violations detected
 */

// ❌ VIOLATION 1: isset() check doesn't sanitize - value used in comparison
if ( isset( $_GET['tab'] ) && $_GET['tab'] === 'subscriptions' ) {
    echo 'Subscriptions tab';
}

// ❌ VIOLATION 2: isset() check doesn't sanitize - value used in switch
if ( isset( $_GET['action'] ) ) {
    switch ( $_GET['action'] ) {
        case 'delete':
            delete_item();
            break;
    }
}

// ❌ VIOLATION 3: isset() check doesn't sanitize - value used in function call
if ( isset( $_POST['user_id'] ) ) {
    $user = get_user_by( 'id', $_POST['user_id'] );
}

// ❌ VIOLATION 4: isset() check doesn't sanitize - value assigned to variable
if ( isset( $_GET['page'] ) ) {
    $page = $_GET['page'];
}

// ❌ VIOLATION 5: isset() check doesn't sanitize - value used in string concatenation
if ( isset( $_GET['redirect'] ) ) {
    $url = 'https://example.com/' . $_GET['redirect'];
}

// ✅ VALID: isset() used only to check existence, then sanitized
if ( isset( $_GET['tab'] ) && sanitize_key( $_GET['tab'] ) === 'subscriptions' ) {
    echo 'Subscriptions tab';
}

// ✅ VALID: isset() check, then sanitized before use
if ( isset( $_POST['user_id'] ) ) {
    $user_id = absint( $_POST['user_id'] );
    $user = get_user_by( 'id', $user_id );
}

// ✅ VALID: isset() check, then wc_clean() sanitization
if ( isset( $_POST['notice'] ) ) {
    $notice = wc_clean( $_POST['notice'] );
    dismiss_notice( $notice );
}

// ✅ VALID: isset() check, then intval() sanitization
if ( isset( $_POST['index'] ) ) {
    $index = intval( $_POST['index'] );
}

// ✅ VALID: isset() used ONLY to check existence (no further use of superglobal)
if ( isset( $_GET['debug'] ) ) {
    define( 'WP_DEBUG', true );
}

// ✅ VALID: empty() check (similar to isset but also checks for empty values)
if ( ! empty( $_GET['tab'] ) ) {
    // Not using the value, just checking if it exists and is not empty
    show_tab_content();
}

