<?php
/**
 * Test Fixture: WooCommerce Subscriptions Queries Without Limits
 * 
 * This file contains examples of WooCommerce Subscriptions function calls
 * that should be detected by the check-performance.sh script.
 * 
 * WooCommerce Subscriptions queries should always include a 'limit' parameter
 * to prevent performance issues with large subscription counts.
 */

// ============================================================
// VIOLATIONS - These should be detected
// ============================================================

// wcs_get_subscriptions without limit - VIOLATION
function get_all_subscriptions_bad() {
    $subscriptions = wcs_get_subscriptions( array(
        'status' => 'active'
    ) );
    return $subscriptions;
}

// wcs_get_subscriptions_for_order without limit - VIOLATION
function get_order_subscriptions_bad( $order_id ) {
    $subscriptions = wcs_get_subscriptions_for_order( $order_id );
    return $subscriptions;
}

// wcs_get_subscriptions_for_product without limit - VIOLATION
function get_product_subscriptions_bad( $product_id ) {
    $subscriptions = wcs_get_subscriptions_for_product( $product_id );
    return $subscriptions;
}

// wcs_get_subscriptions_for_user without limit - VIOLATION
function get_user_subscriptions_bad( $user_id ) {
    $subscriptions = wcs_get_subscriptions_for_user( $user_id );
    return $subscriptions;
}

// wcs_get_subscriptions with multiple args but no limit - VIOLATION
function get_filtered_subscriptions_bad() {
    $subscriptions = wcs_get_subscriptions( array(
        'status' => array( 'active', 'pending' ),
        'orderby' => 'start_date',
        'order' => 'DESC'
    ) );
    return $subscriptions;
}

// ============================================================
// VALID CODE - These should NOT be detected
// ============================================================

// wcs_get_subscriptions with limit - VALID
function get_all_subscriptions_good() {
    $subscriptions = wcs_get_subscriptions( array(
        'status' => 'active',
        'limit' => 100
    ) );
    return $subscriptions;
}

// wcs_get_subscriptions_for_order with limit - VALID
function get_order_subscriptions_good( $order_id ) {
    $subscriptions = wcs_get_subscriptions_for_order( $order_id, array(
        'limit' => 50
    ) );
    return $subscriptions;
}

// wcs_get_subscriptions_for_product with limit - VALID
function get_product_subscriptions_good( $product_id ) {
    $subscriptions = wcs_get_subscriptions_for_product( $product_id, array(
        'limit' => 100
    ) );
    return $subscriptions;
}

// wcs_get_subscriptions_for_user with limit - VALID
function get_user_subscriptions_good( $user_id ) {
    $subscriptions = wcs_get_subscriptions_for_user( $user_id, array(
        'limit' => 25
    ) );
    return $subscriptions;
}

// wcs_get_subscriptions with multiple args including limit - VALID
function get_filtered_subscriptions_good() {
    $subscriptions = wcs_get_subscriptions( array(
        'status' => array( 'active', 'pending' ),
        'orderby' => 'start_date',
        'order' => 'DESC',
        'limit' => 100
    ) );
    return $subscriptions;
}

// wcs_get_subscriptions with limit = -1 (intentional unbounded) - VALID
// This is caught by a different check (unbounded queries)
function get_all_subscriptions_unbounded() {
    $subscriptions = wcs_get_subscriptions( array(
        'limit' => -1
    ) );
    return $subscriptions;
}

// Comment mentioning wcs_get_subscriptions - VALID (should be ignored)
// This function uses wcs_get_subscriptions to retrieve subscriptions

