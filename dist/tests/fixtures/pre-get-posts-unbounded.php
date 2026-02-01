<?php
/**
 * Test Fixture: pre_get_posts unbounded queries
 *
 * This file tests detection of pre_get_posts hooks that set unbounded queries.
 *
 * Expected detections:
 * - Line 12: pre_get_posts with posts_per_page => -1 (CRITICAL)
 * - Line 24: pre_get_posts with nopaging => true (CRITICAL)
 */

// BAD: Unbounded query via posts_per_page => -1
add_action( 'pre_get_posts', 'hcc_fixture_unbounded_posts_per_page' );
function hcc_fixture_unbounded_posts_per_page( $query ) {
	// This will load ALL posts on every query - catastrophic!
	$query->set( 'posts_per_page', -1 );
}

// BAD: Unbounded query via nopaging => true
add_filter( 'pre_get_posts', 'hcc_fixture_unbounded_nopaging' );
function hcc_fixture_unbounded_nopaging( $query ) {
	// This disables pagination entirely
	$query->set( 'nopaging', true );
}

// GOOD: Bounded query with conditional logic
add_action( 'pre_get_posts', 'hcc_fixture_bounded_query' );
function hcc_fixture_bounded_query( $query ) {
	// Only modify main query on frontend
	if ( is_admin() || ! $query->is_main_query() ) {
		return;
	}

	// Use reasonable limit
	if ( is_post_type_archive( 'product' ) ) {
		$query->set( 'posts_per_page', 24 );
	}
}

// GOOD: Conditional unbounded query (admin-only context)
add_action( 'pre_get_posts', 'hcc_fixture_admin_unbounded' );
function hcc_fixture_admin_unbounded( $query ) {
	// Only in admin - less risky but still not ideal
	if ( ! is_admin() ) {
		return;
	}

	// This is still risky but limited to admin context
	$query->set( 'posts_per_page', -1 );
}

