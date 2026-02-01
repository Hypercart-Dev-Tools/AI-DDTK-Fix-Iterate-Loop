<?php
/**
 * Fixture: wp-query-unbounded mitigation adjustment (1 mitigation)
 *
 * This file intentionally contains an unbounded WP_Query (posts_per_page => -1)
 * but includes exactly one mitigating factor within the same function.
 *
 * Expected behavior:
 * - Detection triggers for wp-query-unbounded
 * - Mitigation adjustment downgrades severity from CRITICAL -> HIGH (1 mitigation)
 * - Detected mitigation: caching
 */

function hcc_fixture_wp_query_unbounded_mitigated_1() {
	// Mitigation: caching
	get_transient( 'hcc_fixture_wpq_cache_key_1' );

	// Unbounded query (no admin gate, no ids-only, no parent scoping)
	$q = new WP_Query(
		array(
			'posts_per_page' => -1,
		)
	);

	return $q->posts;
}
