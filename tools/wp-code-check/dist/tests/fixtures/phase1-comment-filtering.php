<?php
/**
 * Phase 1 Test Fixture: Comment/Docblock Filtering (Enhanced)
 *
 * This fixture tests that the scanner correctly ignores matches inside comments and docblocks,
 * including edge cases like string literals and inline comments.
 *
 * Expected violations: 2 (only the actual code, not comments or strings)
 * Expected passes: 10+ (all comment/docblock mentions, strings, inline comments)
 */

// ============================================================
// FALSE POSITIVES (Should NOT be flagged)
// ============================================================

/**
 * This function makes HTTP requests.
 *
 * @uses wp_remote_get() to fetch data from external API
 * @uses wp_remote_post() to send data to webhook
 *
 * @param string $url The URL to fetch
 * @return array Response data
 */
function example_docblock_mentions() {
    // This comment mentions wp_remote_get() but doesn't call it
    /* This block comment also mentions wp_remote_post() */

    /**
     * Inline docblock mentioning wp_remote_request()
     */

    // Single line comment: wp_remote_head() is useful

    /*
     * Multi-line comment block
     * mentioning wp_remote_get() and wp_remote_post()
     * across multiple lines
     */

    return array();
}

// ============================================================
// EDGE CASE: String Literals with Comment Markers
// ============================================================

function string_literals_with_comment_markers() {
    // These strings contain /* */ but are NOT comments - should NOT be flagged
    $description = "This function uses /* block comments */ for documentation";
    echo "Example: /* not a comment */";
    $pattern = '/\* asterisk pattern */';

    // Inline comment after code - should NOT be flagged
    $data = array(); /* wp_remote_get() mentioned in inline comment */

    return $description;
}

// ============================================================
// EDGE CASE: Large Docblock (>50 lines, tests 100-line backscan)
// ============================================================

/**
 * Large docblock to test backscan window.
 *
 * Line 3 of docblock
 * Line 4 of docblock
 * Line 5 of docblock
 * Line 6 of docblock
 * Line 7 of docblock
 * Line 8 of docblock
 * Line 9 of docblock
 * Line 10 of docblock
 * Line 11 of docblock
 * Line 12 of docblock
 * Line 13 of docblock
 * Line 14 of docblock
 * Line 15 of docblock
 * Line 16 of docblock
 * Line 17 of docblock
 * Line 18 of docblock
 * Line 19 of docblock
 * Line 20 of docblock - mentions wp_remote_get() here
 * Line 21 of docblock
 * Line 22 of docblock
 * Line 23 of docblock
 * Line 24 of docblock
 * Line 25 of docblock
 */
function large_docblock_test() {
    return true;
}

// ============================================================
// TRUE VIOLATIONS (Should be flagged)
// ============================================================

function actual_http_call_without_timeout() {
    // This is actual code - should be flagged
    $response = wp_remote_get( 'https://api.example.com/data' );
    return $response;
}

function another_actual_call() {
    // Another real call - should be flagged
    $result = wp_remote_post( 'https://webhook.example.com', array(
        'body' => array( 'data' => 'test' )
    ) );
    return $result;
}

