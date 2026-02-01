<?php
/**
 * Fixture: wp-query-unbounded class method scope boundaries
 *
 * Purpose:
 * - Ensure mitigation detection does NOT leak across class methods.
 * - Historically, method declarations like `public function foo()` were not
 *   treated as function boundaries by the mitigation scoper, causing caching
 *   mitigation from a nearby method to incorrectly downgrade severity.
 *
 * Expected behavior:
 * - Detection triggers for wp-query-unbounded
 * - NO mitigations are detected for the unbounded query method
 * - Severity remains CRITICAL (no downgrade)
 */

class HCC_Fixture_WP_Query_Unbounded_Class_Method_Scope {
	public function cached_method_unrelated() {
		// Mitigation signal (should NOT apply to the other method).
		get_transient( 'hcc_fixture_wpq_cache_key_unrelated' );

		return true;
	}

	public static function unbounded_query_method() {
		$q = new WP_Query(
			array(
				'posts_per_page' => -1,
			)
		);

		return $q->posts;
	}
}
