<?php
/**
 * Phase 2 Test Fixture: WPDB Safety Detection
 * 
 * This fixture tests the detection of safe literal SQL vs unsafe concatenated SQL.
 * The scanner should downgrade severity for safe literal queries.
 * 
 * Expected behavior:
 * - Safe literal SQL should be reported as LOW/MEDIUM (best-practice)
 * - Unsafe concatenated SQL should be reported as HIGH/CRITICAL (security)
 */

global $wpdb;

// ============================================================
// SAFE LITERAL SQL (Should downgrade to best-practice)
// ============================================================

function test_safe_literal_select() {
    global $wpdb;
    
    // Safe: Literal SQL with only wpdb identifiers
    $results = $wpdb->get_results(
        "SELECT * FROM {$wpdb->posts} WHERE post_type = 'page' AND post_status = 'publish'"
    );
    return $results;
}

function test_safe_literal_delete() {
    global $wpdb;
    
    // Safe: Literal SQL with wpdb prefix
    $wpdb->query(
        "DELETE FROM {$wpdb->options} WHERE option_name = 'my_temp_option'"
    );
}

function test_safe_literal_update() {
    global $wpdb;
    
    // Safe: Literal SQL with wpdb table names
    $wpdb->query(
        "UPDATE {$wpdb->postmeta} SET meta_value = '0' WHERE meta_key = 'my_flag'"
    );
}

function test_safe_literal_insert() {
    global $wpdb;
    
    // Safe: Literal SQL
    $wpdb->query(
        "INSERT INTO {$wpdb->usermeta} (user_id, meta_key, meta_value) VALUES (1, 'test_key', 'test_value')"
    );
}

function test_safe_with_wpdb_prefix_concat() {
    global $wpdb;
    
    // Safe: Only concatenating wpdb identifiers
    $table = $wpdb->prefix . 'custom_table';
    $results = $wpdb->get_results(
        "SELECT * FROM " . $table . " WHERE status = 'active'"
    );
    return $results;
}

// ============================================================
// UNSAFE CONCATENATED SQL (Should keep high severity)
// ============================================================

function test_unsafe_superglobal_concat() {
    global $wpdb;
    
    // UNSAFE: Concatenating $_GET (SQL injection risk)
    $post_id = $_GET['id'];
    $results = $wpdb->get_results(
        "SELECT * FROM {$wpdb->posts} WHERE ID = " . $post_id
    );
    return $results;
}

function test_unsafe_variable_concat() {
    global $wpdb;
    
    // UNSAFE: Concatenating user-provided variable
    $search_term = $_POST['search'];
    $results = $wpdb->get_results(
        "SELECT * FROM {$wpdb->posts} WHERE post_title LIKE '%" . $search_term . "%'"
    );
    return $results;
}

function test_unsafe_request_concat() {
    global $wpdb;
    
    // UNSAFE: Using $_REQUEST in query
    $user_id = $_REQUEST['user_id'];
    $meta = $wpdb->get_var(
        "SELECT meta_value FROM {$wpdb->usermeta} WHERE user_id = " . $user_id
    );
    return $meta;
}

function test_unsafe_cookie_concat() {
    global $wpdb;
    
    // UNSAFE: Using $_COOKIE in query
    $session_id = $_COOKIE['session'];
    $wpdb->query(
        "DELETE FROM {$wpdb->prefix}sessions WHERE session_id = '" . $session_id . "'"
    );
}

function test_unsafe_variable_interpolation() {
    global $wpdb;
    
    // UNSAFE: Variable interpolation (not wpdb identifier)
    $user_input = $_POST['category'];
    $results = $wpdb->get_results(
        "SELECT * FROM {$wpdb->posts} WHERE post_category = '$user_input'"
    );
    return $results;
}

// ============================================================
// EDGE CASES
// ============================================================

function test_mixed_safe_and_unsafe() {
    global $wpdb;
    
    // UNSAFE: Mix of safe wpdb identifiers and unsafe user input
    $status = $_GET['status'];
    $results = $wpdb->get_results(
        "SELECT * FROM {$wpdb->posts} WHERE post_status = '" . $status . "'"
    );
    return $results;
}

function test_safe_with_multiple_wpdb_tables() {
    global $wpdb;
    
    // Safe: Multiple wpdb identifiers
    $results = $wpdb->get_results(
        "SELECT p.*, pm.* 
         FROM {$wpdb->posts} p 
         LEFT JOIN {$wpdb->postmeta} pm ON p.ID = pm.post_id 
         WHERE p.post_type = 'product'"
    );
    return $results;
}

function test_prepared_statement() {
    global $wpdb;
    
    // SAFE: Using prepare() - should be skipped by scanner
    $post_id = $_GET['id'];
    $results = $wpdb->get_results(
        $wpdb->prepare(
            "SELECT * FROM {$wpdb->posts} WHERE ID = %d",
            $post_id
        )
    );
    return $results;
}

