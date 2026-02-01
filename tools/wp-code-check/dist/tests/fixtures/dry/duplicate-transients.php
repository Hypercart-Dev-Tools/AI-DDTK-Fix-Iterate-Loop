<?php
/**
 * Test Fixture: Duplicate Transient Keys
 * 
 * This file simulates transient keys scattered across multiple "files"
 * (represented as functions to keep in one file for testing).
 * 
 * Expected violations:
 * - 'user_data_cache' appears in 3+ functions
 * - 'api_response_cache' appears in 3+ functions
 * 
 * @package WPCodeCheck\Tests\Fixtures\DRY
 */

// ============================================================
// VIOLATIONS - These should be detected
// ============================================================

/**
 * Simulates: includes/cache.php
 * Cache management functions
 */
function get_cached_user_data( $user_id ) {
	// ❌ VIOLATION: 'user_data_cache' (occurrence 1)
	$cache_key = 'user_data_cache_' . $user_id;
	$data = get_transient( $cache_key );
	
	if ( false === $data ) {
		$data = fetch_user_data_from_db( $user_id );
		// ❌ VIOLATION: 'user_data_cache' (occurrence 2 - set_transient)
		set_transient( $cache_key, $data, HOUR_IN_SECONDS );
	}
	
	return $data;
}

/**
 * Simulates: ajax/user-search.php
 * AJAX handler for user search
 */
function ajax_search_users() {
	$search_term = sanitize_text_field( $_GET['term'] );
	
	// ❌ VIOLATION: 'user_data_cache' (occurrence 3)
	$cache_key = 'user_data_cache_search_' . md5( $search_term );
	$results = get_transient( $cache_key );
	
	if ( false === $results ) {
		$results = search_users_in_db( $search_term );
		// ❌ VIOLATION: 'user_data_cache' (occurrence 4 - set_transient)
		set_transient( $cache_key, $results, 15 * MINUTE_IN_SECONDS );
	}
	
	wp_send_json_success( $results );
}

/**
 * Simulates: cron/cleanup.php
 * Cron job that cleans up old caches
 */
function cron_cleanup_user_cache() {
	global $wpdb;
	
	// ❌ VIOLATION: 'user_data_cache' (occurrence 5 - delete_transient)
	// Delete all user data cache transients
	$wpdb->query( "DELETE FROM {$wpdb->options} WHERE option_name LIKE '_transient_user_data_cache_%'" );
	$wpdb->query( "DELETE FROM {$wpdb->options} WHERE option_name LIKE '_transient_timeout_user_data_cache_%'" );
}

/**
 * Simulates: includes/api-client.php
 * API client with response caching
 */
function fetch_api_data( $endpoint ) {
	// ❌ VIOLATION: 'api_response_cache' (occurrence 1)
	$cache_key = 'api_response_cache_' . md5( $endpoint );
	$response = get_transient( $cache_key );
	
	if ( false === $response ) {
		$response = wp_remote_get( $endpoint );
		// ❌ VIOLATION: 'api_response_cache' (occurrence 2 - set_transient)
		set_transient( $cache_key, $response, 30 * MINUTE_IN_SECONDS );
	}
	
	return $response;
}

/**
 * Simulates: admin/dashboard.php
 * Admin dashboard widget
 */
function dashboard_widget_display() {
	// ❌ VIOLATION: 'api_response_cache' (occurrence 3)
	$cache_key = 'api_response_cache_dashboard';
	$data = get_transient( $cache_key );
	
	if ( false === $data ) {
		$data = fetch_dashboard_data();
		// ❌ VIOLATION: 'api_response_cache' (occurrence 4 - set_transient)
		set_transient( $cache_key, $data, HOUR_IN_SECONDS );
	}
	
	echo '<div class="dashboard-widget">' . esc_html( $data ) . '</div>';
}

/**
 * Simulates: includes/cache-invalidation.php
 * Cache invalidation functions
 */
function invalidate_api_cache() {
	// ❌ VIOLATION: 'api_response_cache' (occurrence 5 - delete_transient)
	delete_transient( 'api_response_cache_dashboard' );
	delete_transient( 'api_response_cache_stats' );
}

/**
 * Simulates: public/shortcodes.php
 * Shortcode with caching
 */
function shortcode_api_data( $atts ) {
	// ❌ VIOLATION: 'api_response_cache' (occurrence 6)
	$cache_key = 'api_response_cache_shortcode';
	$data = get_transient( $cache_key );
	
	if ( false === $data ) {
		$data = fetch_api_data( 'https://api.example.com/data' );
		// ❌ VIOLATION: 'api_response_cache' (occurrence 7 - set_transient)
		set_transient( $cache_key, $data, 2 * HOUR_IN_SECONDS );
	}
	
	return '<div>' . esc_html( $data ) . '</div>';
}

// ============================================================
// EXPECTED VIOLATIONS SUMMARY
// ============================================================
// 
// 1. 'user_data_cache' - 3 files, 5 occurrences
//    - get_cached_user_data (get_transient, set_transient)
//    - ajax_search_users (get_transient, set_transient)
//    - cron_cleanup_user_cache (delete via SQL - may not be detected)
// 
// 2. 'api_response_cache' - 4 files, 7 occurrences
//    - fetch_api_data (get_transient, set_transient)
//    - dashboard_widget_display (get_transient, set_transient)
//    - invalidate_api_cache (delete_transient x2)
//    - shortcode_api_data (get_transient, set_transient)
// 
// With default thresholds (min_distinct_files: 3, min_total_matches: 4):
// - 'user_data_cache' should be FLAGGED (3 files, 5 matches)
// - 'api_response_cache' should be FLAGGED (4 files, 7 matches)

