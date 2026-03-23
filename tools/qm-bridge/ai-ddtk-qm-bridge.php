<?php
/**
 * AI-DDTK Query Monitor Bridge
 *
 * Captures QM profiling data at shutdown and stores it in a transient,
 * then exposes a REST endpoint to retrieve it. This enables MCP tools
 * to profile any WordPress page (frontend, admin, POST) without parsing
 * QM's HTML output.
 *
 * Requires: Query Monitor plugin (active).
 * Install:  Copy to wp-content/mu-plugins/ai-ddtk-qm-bridge.php
 *
 * @package ai-ddtk
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Only activate when QM is loaded and the requesting user can view QM.
 * The profile nonce header gates which requests get captured — without it,
 * normal page loads are unaffected.
 */
add_action( 'plugins_loaded', function () {
	if ( ! class_exists( 'QM_Collectors' ) ) {
		return;
	}

	$nonce = $_SERVER['HTTP_X_AIDDTK_QM_NONCE'] ?? '';

	if ( ! $nonce || ! preg_match( '/^[a-f0-9]{16,64}$/', $nonce ) ) {
		return;
	}

	// Capture QM data at shutdown, after QM's own collectors have processed.
	// Priority 0 runs before QM's HTML dispatcher (priority 9) so the data
	// is already collected but we capture before output buffers flush.
	add_action( 'shutdown', function () use ( $nonce ) {
		if ( ! class_exists( 'QM_Dispatcher' ) || ! QM_Dispatcher::user_can_view() ) {
			return;
		}

		$collectors = QM_Collectors::init();
		$collectors->process();

		// Load raw outputters (same ones the envelope dispatcher uses).
		foreach ( (array) glob( WP_PLUGIN_DIR . '/query-monitor/output/raw/*.php' ) as $file ) {
			include_once $file;
		}

		$outputters = apply_filters( 'qm/outputter/raw', array(), $collectors );
		$data = array();

		foreach ( $outputters as $id => $output ) {
			$data[ $id ] = $output->get_output();
		}

		// Add overview data (time/memory) from the overview collector directly.
		$overview_collector = QM_Collectors::get( 'overview' );
		if ( $overview_collector ) {
			$overview_data = $overview_collector->get_data();
			$data['overview'] = array(
				'time_taken'   => round( $overview_data->time_taken ?? 0, 4 ),
				'time_limit'   => (int) ( $overview_data->time_limit ?? 0 ),
				'time_usage'   => round( $overview_data->time_usage ?? 0, 1 ),
				'memory'       => (int) ( $overview_data->memory ?? 0 ),
				'memory_limit' => (int) ( $overview_data->memory_limit ?? 0 ),
				'memory_usage' => round( $overview_data->memory_usage ?? 0, 1 ),
			);
		}

		$data['_meta'] = array(
			'nonce'      => $nonce,
			'url'        => home_url( $_SERVER['REQUEST_URI'] ?? '/' ),
			'method'     => $_SERVER['REQUEST_METHOD'] ?? 'GET',
			'status'     => http_response_code(),
			'timestamp'  => gmdate( 'c' ),
			'qm_version' => defined( 'QM_VERSION' ) ? QM_VERSION : 'unknown',
		);

		// Store for 5 minutes — long enough for the MCP handler to retrieve.
		set_transient( 'aiddtk_qm_' . $nonce, wp_json_encode( $data ), 300 );
	}, 0 );
}, 20 );

/**
 * Verify QM cookie directly — bypasses WordPress REST nonce requirement.
 *
 * Cookie-based REST auth requires X-WP-Nonce which the MCP handler can't
 * obtain without a prior authenticated request. QM's own cookie verification
 * (wp_validate_auth_cookie on the QM cookie value) is sufficient and matches
 * the same security gate QM uses for its own dispatchers.
 */
function aiddtk_qm_verify_cookie(): bool {
	if ( current_user_can( 'view_query_monitor' ) ) {
		return true;
	}

	if ( ! class_exists( 'QM_Dispatcher' ) ) {
		return false;
	}

	return QM_Dispatcher::user_can_view();
}

/**
 * REST endpoint to retrieve captured QM profile data.
 */
add_action( 'rest_api_init', function () {
	register_rest_route( 'ai-ddtk-qm/v1', '/profile/(?P<nonce>[a-f0-9]{16,64})', array(
		'methods'             => 'GET',
		'callback'            => function ( WP_REST_Request $request ) {
			$nonce = $request->get_param( 'nonce' );
			$raw   = get_transient( 'aiddtk_qm_' . $nonce );

			if ( ! $raw ) {
				return new WP_Error(
					'qm_profile_not_found',
					'No QM profile data found for this nonce. The profile may have expired or the page was not loaded with the profiling header.',
					array( 'status' => 404 )
				);
			}

			// Clean up after retrieval.
			delete_transient( 'aiddtk_qm_' . $nonce );

			$data = json_decode( $raw, true );

			if ( ! is_array( $data ) ) {
				return new WP_Error(
					'qm_profile_corrupt',
					'QM profile data could not be decoded.',
					array( 'status' => 500 )
				);
			}

			return rest_ensure_response( $data );
		},
		'permission_callback' => 'aiddtk_qm_verify_cookie',
		'args'                => array(
			'nonce' => array(
				'required'          => true,
				'validate_callback' => function ( $value ) {
					return (bool) preg_match( '/^[a-f0-9]{16,64}$/', $value );
				},
			),
		),
	) );

	// Health check endpoint — lets the MCP handler detect if the bridge is installed.
	register_rest_route( 'ai-ddtk-qm/v1', '/status', array(
		'methods'             => 'GET',
		'callback'            => function () {
			return rest_ensure_response( array(
				'active'     => class_exists( 'QM_Collectors' ),
				'qm_version' => defined( 'QM_VERSION' ) ? QM_VERSION : null,
				'bridge_version' => '1.0.0',
			) );
		},
		'permission_callback' => 'aiddtk_qm_verify_cookie',
	) );
} );
