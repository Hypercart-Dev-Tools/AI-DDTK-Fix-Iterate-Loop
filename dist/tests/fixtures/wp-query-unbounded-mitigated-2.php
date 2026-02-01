<?php
/**
 * Fixture: wp-query-unbounded mitigation adjustment (2 mitigations)
 *
 * This file intentionally contains an unbounded WP_Query (posts_per_page => -1)
 * but includes exactly two mitigating factors within the same function.
 *
 * Expected behavior:
 * - Detection triggers for wp-query-unbounded
 * - Mitigation adjustment downgrades severity from CRITICAL -> MEDIUM (2 mitigations)
 * - Detected mitigations: caching, admin-only
 */

function hcc_fixture_wp_query_unbounded_mitigated_2() {
	// Mitigation: admin-only context
	if ( ! is_admin() ) {
		return;
	}

	// Mitigation: caching
	get_transient( 'hcc_fixture_wpq_cache_key_2' );

	// Unbounded query (no ids-only, no parent scoping)
	$q = new WP_Query(
		array(
			'posts_per_page' => -1,
		)
	);

	return $q->posts;
}
