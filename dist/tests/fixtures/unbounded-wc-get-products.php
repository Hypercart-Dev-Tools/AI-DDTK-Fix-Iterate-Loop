<?php

// Fixture: unbounded wc_get_products() limit => -1

function hcc_fixture_unbounded_wc_get_products( array $product_ids ) {
	$products = wc_get_products(
		array(
			'include' => $product_ids,
			'limit'   => -1,
		)
	);

	return $products;
}
