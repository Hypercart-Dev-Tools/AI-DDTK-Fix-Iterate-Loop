<?php
/**
 * Test Fixture: Duplicate Option Names
 * 
 * This file simulates option names scattered across multiple "files"
 * (represented as functions to keep in one file for testing).
 * 
 * Expected violations:
 * - 'my_plugin_api_key' appears in 3+ functions (admin, api, cron)
 * - 'my_plugin_cache_ttl' appears in 2+ functions (cron, ajax)
 * - 'my_plugin_debug_mode' appears in 2+ functions (admin, ajax)
 * 
 * @package WPCodeCheck\Tests\Fixtures\DRY
 */

// ============================================================
// VIOLATIONS - These should be detected
// ============================================================

/**
 * Simulates: admin/settings.php
 * Admin settings page that reads multiple options
 */
function admin_settings_page() {
	// ❌ VIOLATION: 'my_plugin_api_key' (occurrence 1)
	$api_key = get_option( 'my_plugin_api_key' );
	
	// ❌ VIOLATION: 'my_plugin_debug_mode' (occurrence 1)
	$debug = get_option( 'my_plugin_debug_mode' );
	
	// ❌ VIOLATION: 'my_plugin_email_notifications' (occurrence 1)
	$email_enabled = get_option( 'my_plugin_email_notifications' );
	
	echo '<h1>Settings</h1>';
	echo '<p>API Key: ' . esc_html( $api_key ) . '</p>';
	echo '<p>Debug: ' . ( $debug ? 'On' : 'Off' ) . '</p>';
}

/**
 * Simulates: includes/api-client.php
 * API client that needs the API key
 */
function api_client_init() {
	// ❌ VIOLATION: 'my_plugin_api_key' (occurrence 2)
	$api_key = get_option( 'my_plugin_api_key' );
	
	if ( empty( $api_key ) ) {
		return new WP_Error( 'no_api_key', 'API key not configured' );
	}
	
	return new My_Plugin_API_Client( $api_key );
}

/**
 * Simulates: cron/sync-data.php
 * Cron job that syncs data using API
 */
function cron_sync_data() {
	// ❌ VIOLATION: 'my_plugin_api_key' (occurrence 3)
	$api_key = get_option( 'my_plugin_api_key' );
	
	// ❌ VIOLATION: 'my_plugin_cache_ttl' (occurrence 1)
	$cache_ttl = get_option( 'my_plugin_cache_ttl', 3600 );
	
	// ❌ VIOLATION: 'my_plugin_sync_interval' (occurrence 1)
	$sync_interval = get_option( 'my_plugin_sync_interval', 'hourly' );
	
	// Sync logic here
	$data = fetch_remote_data( $api_key );
	cache_data( $data, $cache_ttl );
}

/**
 * Simulates: ajax/handlers.php
 * AJAX handler that checks settings
 */
function ajax_get_settings() {
	// ❌ VIOLATION: 'my_plugin_debug_mode' (occurrence 2)
	$debug = get_option( 'my_plugin_debug_mode' );
	
	// ❌ VIOLATION: 'my_plugin_cache_ttl' (occurrence 2)
	$cache_ttl = get_option( 'my_plugin_cache_ttl', 3600 );
	
	// ❌ VIOLATION: 'my_plugin_email_notifications' (occurrence 2)
	$email_enabled = get_option( 'my_plugin_email_notifications' );
	
	wp_send_json_success( array(
		'debug' => $debug,
		'cache_ttl' => $cache_ttl,
		'email_enabled' => $email_enabled,
	) );
}

/**
 * Simulates: public/shortcodes.php
 * Shortcode that displays data
 */
function shortcode_display_data( $atts ) {
	// ❌ VIOLATION: 'my_plugin_api_key' (occurrence 4)
	$api_key = get_option( 'my_plugin_api_key' );
	
	if ( empty( $api_key ) ) {
		return '<p>Plugin not configured</p>';
	}
	
	// Display logic here
	return '<div class="my-plugin-data">Data here</div>';
}

/**
 * Simulates: includes/cache.php
 * Cache management functions
 */
function clear_plugin_cache() {
	// ❌ VIOLATION: 'my_plugin_cache_ttl' (occurrence 3)
	$cache_ttl = get_option( 'my_plugin_cache_ttl', 3600 );
	
	// Clear cache logic
	delete_transient( 'my_plugin_data_cache' );
}

/**
 * Simulates: admin/settings-save.php
 * Settings save handler
 */
function save_plugin_settings() {
	// ❌ VIOLATION: 'my_plugin_api_key' (occurrence 5 - update_option)
	update_option( 'my_plugin_api_key', sanitize_text_field( $_POST['api_key'] ) );
	
	// ❌ VIOLATION: 'my_plugin_debug_mode' (occurrence 3 - update_option)
	update_option( 'my_plugin_debug_mode', isset( $_POST['debug'] ) );
	
	// ❌ VIOLATION: 'my_plugin_cache_ttl' (occurrence 4 - update_option)
	update_option( 'my_plugin_cache_ttl', absint( $_POST['cache_ttl'] ) );
}

// ============================================================
// EXPECTED VIOLATIONS SUMMARY
// ============================================================
// 
// 1. 'my_plugin_api_key' - 5 files, 5 occurrences
//    - admin_settings_page (get_option)
//    - api_client_init (get_option)
//    - cron_sync_data (get_option)
//    - shortcode_display_data (get_option)
//    - save_plugin_settings (update_option)
// 
// 2. 'my_plugin_cache_ttl' - 4 files, 4 occurrences
//    - cron_sync_data (get_option)
//    - ajax_get_settings (get_option)
//    - clear_plugin_cache (get_option)
//    - save_plugin_settings (update_option)
// 
// 3. 'my_plugin_debug_mode' - 3 files, 3 occurrences
//    - admin_settings_page (get_option)
//    - ajax_get_settings (get_option)
//    - save_plugin_settings (update_option)
// 
// With default thresholds (min_distinct_files: 3, min_total_matches: 6):
// - 'my_plugin_api_key' should be FLAGGED (5 files, 5 matches - meets file threshold but not match threshold)
// - 'my_plugin_cache_ttl' should be FLAGGED (4 files, 4 matches - meets file threshold but not match threshold)
// - 'my_plugin_debug_mode' should be FLAGGED (3 files, 3 matches - meets file threshold but not match threshold)
//
// Note: Thresholds may need adjustment based on real-world testing

