<?php
/**
 * Test fixture for wp-json-html-escape pattern
 * 
 * This pattern detects HTML escaping functions (esc_url, esc_attr, esc_html)
 * used in JSON response fields with URL-like names.
 * 
 * Expected detections: 8 true positives (lines marked with ❌)
 * Acceptable cases: 4 (lines marked with ✅ - intentional HTML or non-URL fields)
 */

// ============================================================================
// TRUE POSITIVES - Should be detected (8 cases)
// ============================================================================

// ❌ Case 1: esc_url() in wp_send_json_success with redirect_url key
function ajax_login_handler() {
    if ( wp_verify_nonce( $_POST['nonce'], 'login_nonce' ) ) {
        wp_send_json_success( array(
            'redirect_url' => esc_url( admin_url( 'admin.php' ) )  // Line 21 - DETECT
        ) );
    }
}

// ❌ Case 2: esc_url() in wp_send_json_error with view_url key
function ajax_delete_post() {
    if ( ! current_user_can( 'delete_posts' ) ) {
        wp_send_json_error( array(
            'view_url' => esc_url( get_permalink( $post_id ) )  // Line 30 - DETECT
        ) );
    }
}

// ❌ Case 3: esc_attr() in wp_send_json with edit_url key
function get_post_edit_link() {
    $edit_link = get_edit_post_link( $post_id );
    wp_send_json( array(
        'edit_url' => esc_attr( $edit_link )  // Line 38 - DETECT
    ) );
}

// ❌ Case 4: esc_html() in WP_REST_Response with ajax_url key
function rest_get_settings( $request ) {
    return new WP_REST_Response( array(
        'ajax_url' => esc_html( admin_url( 'admin-ajax.php' ) )  // Line 45 - DETECT
    ) );
}

// ❌ Case 5: esc_url() in wp_json_encode with api_url key
function enqueue_ajax_script() {
    $data = array(
        'api_url' => esc_url( rest_url( 'wp/v2/posts' ) )  // Line 52 - DETECT
    );
    wp_localize_script( 'my-script', 'myData', $data );
}

// ❌ Case 6: esc_url() with href key
function ajax_get_link() {
    wp_send_json_success( array(
        'href' => esc_url( 'https://example.com/page' )  // Line 60 - DETECT
    ) );
}

// ❌ Case 7: esc_url() with link key
function get_download_link() {
    wp_send_json( array(
        'link' => esc_url( wp_get_attachment_url( $attachment_id ) )  // Line 67 - DETECT
    ) );
}

// ❌ Case 8: esc_url() with delete_url key
function ajax_delete_item() {
    wp_send_json_success( array(
        'delete_url' => esc_url( admin_url( 'admin.php?action=delete&id=' . $id ) )  // Line 74 - DETECT
    ) );
}

// ============================================================================
// ACCEPTABLE CASES - Should NOT be detected (4 cases)
// ============================================================================

// ✅ Case 1: esc_html() with html_content key (intentional HTML fragment)
function ajax_get_content() {
    wp_send_json_success( array(
        'html_content' => esc_html( $content )  // OK - HTML content, not URL
    ) );
}

// ✅ Case 2: esc_html() with message key (not a URL field)
function ajax_save_settings() {
    wp_send_json_success( array(
        'message' => esc_html( 'Settings saved successfully' )  // OK - message, not URL
    ) );
}

// ✅ Case 3: Raw URL without escaping (correct for JSON)
function ajax_get_redirect() {
    wp_send_json_success( array(
        'redirect_url' => admin_url( 'admin.php' )  // OK - raw URL, no escaping
    ) );
}

// ✅ Case 4: esc_url_raw() for database storage (different context)
function save_url_to_db() {
    $url = esc_url_raw( $_POST['url'] );  // OK - sanitizing for DB, not JSON response
    update_option( 'my_url', $url );
}

// ============================================================================
// EDGE CASES - Context matters
// ============================================================================

// Edge case: Multiple keys, only some are URLs
function ajax_mixed_response() {
    wp_send_json_success( array(
        'title' => esc_html( $title ),           // OK - not a URL field
        'redirect_url' => esc_url( $url ),       // Line 121 - DETECT (URL field)
        'message' => esc_html( $message )        // OK - not a URL field
    ) );
}

// Edge case: Nested array with URL
function ajax_nested_data() {
    wp_send_json_success( array(
        'data' => array(
            'view_url' => esc_url( get_permalink() )  // Line 130 - DETECT
        )
    ) );
}

// Edge case: JSON in REST API callback
function register_custom_endpoint() {
    register_rest_route( 'my-plugin/v1', '/data', array(
        'callback' => function() {
            return new WP_REST_Response( array(
                'endpoint' => esc_url( rest_url( 'my-plugin/v1/posts' ) )  // Line 140 - DETECT
            ) );
        }
    ) );
}

