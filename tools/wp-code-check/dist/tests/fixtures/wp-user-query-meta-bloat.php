<?php

// Fixture: WP_User_Query without update_user_meta_cache => false

function hcc_fixture_wp_user_query_meta_bloat( array $user_ids ) {
	$args = array(
		'include' => $user_ids,
		'fields'  => array( 'ID', 'user_email' ),
	);

	$user_query = new WP_User_Query( $args );
	return $user_query;
}
