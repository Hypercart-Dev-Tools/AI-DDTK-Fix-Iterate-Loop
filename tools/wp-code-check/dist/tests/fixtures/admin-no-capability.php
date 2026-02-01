<?php
/**
 * Test Fixture: Admin Functions Without Capability Checks
 * 
 * This file contains examples of admin functions and menu callbacks
 * that should be detected by the check-performance.sh script.
 * 
 * WordPress requires all admin functions to check user capabilities
 * to prevent privilege escalation attacks.
 */

// ============================================================
// VIOLATIONS - These should be detected
// ============================================================

// Admin menu callback without capability check - VIOLATION
function my_admin_page_callback() {
    // Missing: if ( ! current_user_can( 'manage_options' ) ) { return; }
    echo '<h1>Admin Page</h1>';
    update_option( 'my_setting', $_POST['value'] );
}

// add_menu_page without capability check in callback - VIOLATION
add_menu_page(
    'My Plugin',
    'My Plugin',
    'manage_options',
    'my-plugin',
    'render_admin_page_bad' // This function should have capability check
);

function render_admin_page_bad() {
    // Missing capability check
    echo '<div class="wrap">';
    echo '<h1>Settings</h1>';
    echo '</div>';
}

// add_submenu_page without capability check - VIOLATION
add_submenu_page(
    'my-plugin',
    'Settings',
    'Settings',
    'manage_options',
    'my-plugin-settings',
    'render_settings_page_bad'
);

function render_settings_page_bad() {
    // Missing capability check
    if ( isset( $_POST['submit'] ) ) {
        update_option( 'my_setting', $_POST['value'] );
    }
}

// add_options_page without capability check - VIOLATION
add_options_page(
    'My Options',
    'My Options',
    'manage_options',
    'my-options',
    'render_options_bad'
);

function render_options_bad() {
    // Missing capability check
    echo '<h1>Options</h1>';
}

// Admin action hook without capability check - VIOLATION
add_action( 'admin_init', 'handle_admin_action_bad' );

function handle_admin_action_bad() {
    // Missing capability check
    if ( isset( $_POST['action'] ) && $_POST['action'] === 'save' ) {
        update_option( 'setting', $_POST['value'] );
    }
}

// ============================================================
// VALID CODE - These should NOT be detected
// ============================================================

// Properly protected admin menu callback - VALID
function my_admin_page_callback_good() {
    if ( ! current_user_can( 'manage_options' ) ) {
        wp_die( __( 'You do not have sufficient permissions to access this page.' ) );
    }
    echo '<h1>Admin Page</h1>';
    update_option( 'my_setting', $_POST['value'] );
}

// add_menu_page with capability check in callback - VALID
add_menu_page(
    'My Plugin Good',
    'My Plugin Good',
    'manage_options',
    'my-plugin-good',
    'render_admin_page_good'
);

function render_admin_page_good() {
    if ( ! current_user_can( 'manage_options' ) ) {
        return;
    }
    echo '<div class="wrap">';
    echo '<h1>Settings</h1>';
    echo '</div>';
}

// add_submenu_page with capability check - VALID
add_submenu_page(
    'my-plugin',
    'Settings Good',
    'Settings Good',
    'manage_options',
    'my-plugin-settings-good',
    'render_settings_page_good'
);

function render_settings_page_good() {
    if ( ! current_user_can( 'manage_options' ) ) {
        wp_die( 'Unauthorized' );
    }
    if ( isset( $_POST['submit'] ) ) {
        update_option( 'my_setting', $_POST['value'] );
    }
}

// Admin action with capability check - VALID
add_action( 'admin_init', 'handle_admin_action_good' );

function handle_admin_action_good() {
    if ( ! current_user_can( 'manage_options' ) ) {
        return;
    }
    if ( isset( $_POST['action'] ) && $_POST['action'] === 'save' ) {
        update_option( 'setting', $_POST['value'] );
    }
}

// Using user_can instead of current_user_can - VALID
function check_user_capability( $user_id ) {
    if ( ! user_can( $user_id, 'edit_posts' ) ) {
        return false;
    }
    return true;
}

