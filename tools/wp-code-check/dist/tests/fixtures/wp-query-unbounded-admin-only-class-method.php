<?php
/**
 * Fixture: wp-query-unbounded admin-only mitigation in class method
 *
 * Purpose:
 * - Ensure admin-only mitigation is detected within a class method scope.
 * - Ensure mitigation logic does NOT require free functions.
 *
 * Expected behavior:
 * - Detection triggers for wp-query-unbounded
 * - Detected mitigation: admin-only
 * - Severity is downgraded from CRITICAL -> HIGH (1 mitigation)
 */

class HCC_Fixture_WP_Query_Unbounded_Admin_Only_Class_Method {
	public function unbounded_query_admin_only() {
		// Mitigation: admin-only context
		if ( ! is_admin() ) {
			return array();
		}

		$q = new WP_Query(
			array(
				'posts_per_page' => -1,
			)
		);

		return $q->posts;
	}
}
