<?php
/**
 * AI-DDTK Test Delays — Fixture Plugin
 *
 * Fires on any page with ?aiddtk_test_delays=1 query param, injecting
 * four distinct delay types so QM profiling can be validated:
 *
 *   1. Slow DB query   — SELECT SLEEP(N) via $wpdb
 *   2. External HTTP    — wp_remote_get() to a slow endpoint
 *   3. PHP computation  — CPU-bound loop (no I/O, pure PHP time)
 *   4. N+1 queries      — get_post_meta() in a loop (duplicate query pattern)
 *
 * Install: Copy to wp-content/mu-plugins/ai-ddtk-test-delays.php
 * Usage:   Visit any page with ?aiddtk_test_delays=1
 *          Or visit /test-delay/ (shortcode version)
 *
 * @package ai-ddtk
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Hook into template_redirect to fire delays regardless of page builder.
 * Triggered by ?aiddtk_test_delays=1 on any page.
 */
add_action( 'template_redirect', function () {
	if ( empty( $_GET['aiddtk_test_delays'] ) ) {
		return;
	}

	// Auth gate — only administrators can trigger test delays.
	// Without this, any visitor could cause slow queries and CPU load via the query param.
	if ( ! current_user_can( 'manage_options' ) ) {
		return;
	}

	// Run the delays early in the page lifecycle so QM captures everything.
	aiddtk_run_test_delays();
}, 5 );

/**
 * Also register as a shortcode for non-BB pages.
 */
add_shortcode( 'aiddtk_test_delays', function () {
	if ( ! current_user_can( 'manage_options' ) ) {
		return '';
	}
	aiddtk_run_test_delays();
	return '<p style="font-family:monospace;color:#666;">AI-DDTK test delays executed. Check QM for profiling data.</p>';
} );

function aiddtk_run_test_delays(): void {
	global $wpdb;

	// -----------------------------------------------------------------
	// 1. Slow DB query — SELECT SLEEP(0.15)
	//    QM sees this as a real query with timing and stack trace.
	// -----------------------------------------------------------------
	// phpcs:ignore WordPress.DB.DirectDatabaseQuery
	$wpdb->get_var( $wpdb->prepare( 'SELECT SLEEP(%f)', 0.15 ) );

	// -----------------------------------------------------------------
	// 2. External HTTP API call — wp_remote_get() to httpbin
	//    QM's HTTP collector captures URL, timing, and stack trace.
	// -----------------------------------------------------------------
	wp_remote_get( 'https://httpbin.org/delay/0.3', array(
		'timeout'   => 10,
		'sslverify' => false,
	) );

	// -----------------------------------------------------------------
	// 3. PHP CPU-bound loop — burns CPU time
	//    Shows up in overview.time_taken but not as a discrete collector.
	// -----------------------------------------------------------------
	$hash = '';
	for ( $i = 0; $i < 500000; $i++ ) {
		$hash = md5( $hash . $i );
	}

	// -----------------------------------------------------------------
	// 4. N+1 query pattern — fetches posts then queries meta individually.
	//    QM's dupes collector should flag repeated postmeta SELECTs.
	// -----------------------------------------------------------------
	$posts = get_posts( array( 'numberposts' => 5, 'post_type' => 'post' ) );
	foreach ( $posts as $post ) {
		get_post_meta( $post->ID, '_aiddtk_fake_meta', true );
	}
}
