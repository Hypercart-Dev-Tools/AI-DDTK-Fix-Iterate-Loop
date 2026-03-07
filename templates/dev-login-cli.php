<?php
/**
 * Plugin Name: Dev Login CLI
 * Description: WP-CLI command that generates one-time admin login URLs for local/dev use.
 *              Designed for AI agent workflows (Playwright, headless browser automation).
 *              Part of AI-DDTK: https://github.com/Hypercart-Dev-Tools/AI-DDTK
 *
 * Installation: Copy this file to wp-content/mu-plugins/dev-login-cli.php
 *
 * Usage:
 *   wp dev login                          # Login URL for 'admin' user
 *   wp dev login --user=editor            # Login URL for specific user
 *   wp dev login --format=url             # Output only the URL (for scripting)
 *   wp dev login --redirect=/wp-admin/site-editor.php
 *
 * Safety:
 *   - One-time token (deleted after use)
 *   - Expires after 5 minutes
 *   - Disabled in production environments
 *   - Restricted to non-production hosts by default
 *   - Limited to users with edit_posts capability
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Host allowlist — restricts login to known local/dev hosts.
 * Customize this array for your environment.
 */
function _dev_login_allowed_hosts() {
	return apply_filters( 'dev_login_allowed_hosts', [
		'localhost',
		'127.0.0.1',
		'::1',
	] );
}

/**
 * Check if the current host is in the allowlist.
 * Accepts any *.local TLD automatically.
 */
function _dev_login_host_allowed() {
	$host = wp_parse_url( home_url( '/' ), PHP_URL_HOST );

	if ( in_array( $host, _dev_login_allowed_hosts(), true ) ) {
		return true;
	}

	// Allow any .local TLD (e.g., my-site.local) — PHP 7 compatible
	if ( $host && substr( $host, -6 ) === '.local' ) {
		return true;
	}

	return false;
}

/**
 * Handle incoming one-time login requests.
 */
add_action( 'init', function () {
	if ( empty( $_GET['dev_login'] ) || empty( $_GET['u'] ) || empty( $_GET['t'] ) ) {
		return;
	}

	$env = wp_get_environment_type();
	if ( ! $env || $env === 'production' ) {
		wp_die( 'Dev login is disabled in production environments.' );
	}

	if ( ! _dev_login_host_allowed() ) {
		wp_die( 'Dev login is not allowed on this host.' );
	}

	$user_id = absint( $_GET['u'] );
	$token   = sanitize_text_field( wp_unslash( $_GET['t'] ) );
	$key     = 'dev_login_' . $user_id;
	$saved   = get_transient( $key );

	if ( ! $saved || ! hash_equals( $saved, $token ) ) {
		wp_die( 'Invalid or expired login link.' );
	}

	delete_transient( $key );

	$user = get_user_by( 'id', $user_id );
	if ( ! $user || ! user_can( $user, 'edit_posts' ) ) {
		wp_die( 'Invalid user.' );
	}

	wp_set_current_user( $user->ID );
	wp_set_auth_cookie( $user->ID, true, is_ssl() );

	$redirect = admin_url();
	if ( ! empty( $_GET['redirect'] ) ) {
		$redirect = home_url( sanitize_text_field( wp_unslash( $_GET['redirect'] ) ) );
	}

	wp_safe_redirect( $redirect );
	exit;
} );

/**
 * WP-CLI: wp dev login
 */
if ( defined( 'WP_CLI' ) && WP_CLI ) {
	WP_CLI::add_command( 'dev login', function ( $args, $assoc_args ) {
		$env = wp_get_environment_type();
		if ( ! $env || $env === 'production' ) {
			WP_CLI::error( 'Refusing to run in production.' );
		}

		if ( ! _dev_login_host_allowed() ) {
			WP_CLI::error( 'Dev login is not allowed on this host. Check dev_login_allowed_hosts filter.' );
		}

		$login = $assoc_args['user'] ?? 'admin';
		$user  = get_user_by( 'login', $login );

		if ( ! $user ) {
			WP_CLI::error( "User '{$login}' not found." );
		}

		$token = wp_generate_password( 48, false, false );
		set_transient( 'dev_login_' . $user->ID, $token, 5 * MINUTE_IN_SECONDS );

		$query = [
			'dev_login' => 1,
			'u'         => $user->ID,
			't'         => $token,
		];

		if ( ! empty( $assoc_args['redirect'] ) ) {
			$query['redirect'] = $assoc_args['redirect'];
		}

		$url = add_query_arg( $query, home_url( '/' ) );

		$format = $assoc_args['format'] ?? 'default';

		if ( $format === 'url' ) {
			WP_CLI::line( $url );
		} else {
			WP_CLI::success( 'One-time login URL (valid for 5 minutes):' );
			WP_CLI::line( $url );
		}
	} );
}
