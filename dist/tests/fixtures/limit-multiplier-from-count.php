<?php

// Fixture: candidate limit multiplier derived from count()

function hcc_fixture_limit_multiplier_from_count( array $user_ids ) {
	$candidate_limit = count( $user_ids ) * 10 * 5;
	return $candidate_limit;
}
