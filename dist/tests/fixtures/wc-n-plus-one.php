<?php
/**
 * Test Fixture: WooCommerce N+1 Query Patterns
 * 
 * This file contains examples of WooCommerce-specific N+1 query patterns
 * that should be detected by the check-performance.sh script.
 * 
 * N+1 patterns occur when you loop over a collection and make additional
 * database queries for each item in the loop, causing query multiplication.
 */

// ============================================================
// VIOLATIONS - These should be detected
// ============================================================

// N+1: wc_get_order in loop over order IDs - VIOLATION
function process_orders_bad( $order_ids ) {
    foreach ( $order_ids as $order_id ) {
        $order = wc_get_order( $order_id ); // N+1: Fetches order for each ID
        $total = $order->get_total();
        echo "Order #$order_id: $total";
    }
}

// N+1: get_post_meta in loop over WC orders - VIOLATION
function get_order_custom_fields_bad() {
    $orders = wc_get_orders( array( 'limit' => 100 ) );
    foreach ( $orders as $order ) {
        $custom_field = get_post_meta( $order->get_id(), '_custom_field', true ); // N+1
        $tracking = get_post_meta( $order->get_id(), '_tracking_number', true ); // N+1
        echo "Order has tracking: $tracking";
    }
}

// N+1: wc_get_product in loop - VIOLATION
function display_product_details_bad( $product_ids ) {
    foreach ( $product_ids as $product_id ) {
        $product = wc_get_product( $product_id ); // N+1: Fetches product for each ID
        echo $product->get_name();
        echo $product->get_price();
    }
}

// N+1: ->get_meta() in loop over orders - VIOLATION
function export_order_metadata_bad() {
    $orders = wc_get_orders( array( 'limit' => 50 ) );
    foreach ( $orders as $order ) {
        $gift_message = $order->get_meta( '_gift_message' ); // N+1
        $delivery_date = $order->get_meta( '_delivery_date' ); // N+1
        echo "Gift: $gift_message, Delivery: $delivery_date";
    }
}

// N+1: get_user_meta in loop over orders - VIOLATION
function get_customer_preferences_bad() {
    $orders = wc_get_orders( array( 'limit' => 100 ) );
    foreach ( $orders as $order ) {
        $customer_id = $order->get_customer_id();
        $preference = get_user_meta( $customer_id, 'newsletter_preference', true ); // N+1
        echo "Customer $customer_id prefers: $preference";
    }
}

// N+1: Multiple meta queries in loop - VIOLATION
function generate_order_report_bad() {
    $orders = wc_get_orders( array( 'limit' => 200 ) );
    $report = array();
    
    foreach ( $orders as $order ) {
        $order_id = $order->get_id();
        $report[] = array(
            'id' => $order_id,
            'tracking' => get_post_meta( $order_id, '_tracking_number', true ), // N+1
            'gift_wrap' => get_post_meta( $order_id, '_gift_wrap', true ), // N+1
            'delivery_notes' => get_post_meta( $order_id, '_delivery_notes', true ), // N+1
        );
    }
    
    return $report;
}

// N+1: while loop with wc_get_order - VIOLATION
function process_pending_orders_bad() {
    $order_ids = get_posts( array(
        'post_type' => 'shop_order',
        'post_status' => 'wc-pending',
        'fields' => 'ids',
        'posts_per_page' => 50
    ) );
    
    $i = 0;
    while ( $i < count( $order_ids ) ) {
        $order = wc_get_order( $order_ids[$i] ); // N+1
        $order->update_status( 'processing' );
        $i++;
    }
}

// ============================================================
// VALID CODE - These should NOT be detected
// ============================================================

// Using WC_Order objects directly (no N+1) - VALID
function process_orders_good() {
    $orders = wc_get_orders( array( 'limit' => 100 ) );
    foreach ( $orders as $order ) {
        // $order is already a WC_Order object, no additional query
        $total = $order->get_total();
        echo "Order total: $total";
    }
}

// Pre-fetching meta before loop - VALID
function get_order_custom_fields_good() {
    $orders = wc_get_orders( array( 'limit' => 100 ) );
    
    // Pre-fetch all meta in one query
    $order_ids = wp_list_pluck( $orders, 'id' );
    update_meta_cache( 'post', $order_ids );
    
    foreach ( $orders as $order ) {
        // Meta is now cached, no additional queries
        $custom_field = $order->get_meta( '_custom_field' );
        echo "Custom field: $custom_field";
    }
}

// Using WC built-in methods (optimized) - VALID
function display_product_details_good() {
    $products = wc_get_products( array( 'limit' => 100 ) );
    foreach ( $products as $product ) {
        // $product is already a WC_Product object
        echo $product->get_name();
        echo $product->get_price();
    }
}

// Batch processing with proper caching - VALID
function export_order_metadata_good() {
    $orders = wc_get_orders( array( 'limit' => 50 ) );
    
    // Prime the meta cache
    $order_ids = array_map( function( $order ) { return $order->get_id(); }, $orders );
    update_meta_cache( 'post', $order_ids );
    
    foreach ( $orders as $order ) {
        $gift_message = $order->get_meta( '_gift_message' );
        $delivery_date = $order->get_meta( '_delivery_date' );
        echo "Gift: $gift_message, Delivery: $delivery_date";
    }
}

