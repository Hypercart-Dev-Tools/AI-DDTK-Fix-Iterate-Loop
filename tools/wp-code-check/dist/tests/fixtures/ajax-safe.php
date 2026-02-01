<?php
/**
 * Test Fixture: AJAX safe patterns
 *
 * Contains safe AJAX handlers that should NOT trigger nonce-missing
 * heuristics in the performance checker.
 */

// ============================================================
// Shared handler with wp_ajax_ and wp_ajax_nopriv_ (should PASS)
// ============================================================

add_action( 'wp_ajax_nopriv_npt_shared_action', 'npt_shared_handler' );
add_action( 'wp_ajax_npt_shared_action', 'npt_shared_handler' );

function npt_shared_handler() {
	check_ajax_referer( 'npt_shared_action', 'nonce' );
	wp_send_json_success(
		array(
			'status' => 'ok',
			'source' => 'shared',
		)
	);
}

// ============================================================
// Handler using a helper that wraps check_ajax_referer (should PASS)
// ============================================================

add_action( 'wp_ajax_npt_helper_wrapped', 'npt_helper_wrapped_handler' );

function npt_require_ajax_nonce( $action, $field = 'nonce' ) {
	check_ajax_referer( $action, $field );
}

function npt_helper_wrapped_handler() {
	npt_require_ajax_nonce( 'npt_helper_wrapped', 'nonce' );

	wp_send_json_success(
		array(
			'status' => 'ok',
			'source' => 'helper',
		)
	);
}
