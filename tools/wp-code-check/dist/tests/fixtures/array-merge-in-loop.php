<?php

// Fixture: array_merge() inside loop (quadratic memory risk)

function hcc_fixture_array_merge_in_loop( array $items ) {
	$out = array();
	foreach ( $items as $item ) {
		$out = array_merge( $out, array( $item ) );
	}
	return $out;
}
