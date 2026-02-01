<?php

// Fixture: unbounded wc_get_orders() limit => -1

function hcc_fixture_unbounded_wc_get_orders( array $all_order_ids ) {
	$orders = wc_get_orders(
		array(
			'include' => $all_order_ids,
			'limit'   => -1,
			'orderby' => 'include',
		)
	);

	return $orders;
}
