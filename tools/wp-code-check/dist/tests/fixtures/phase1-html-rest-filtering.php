<?php
/**
 * Phase 1 Test Fixture: HTML Form and REST Config Filtering (Enhanced)
 *
 * This fixture tests that the scanner correctly ignores HTML form method attributes
 * and REST route method configurations, including edge cases.
 *
 * Expected violations: 2 (only actual superglobal access)
 * Expected passes: 8+ (HTML forms, REST configs, edge cases)
 */

// ============================================================
// FALSE POSITIVES (Should NOT be flagged)
// ============================================================

function render_html_form() {
    ?>
    <!-- HTML form with POST method - should NOT be flagged -->
    <form action="#" method="POST" id="test-form">
        <input type="text" name="username" />
        <input type="submit" value="Submit" />
    </form>

    <!-- Another form with single quotes -->
    <form action="/submit" method='POST'>
        <input type="email" name="email" />
    </form>

    <!-- Form with lowercase 'post' - should NOT be flagged -->
    <form action="/api" method="post">
        <input type="text" name="data" />
    </form>

    <!-- Form with mixed case 'Post' - should NOT be flagged -->
    <form action="/submit" method="Post">
        <input type="text" name="field" />
    </form>
    <?php
}

function register_rest_routes() {
    // REST route with POST method - should NOT be flagged
    register_rest_route(
        'my-plugin/v1',
        '/endpoint',
        array(
            'methods'             => 'POST',
            'callback'            => 'my_callback',
            'permission_callback' => '__return_true',
        )
    );

    // REST route with methods array - should NOT be flagged
    register_rest_route(
        'my-plugin/v1',
        '/another',
        array(
            'methods' => array( 'POST', 'PUT' ),
            'callback' => 'another_callback',
        )
    );

    // REST route with lowercase 'post' - should NOT be flagged
    register_rest_route(
        'my-plugin/v1',
        '/lowercase',
        array(
            'methods' => 'post',
            'callback' => 'lowercase_callback',
        )
    );
}

// ============================================================
// EDGE CASES: Should NOT trigger false positives
// ============================================================

function edge_cases_that_should_not_be_filtered() {
    // Variable named $methods - this SHOULD be flagged (not a REST config)
    // But our improved pattern requires quotes around 'methods' key
    $methods = $_POST['methods']; // SHOULD BE FLAGGED

    // String containing "method" and "POST" - not a form
    $description = "This method handles POST requests"; // Should NOT be flagged

    // Comment mentioning method and POST
    // The method attribute should be POST for forms

    return $methods;
}

// ============================================================
// TRUE VIOLATIONS (Should be flagged)
// ============================================================

function actual_superglobal_access() {
    // This is actual $_POST access - should be flagged
    $username = $_POST['username'];
    
    // This is actual $_GET access - should be flagged
    $action = $_GET['action'];
    
    return array( $username, $action );
}

