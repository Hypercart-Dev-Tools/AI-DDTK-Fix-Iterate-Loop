<?php
/**
 * Tests for the ai-ddtk/update-options ability (Phase 3).
 *
 * This file is a standalone PHP test runner — no PHPUnit required.
 * It stubs just enough of the WordPress function surface to exercise
 * the ability's logic in isolation, then runs via:
 *
 *   php test/test-update-options-ability.php
 *
 * Or inside a real WordPress site via WP-CLI eval-file:
 *
 *   wp eval-file test/test-update-options-ability.php --skip-wordpress=false
 *
 * Exit code 0 = all tests passed. Exit code 1 = one or more failures.
 */

// ---------------------------------------------------------------------------
// WordPress stubs (used when running outside WordPress)
// ---------------------------------------------------------------------------

if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', '/fake/' );

	// Simple in-memory options store used by all stubs below.
	$GLOBALS['_test_options'] = [];
	$GLOBALS['_test_current_user_id'] = 1;
	$GLOBALS['_test_current_user_can'] = true;
	$GLOBALS['_test_update_option_calls'] = [];

	// Redirect error_log() output to a temp file so audit tests can inspect it.
	$GLOBALS['_test_error_log_file'] = tempnam( sys_get_temp_dir(), 'ai_ddtk_test_' );
	ini_set( 'error_log', $GLOBALS['_test_error_log_file'] );

	function get_option( string $key, $default = false ) {
		return $GLOBALS['_test_options'][ $key ] ?? $default;
	}

	function update_option( string $key, $value, $autoload = null ): bool {
		$GLOBALS['_test_update_option_calls'][] = compact( 'key', 'value', 'autoload' );
		$changed = ( $GLOBALS['_test_options'][ $key ] ?? null ) !== $value;
		$GLOBALS['_test_options'][ $key ] = $value;
		return $changed;
	}

	function sanitize_text_field( string $str ): string {
		return trim( strip_tags( $str ) );
	}

	function current_user_can( string $cap ): bool {
		return $GLOBALS['_test_current_user_can'];
	}

	function get_current_user_id(): int {
		return $GLOBALS['_test_current_user_id'];
	}

	function apply_filters( string $hook, $value ) {
		return $value;
	}

	// Stubs for URL/theme validation used by dangerous-key value checks.
	$GLOBALS['_test_installed_themes'] = [ 'twentytwentyfive' => true, 'storefront' => true ];

	function esc_url_raw( string $url ): string {
		// Minimal stub: reject obviously invalid URLs.
		if ( ! preg_match( '#^https?://#', $url ) ) {
			return '';
		}
		return $url;
	}

	function wp_http_validate_url( string $url ) {
		return filter_var( $url, FILTER_VALIDATE_URL ) ? $url : false;
	}

	function sanitize_email( string $email ): string {
		$clean = filter_var( $email, FILTER_SANITIZE_EMAIL );
		return is_string( $clean ) ? $clean : '';
	}

	function is_email( string $email ) {
		return filter_var( $email, FILTER_VALIDATE_EMAIL ) ? $email : false;
	}

	function wp_get_themes(): array {
		$themes = [];
		foreach ( $GLOBALS['_test_installed_themes'] as $slug => $_v ) {
			$themes[ $slug ] = (object) [ 'Name' => ucfirst( $slug ) ];
		}
		return $themes;
	}

	// Load helpers & ability registration without triggering add_action.
	function _ai_ddtk_load_abilities(): void {
		// no-op: we include the file which defines the functions we need.
	}
}

// ---------------------------------------------------------------------------
// Load the ability source.
// ---------------------------------------------------------------------------

$abilities_file = __DIR__ . '/../templates/ai-ddtk-abilities.php';
if ( ! file_exists( $abilities_file ) ) {
	fwrite( STDERR, "ERROR: Cannot find $abilities_file\n" );
	exit( 1 );
}

// Stub add_action / wp_register_ability so the file loads without errors.
if ( ! function_exists( 'add_action' ) ) {
	function add_action( string $hook, callable $cb, int $prio = 10, int $args = 1 ): void {
		// Fire immediately so the closures that register abilities run.
		$cb();
	}
}

if ( ! function_exists( 'wp_register_ability' ) ) {
	// Store abilities by name so tests can call execute_callback directly.
	$GLOBALS['_registered_abilities'] = [];
	function wp_register_ability( string $name, array $def ): void {
		$GLOBALS['_registered_abilities'][ $name ] = $def;
	}
}

require_once $abilities_file;

// ---------------------------------------------------------------------------
// Tiny test harness
// ---------------------------------------------------------------------------

$pass  = 0;
$fail  = 0;
$tests = [];

function it( string $description, callable $assertion ): void {
	global $pass, $fail, $tests;
	try {
		$assertion();
		echo "\033[32m  ✓ $description\033[0m\n";
		$pass++;
	} catch ( \Throwable $e ) {
		echo "\033[31m  ✗ $description\033[0m\n";
		echo "    → " . $e->getMessage() . "\n";
		$fail++;
	}
}

function assert_true( $value, string $msg = '' ): void {
	if ( ! $value ) {
		throw new \RuntimeException( $msg ?: 'Expected true, got ' . var_export( $value, true ) );
	}
}

function assert_false( $value, string $msg = '' ): void {
	if ( $value ) {
		throw new \RuntimeException( $msg ?: 'Expected false, got ' . var_export( $value, true ) );
	}
}

function assert_equals( $expected, $actual, string $msg = '' ): void {
	if ( $expected !== $actual ) {
		throw new \RuntimeException(
			$msg ?: sprintf( 'Expected %s, got %s', var_export( $expected, true ), var_export( $actual, true ) )
		);
	}
}

function assert_contains( string $needle, string $haystack, string $msg = '' ): void {
	if ( false === strpos( $haystack, $needle ) ) {
		throw new \RuntimeException( $msg ?: "\"$needle\" not found in \"$haystack\"" );
	}
}

// Helper: get the execute_callback for the update-options ability.
function get_execute_cb(): callable {
	if ( ! isset( $GLOBALS['_registered_abilities']['ai-ddtk/update-options'] ) ) {
		throw new \RuntimeException( 'ai-ddtk/update-options ability is not registered' );
	}
	return $GLOBALS['_registered_abilities']['ai-ddtk/update-options']['execute_callback'];
}

// Helper: read all lines from the error_log temp file.
function get_error_log_lines(): array {
	$file = $GLOBALS['_test_error_log_file'];
	if ( ! file_exists( $file ) || filesize( $file ) === 0 ) {
		return [];
	}
	return array_filter( explode( "\n", file_get_contents( $file ) ) );
}

// Helper: reset in-memory state between tests.
function reset_state(): void {
	$GLOBALS['_test_options']             = [];
	$GLOBALS['_test_update_option_calls'] = [];
	// Clear the error_log temp file.
	file_put_contents( $GLOBALS['_test_error_log_file'], '' );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

echo "\nai-ddtk/update-options — unit tests\n";
echo str_repeat( '─', 50 ) . "\n";

// ── Blocklist helper ────────────────────────────────────────────────────────

echo "\n_ai_ddtk_options_blocklist()\n";

it( 'returns always_refuse list containing active_plugins', function () {
	$list = _ai_ddtk_options_blocklist();
	assert_true( in_array( 'active_plugins', $list['always_refuse'], true ) );
} );

it( 'returns always_refuse list containing active_sitewide_plugins', function () {
	$list = _ai_ddtk_options_blocklist();
	assert_true( in_array( 'active_sitewide_plugins', $list['always_refuse'], true ) );
} );

it( 'returns require_confirm list containing siteurl, home, template, stylesheet, admin_email', function () {
	$list = _ai_ddtk_options_blocklist();
	foreach ( [ 'siteurl', 'home', 'template', 'stylesheet', 'admin_email' ] as $key ) {
		assert_true( in_array( $key, $list['require_confirm'], true ), "Missing key: $key" );
	}
} );

// ── Core happy-path write ───────────────────────────────────────────────────

echo "\nHappy-path writes\n";

it( 'writes a safe key and returns changed: true', function () {
	reset_state();
	$GLOBALS['_test_options']['woocommerce_enable_reviews'] = 'no';
	$cb     = get_execute_cb();
	$result = $cb( [ 'updates' => [ 'woocommerce_enable_reviews' => 'yes' ] ] );
	assert_true( $result['success'] );
	assert_equals( 1, count( $result['results'] ) );
	assert_equals( 'woocommerce_enable_reviews', $result['results'][0]['key'] );
	assert_equals( 'no', $result['results'][0]['previous_value'] );
	assert_equals( 'yes', $result['results'][0]['new_value'] );
	assert_true( $result['results'][0]['changed'] );
} );

it( 'reports changed: false when value is identical', function () {
	reset_state();
	$GLOBALS['_test_options']['my_option'] = 'same';
	$cb     = get_execute_cb();
	$result = $cb( [ 'updates' => [ 'my_option' => 'same' ] ] );
	assert_true( $result['success'] );
	assert_false( $result['results'][0]['changed'] );
} );

it( 'writes multiple keys in one call', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates' => [
			'key_a' => 'value_a',
			'key_b' => 'value_b',
		],
	] );
	assert_true( $result['success'] );
	assert_equals( 2, count( $result['results'] ) );
} );

it( 'sets dangerous_keys_present: false for safe keys', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [ 'updates' => [ 'blogname' => 'My Site' ] ] );
	assert_false( $result['dangerous_keys_present'] );
} );

it( 'passes autoload: yes to update_option', function () {
	reset_state();
	$cb = get_execute_cb();
	$cb( [ 'updates' => [ 'my_opt' => '1' ], 'autoload' => 'yes' ] );
	$call = $GLOBALS['_test_update_option_calls'][0];
	assert_equals( true, $call['autoload'] );
} );

it( 'passes autoload: no to update_option', function () {
	reset_state();
	$cb = get_execute_cb();
	$cb( [ 'updates' => [ 'my_opt' => '1' ], 'autoload' => 'no' ] );
	$call = $GLOBALS['_test_update_option_calls'][0];
	assert_equals( false, $call['autoload'] );
} );

it( 'passes null autoload when hint is unchanged', function () {
	reset_state();
	$cb = get_execute_cb();
	$cb( [ 'updates' => [ 'my_opt' => '1' ], 'autoload' => 'unchanged' ] );
	$call = $GLOBALS['_test_update_option_calls'][0];
	assert_equals( null, $call['autoload'] );
} );

// ── Always-refused keys ─────────────────────────────────────────────────────

echo "\nAlways-refused keys\n";

it( 'refuses active_plugins even without confirm_dangerous', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [ 'updates' => [ 'active_plugins' => [] ] ] );
	assert_false( $result['success'] );
	assert_true( in_array( 'active_plugins', $result['blocked_keys'], true ) );
} );

it( 'refuses active_plugins even WITH confirm_dangerous: true', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates'           => [ 'active_plugins' => [] ],
		'confirm_dangerous' => true,
	] );
	assert_false( $result['success'] );
	assert_true( in_array( 'active_plugins', $result['blocked_keys'], true ) );
} );

it( 'refuses active_sitewide_plugins even with confirm_dangerous: true', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates'           => [ 'active_sitewide_plugins' => [] ],
		'confirm_dangerous' => true,
	] );
	assert_false( $result['success'] );
} );

it( 'does NOT call update_option when always-refused key is present', function () {
	reset_state();
	$cb = get_execute_cb();
	$cb( [ 'updates' => [ 'active_plugins' => [] ] ] );
	assert_equals( 0, count( $GLOBALS['_test_update_option_calls'] ) );
} );

it( 'error message mentions WP-CLI for active_plugins refusal', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [ 'updates' => [ 'active_plugins' => [] ] ] );
	assert_contains( 'WP-CLI', $result['error'] );
} );

// ── Require-confirm keys ────────────────────────────────────────────────────

echo "\nRequire-confirm keys\n";

it( 'blocks siteurl without confirm_dangerous and returns error', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [ 'updates' => [ 'siteurl' => 'https://new.local' ] ] );
	assert_false( $result['success'] );
	assert_true( in_array( 'siteurl', $result['blocked_keys'], true ) );
	assert_true( $result['dangerous_keys_present'] );
} );

it( 'blocks template without confirm_dangerous', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [ 'updates' => [ 'template' => 'twentytwentyfive' ] ] );
	assert_false( $result['success'] );
} );

it( 'allows siteurl WITH confirm_dangerous: true', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates'           => [ 'siteurl' => 'https://new.local' ],
		'confirm_dangerous' => true,
	] );
	assert_true( $result['success'] );
	assert_true( $result['dangerous_keys_present'] );
} );

it( 'writes siteurl to the options store when confirm_dangerous is set', function () {
	reset_state();
	$cb = get_execute_cb();
	$cb( [
		'updates'           => [ 'siteurl' => 'https://new.local' ],
		'confirm_dangerous' => true,
	] );
	assert_equals( 'https://new.local', get_option( 'siteurl' ) );
} );

it( 'logs to error_log when a require_confirm key is overridden', function () {
	reset_state();
	$cb = get_execute_cb();
	$cb( [
		'updates'           => [ 'admin_email' => 'new@example.com' ],
		'confirm_dangerous' => true,
	] );
	$lines = get_error_log_lines();
	assert_true( count( $lines ) > 0, 'Expected at least one error_log line' );
	$last = end( $lines );
	assert_contains( 'AI-DDTK', $last );
	assert_contains( 'admin_email', $last );
} );

it( 'does NOT log to error_log for safe keys', function () {
	reset_state();
	$cb = get_execute_cb();
	$cb( [ 'updates' => [ 'blogname' => 'Safe Site' ] ] );
	$lines = get_error_log_lines();
	assert_equals( 0, count( $lines ), 'Expected no error_log output for safe key' );
} );

// ── Validation ──────────────────────────────────────────────────────────────

echo "\nInput validation\n";

it( 'returns error when updates is missing', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [] );
	assert_false( $result['success'] );
	assert_true( isset( $result['error'] ) );
} );

it( 'returns error when updates is an empty array', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [ 'updates' => [] ] );
	assert_false( $result['success'] );
} );

// ── Value validation for dangerous keys ─────────────────────────────────────

echo "\nDangerous-key value validation\n";

it( 'rejects siteurl with an invalid URL even with confirm_dangerous', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates'           => [ 'siteurl' => 'not-a-url' ],
		'confirm_dangerous' => true,
	] );
	assert_false( $result['success'] );
	assert_contains( 'not a valid URL', $result['error'] );
} );

it( 'rejects home with an invalid URL even with confirm_dangerous', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates'           => [ 'home' => 'ftp://nope' ],
		'confirm_dangerous' => true,
	] );
	assert_false( $result['success'] );
	assert_contains( 'not a valid URL', $result['error'] );
} );

it( 'accepts siteurl with a valid URL and confirm_dangerous', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates'           => [ 'siteurl' => 'https://mysite.local' ],
		'confirm_dangerous' => true,
	] );
	assert_true( $result['success'] );
} );

it( 'rejects template with non-installed theme slug', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates'           => [ 'template' => 'nonexistent-theme' ],
		'confirm_dangerous' => true,
	] );
	assert_false( $result['success'] );
	assert_contains( 'does not match any installed theme', $result['error'] );
} );

it( 'accepts template with an installed theme slug', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates'           => [ 'template' => 'twentytwentyfive' ],
		'confirm_dangerous' => true,
	] );
	assert_true( $result['success'] );
} );

it( 'rejects stylesheet with non-installed theme slug', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates'           => [ 'stylesheet' => 'bad-theme' ],
		'confirm_dangerous' => true,
	] );
	assert_false( $result['success'] );
	assert_contains( 'does not match any installed theme', $result['error'] );
} );

it( 'rejects admin_email with an invalid email address', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates'           => [ 'admin_email' => 'not-an-email' ],
		'confirm_dangerous' => true,
	] );
	assert_false( $result['success'] );
	assert_contains( 'not a valid email', $result['error'] );
} );

it( 'accepts admin_email with a valid email address', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates'           => [ 'admin_email' => 'admin@example.com' ],
		'confirm_dangerous' => true,
	] );
	assert_true( $result['success'] );
} );

// ── Value redaction ─────────────────────────────────────────────────────────

echo "\nValue redaction\n";

it( 'redacts previous_value and new_value when redact_values is true', function () {
	reset_state();
	$GLOBALS['_test_options']['secret_key'] = 'sk_live_abc123';
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates'       => [ 'secret_key' => 'sk_live_xyz789' ],
		'redact_values' => true,
	] );
	assert_true( $result['success'] );
	assert_equals( '[REDACTED]', $result['results'][0]['previous_value'] );
	assert_equals( '[REDACTED]', $result['results'][0]['new_value'] );
	assert_true( $result['results'][0]['changed'] );
} );

it( 'does NOT redact values when redact_values is false', function () {
	reset_state();
	$GLOBALS['_test_options']['blogname'] = 'Old Name';
	$cb     = get_execute_cb();
	$result = $cb( [ 'updates' => [ 'blogname' => 'New Name' ] ] );
	assert_equals( 'Old Name', $result['results'][0]['previous_value'] );
	assert_equals( 'New Name', $result['results'][0]['new_value'] );
} );

it( 'still reports changed: true when redacting', function () {
	reset_state();
	$GLOBALS['_test_options']['api_key'] = 'old';
	$cb     = get_execute_cb();
	$result = $cb( [
		'updates'       => [ 'api_key' => 'new' ],
		'redact_values' => true,
	] );
	assert_true( $result['results'][0]['changed'] );
} );

// ── Post-sanitize key validation ────────────────────────────────────────────

echo "\nPost-sanitize key validation\n";

it( 'skips keys that sanitize to empty string', function () {
	reset_state();
	$cb     = get_execute_cb();
	// HTML tags sanitize to empty via strip_tags in our sanitize_text_field stub.
	$result = $cb( [ 'updates' => [ '<script>' => 'evil' ] ] );
	assert_true( $result['success'] );
	assert_equals( 0, count( $result['results'] ) );
	assert_true( in_array( '<script>', $result['skipped_keys'], true ) );
} );

it( 'processes valid keys and skips invalid ones in the same call', function () {
	reset_state();
	$cb     = get_execute_cb();
	$result = $cb( [ 'updates' => [ 'blogname' => 'Valid', '<br>' => 'invalid' ] ] );
	assert_true( $result['success'] );
	assert_equals( 1, count( $result['results'] ) );
	assert_equals( 'blogname', $result['results'][0]['key'] );
	assert_true( isset( $result['skipped_keys'] ) );
} );

// ── Summary ─────────────────────────────────────────────────────────────────

echo "\n" . str_repeat( '─', 50 ) . "\n";
$total = $pass + $fail;
echo "Results: $pass/$total passed";
if ( $fail > 0 ) {
	echo "  \033[31m($fail failed)\033[0m";
}
echo "\n\n";

// Clean up temp error_log file.
if ( file_exists( $GLOBALS['_test_error_log_file'] ) ) {
	unlink( $GLOBALS['_test_error_log_file'] );
}

exit( $fail > 0 ? 1 : 0 );
