<?php
/**
 * Test Fixture: N+1 Pattern - Optimized with Meta Caching
 *
 * This file contains OPTIMIZED code that uses update_meta_cache() to prevent N+1 queries.
 * The scanner should detect this as INFO (not WARNING) because meta caching is used.
 *
 * @package Neochrome\WPPerformanceTests
 */

// ============================================================
// OPTIMIZED: User Meta with Caching (should be INFO, not WARNING)
// ============================================================

/**
 * GOOD: Pre-load user meta before loop
 * Uses update_meta_cache() to load all meta in ONE query
 */
function display_users_with_meta_optimized( $users ) {
    $user_ids = wp_list_pluck( $users, 'ID' );
    
    // ✅ OPTIMIZED: Pre-load ALL user meta in ONE query
    if ( ! empty( $user_ids ) && function_exists( 'update_meta_cache' ) ) {
        update_meta_cache( 'user', $user_ids );
    }
    
    // Loop reads from cache - NO database queries!
    foreach ( $users as $user ) {
        $first_name = get_user_meta( $user->ID, 'first_name', true );
        $last_name = get_user_meta( $user->ID, 'last_name', true );
        $email = get_user_meta( $user->ID, 'billing_email', true );
        
        echo esc_html( $first_name . ' ' . $last_name . ' - ' . $email );
    }
}

/**
 * GOOD: Pre-load post meta before loop
 * Uses update_postmeta_cache() for posts
 */
function display_posts_with_meta_optimized( $posts ) {
    $post_ids = wp_list_pluck( $posts, 'ID' );
    
    // ✅ OPTIMIZED: Pre-load ALL post meta in ONE query
    if ( ! empty( $post_ids ) && function_exists( 'update_postmeta_cache' ) ) {
        update_postmeta_cache( $post_ids );
    }
    
    // Loop reads from cache - NO database queries!
    foreach ( $posts as $post ) {
        $custom_field = get_post_meta( $post->ID, 'custom_field', true );
        $price = get_post_meta( $post->ID, '_price', true );
        
        echo esc_html( $custom_field . ' - $' . $price );
    }
}

/**
 * GOOD: Pre-load term meta before loop
 * Uses update_termmeta_cache() for terms
 */
function display_terms_with_meta_optimized( $terms ) {
    $term_ids = wp_list_pluck( $terms, 'term_id' );
    
    // ✅ OPTIMIZED: Pre-load ALL term meta in ONE query
    if ( ! empty( $term_ids ) && function_exists( 'update_termmeta_cache' ) ) {
        update_termmeta_cache( $term_ids );
    }
    
    // Loop reads from cache - NO database queries!
    foreach ( $terms as $term ) {
        $icon = get_term_meta( $term->term_id, 'icon', true );
        $color = get_term_meta( $term->term_id, 'color', true );
        
        echo '<span style="color:' . esc_attr( $color ) . '">' . esc_html( $icon ) . '</span>';
    }
}

/**
 * GOOD: Real-world example from WooCommerce customer search
 * This is the pattern used in KISS Woo Fast Search plugin
 */
function search_customers_optimized( $user_ids ) {
    // ✅ OPTIMIZED: Bulk load user meta
    if ( ! empty( $user_ids ) && function_exists( 'update_meta_cache' ) ) {
        update_meta_cache( 'user', $user_ids );
    }
    
    // ✅ OPTIMIZED: Bulk load order counts (custom method)
    $order_counts = get_order_counts_for_customers( $user_ids );
    
    // ✅ OPTIMIZED: Bulk load recent orders (custom method)
    $recent_orders = get_recent_orders_for_customers( $user_ids );
    
    $results = array();
    
    // Loop uses cached data - NO queries in loop!
    foreach ( $user_ids as $user_id ) {
        $user = get_userdata( $user_id );
        
        if ( ! $user ) {
            continue;
        }
        
        // All meta reads from cache
        $first_name = get_user_meta( $user_id, 'billing_first_name', true );
        $last_name = get_user_meta( $user_id, 'billing_last_name', true );
        $billing_email = get_user_meta( $user_id, 'billing_email', true );
        
        // Order data from pre-loaded arrays
        $order_count = isset( $order_counts[ $user_id ] ) ? (int) $order_counts[ $user_id ] : 0;
        $orders_list = isset( $recent_orders[ $user_id ] ) ? $recent_orders[ $user_id ] : array();
        
        $results[] = array(
            'id'            => $user_id,
            'name'          => $first_name . ' ' . $last_name,
            'email'         => $billing_email ?: $user->user_email,
            'order_count'   => $order_count,
            'recent_orders' => $orders_list,
        );
    }
    
    return $results;
}

/**
 * Helper: Bulk load order counts (example implementation)
 */
function get_order_counts_for_customers( $user_ids ) {
    global $wpdb;
    
    if ( empty( $user_ids ) ) {
        return array();
    }
    
    $user_ids = array_map( 'intval', $user_ids );
    $placeholders = implode( ',', array_fill( 0, count( $user_ids ), '%d' ) );
    
    $query = $wpdb->prepare(
        "SELECT customer_id, COUNT(*) as total 
         FROM {$wpdb->prefix}wc_orders 
         WHERE customer_id IN ($placeholders) 
         GROUP BY customer_id",
        $user_ids
    );
    
    $rows = $wpdb->get_results( $query );
    
    $counts = array();
    foreach ( $rows as $row ) {
        $counts[ (int) $row->customer_id ] = (int) $row->total;
    }
    
    return $counts;
}

/**
 * Helper: Bulk load recent orders (example implementation)
 */
function get_recent_orders_for_customers( $user_ids ) {
    if ( empty( $user_ids ) || ! function_exists( 'wc_get_orders' ) ) {
        return array();
    }
    
    $orders = wc_get_orders( array(
        'limit'    => count( $user_ids ) * 10,
        'customer' => $user_ids,
        'orderby'  => 'date',
        'order'    => 'DESC',
    ) );
    
    $results = array();
    foreach ( $orders as $order ) {
        $customer_id = $order->get_customer_id();
        if ( ! isset( $results[ $customer_id ] ) ) {
            $results[ $customer_id ] = array();
        }
        $results[ $customer_id ][] = array(
            'id'     => $order->get_id(),
            'total'  => $order->get_total(),
            'status' => $order->get_status(),
        );
    }
    
    return $results;
}

