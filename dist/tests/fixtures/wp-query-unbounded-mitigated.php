<?php
/**
 * Fixture: wp-query-unbounded mitigation adjustment
 *
 * This file intentionally contains an unbounded WP_Query (posts_per_page => -1)
 * but includes multiple mitigating factors within the same function.
 *
 * Expected behavior:
 * - Detection triggers for wp-query-unbounded
 * - Mitigation adjustment downgrades severity from CRITICAL -> LOW (3 mitigations)
 */

function hcc_fixture_wp_query_unbounded_mitigated() {
	// Mitigation: admin-only context
	if ( ! is_admin() ) {
		return;
	}

	// Mitigation: caching
	get_transient( 'hcc_fixture_wpq_cache_key' );

	// Unbounded query with mitigation: IDs-only return (lower memory)
	$q = new WP_Query(
		array(
			'posts_per_page' => -1,
			'fields'        => 'ids',
		)
	);

	return $q->posts;
}
