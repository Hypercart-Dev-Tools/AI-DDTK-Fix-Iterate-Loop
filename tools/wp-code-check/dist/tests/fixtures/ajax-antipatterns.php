<?php
/**
 * Test Fixture: AJAX and REST Antipatterns
 *
 * Contains intentionally unsafe AJAX/REST patterns for detection.
 *
 * @package Neochrome\WPPerformanceTests
 */

// ============================================================
// REST: Missing pagination/limits (should FAIL)
// ============================================================

add_action( 'rest_api_init', function() {
	// 🚨 ANTIPATTERN: No per_page/limit guard
	register_rest_route(
		'toolkit/v1',
		'/products',
		array(
			'methods'  => WP_REST_Server::READABLE,
			'callback' => function ( WP_REST_Request $request ) {
				// Intentional unbounded query to simulate load
				return new WP_Query(
					array(
						'post_type' => 'product',
					)
				);
			},
		)
	);
} );

// ============================================================
// wp_ajax: Missing nonce validation (should FAIL)
// ============================================================

add_action( 'wp_ajax_nopriv_npt_load_feed', 'npt_load_feed_no_nonce' );
add_action( 'wp_ajax_npt_load_feed', 'npt_load_feed_no_nonce' );

function npt_load_feed_no_nonce() {
	// 🚨 ANTIPATTERN: No check_ajax_referer/wp_verify_nonce
	$feed = wp_remote_get( 'https://example.com/feed' );
	wp_send_json( $feed );
}

// ============================================================
// SAFE EXAMPLE: Nonce is present (should NOT fail)
// ============================================================

add_action( 'wp_ajax_npt_secure_action', 'npt_secure_action' );

function npt_secure_action() {
	check_ajax_referer( 'npt_nonce', 'nonce' );
	wp_send_json_success( array( 'status' => 'ok' ) );
}
