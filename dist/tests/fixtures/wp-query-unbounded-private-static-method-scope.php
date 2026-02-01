<?php
/**
 * Fixture: wp-query-unbounded private static method scope boundaries
 *
 * Purpose:
 * - Ensure function/method scope detection recognizes `private static function`.
 * - Prevent caching mitigation from leaking into a different method.
 *
 * Expected behavior:
 * - Detection triggers for wp-query-unbounded
 * - NO mitigations are detected for the unbounded query method
 * - Severity remains CRITICAL (no downgrade)
 */

class HCC_Fixture_WP_Query_Unbounded_Private_Static_Method_Scope {
	public function cached_method_unrelated() {
		// Mitigation signal (should NOT apply to the private static method below).
		get_transient( 'hcc_fixture_wpq_cache_key_public_unrelated' );

		return true;
	}

	private static function unbounded_query_private_static() {
		$q = new WP_Query(
			array(
				'posts_per_page' => -1,
			)
		);

		return $q->posts;
	}
}
