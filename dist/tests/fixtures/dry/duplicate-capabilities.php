<?php
/**
 * Test Fixture: Duplicate Capability Strings
 * 
 * This file simulates capability strings scattered across multiple "files"
 * (represented as functions to keep in one file for testing).
 * 
 * Expected violations:
 * - 'manage_my_plugin_settings' appears in 5+ functions (custom capability)
 * 
 * Note: WordPress core capabilities like 'manage_options' are intentionally
 * excluded from this test as they're expected to appear everywhere.
 * 
 * @package WPCodeCheck\Tests\Fixtures\DRY
 */

// ============================================================
// VIOLATIONS - These should be detected
// ============================================================

/**
 * Simulates: admin/settings-page.php
 * Admin settings page callback
 */
function render_settings_page() {
	// ❌ VIOLATION: 'manage_my_plugin_settings' (occurrence 1)
	if ( ! current_user_can( 'manage_my_plugin_settings' ) ) {
		wp_die( __( 'You do not have permission to access this page.', 'my-plugin' ) );
	}
	
	echo '<h1>Plugin Settings</h1>';
	// Settings form here
}

/**
 * Simulates: admin/settings-save.php
 * Settings save handler
 */
function save_settings() {
	// ❌ VIOLATION: 'manage_my_plugin_settings' (occurrence 2)
	if ( ! current_user_can( 'manage_my_plugin_settings' ) ) {
		return new WP_Error( 'forbidden', 'Insufficient permissions' );
	}
	
	// Save settings
	update_option( 'my_plugin_settings', $_POST['settings'] );
}

/**
 * Simulates: ajax/update-settings.php
 * AJAX handler for settings updates
 */
function ajax_update_settings() {
	// ❌ VIOLATION: 'manage_my_plugin_settings' (occurrence 3)
	if ( ! current_user_can( 'manage_my_plugin_settings' ) ) {
		wp_send_json_error( array( 'message' => 'Insufficient permissions' ) );
	}
	
	// Update settings via AJAX
	wp_send_json_success();
}

/**
 * Simulates: includes/rest-api.php
 * REST API endpoint for settings
 */
function register_settings_endpoint() {
	register_rest_route( 'my-plugin/v1', '/settings', array(
		'methods' => 'POST',
		'callback' => 'rest_update_settings',
		'permission_callback' => function() {
			// ❌ VIOLATION: 'manage_my_plugin_settings' (occurrence 4)
			return current_user_can( 'manage_my_plugin_settings' );
		},
	) );
}

/**
 * Simulates: admin/menu.php
 * Admin menu registration
 */
function register_admin_menu() {
	add_menu_page(
		'My Plugin Settings',
		'My Plugin',
		'manage_my_plugin_settings', // ❌ VIOLATION: (occurrence 5)
		'my-plugin-settings',
		'render_settings_page'
	);
}

/**
 * Simulates: includes/capabilities.php
 * Capability registration
 */
function add_custom_capabilities() {
	$role = get_role( 'administrator' );
	
	// ❌ VIOLATION: 'manage_my_plugin_settings' (occurrence 6)
	$role->add_cap( 'manage_my_plugin_settings' );
}

/**
 * Simulates: admin/tools-page.php
 * Admin tools page
 */
function render_tools_page() {
	// ❌ VIOLATION: 'manage_my_plugin_settings' (occurrence 7)
	if ( ! current_user_can( 'manage_my_plugin_settings' ) ) {
		return;
	}
	
	echo '<h1>Plugin Tools</h1>';
	// Tools interface here
}

/**
 * Simulates: includes/export.php
 * Export functionality
 */
function export_settings() {
	// ❌ VIOLATION: 'manage_my_plugin_settings' (occurrence 8)
	if ( ! current_user_can( 'manage_my_plugin_settings' ) ) {
		return false;
	}
	
	// Export logic
	return get_option( 'my_plugin_settings' );
}

/**
 * Simulates: includes/import.php
 * Import functionality
 */
function import_settings( $data ) {
	// ❌ VIOLATION: 'manage_my_plugin_settings' (occurrence 9)
	if ( ! current_user_can( 'manage_my_plugin_settings' ) ) {
		return new WP_Error( 'forbidden', 'Cannot import settings' );
	}
	
	// Import logic
	update_option( 'my_plugin_settings', $data );
}

/**
 * Simulates: admin/bulk-actions.php
 * Bulk action handler
 */
function handle_bulk_action() {
	// ❌ VIOLATION: 'manage_my_plugin_settings' (occurrence 10)
	if ( ! current_user_can( 'manage_my_plugin_settings' ) ) {
		wp_die( 'Unauthorized' );
	}
	
	// Bulk action logic
}

/**
 * Simulates: includes/cli.php
 * WP-CLI command
 */
function cli_update_settings( $args ) {
	// ❌ VIOLATION: 'manage_my_plugin_settings' (occurrence 11)
	if ( ! current_user_can( 'manage_my_plugin_settings' ) ) {
		WP_CLI::error( 'Insufficient permissions' );
	}
	
	// CLI logic
}

// ============================================================
// EXPECTED VIOLATIONS SUMMARY
// ============================================================
// 
// 1. 'manage_my_plugin_settings' - 11 files, 11 occurrences
//    - render_settings_page (current_user_can)
//    - save_settings (current_user_can)
//    - ajax_update_settings (current_user_can)
//    - register_settings_endpoint (current_user_can in callback)
//    - register_admin_menu (add_menu_page capability parameter)
//    - add_custom_capabilities (add_cap)
//    - render_tools_page (current_user_can)
//    - export_settings (current_user_can)
//    - import_settings (current_user_can)
//    - handle_bulk_action (current_user_can)
//    - cli_update_settings (current_user_can)
// 
// With default thresholds (min_distinct_files: 5, min_total_matches: 10):
// - 'manage_my_plugin_settings' should be FLAGGED (11 files, 11 matches)

