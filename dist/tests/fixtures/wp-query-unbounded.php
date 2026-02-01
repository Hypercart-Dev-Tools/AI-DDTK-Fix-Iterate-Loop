<?php

// Fixture: unbounded WP_Query / get_posts

function hcc_fixture_unbounded_wp_query() {
	$q = new WP_Query(
		array(
			'post_type'      => 'post',
			'posts_per_page' => -1,
		)
	);

	return $q;
}

function hcc_fixture_unbounded_get_posts() {
	$posts = get_posts(
		array(
			'numberposts' => -1,
		)
	);

	return $posts;
}
