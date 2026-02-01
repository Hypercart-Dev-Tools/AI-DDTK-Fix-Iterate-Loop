<?php
/**
 * Test Fixture: Clean Code
 *
 * This file demonstrates CORRECT patterns that should PASS all checks.
 * Use these as examples of proper WordPress query handling.
 *
 * @package Neochrome\WPPerformanceTests
 */

// ============================================================
// CORRECT: Bounded Query Patterns
// ============================================================

/**
 * Correct: Explicit reasonable limit
 */
function get_recent_posts_good() {
    $args = array(
        'post_type'      => 'post',
        'posts_per_page' => 20,  // ✅ Bounded
        'post_status'    => 'publish',
    );
    return new WP_Query( $args );
}

/**
 * Correct: Using pagination
 */
function get_paginated_products_good( $page = 1 ) {
    return get_posts( array(
        'post_type'   => 'product',
        'numberposts' => 50,  // ✅ Bounded
        'paged'       => $page,
    ) );
}

/**
 * Correct: WooCommerce with explicit limit
 */
function get_recent_orders_good() {
    return wc_get_orders( array(
        'limit'   => 100,  // ✅ Bounded
        'orderby' => 'date',
        'order'   => 'DESC',
    ) );
}

/**
 * Correct: Batched processing for large datasets
 */
function process_all_posts_good() {
    $page = 1;
    $per_page = 100;
    
    do {
        $posts = get_posts( array(
            'post_type'      => 'post',
            'posts_per_page' => $per_page,  // ✅ Bounded batches
            'paged'          => $page,
            'fields'         => 'ids',  // ✅ Memory efficient
        ) );
        
        foreach ( $posts as $post_id ) {
            // Process each post
            do_something( $post_id );
        }
        
        $page++;
    } while ( count( $posts ) === $per_page );
}

// ============================================================
// CORRECT: Avoiding N+1 Patterns
// ============================================================

/**
 * Correct: Pre-fetch meta before loop
 */
function display_posts_with_meta_good( $posts ) {
    // ✅ Pre-fetch all meta in one query
    $post_ids = wp_list_pluck( $posts, 'ID' );
    update_postmeta_cache( $post_ids );
    
    foreach ( $posts as $post ) {
        // Now this uses the cache, no additional queries
        $custom_field = get_post_meta( $post->ID, 'custom_field', true );
        echo esc_html( $custom_field );
    }
}

/**
 * Correct: Batch fetch term meta
 */
function display_categories_with_meta_good( $terms ) {
    // ✅ Pre-fetch all term meta
    $term_ids = wp_list_pluck( $terms, 'term_id' );
    update_termmeta_cache( $term_ids );
    
    foreach ( $terms as $term ) {
        $icon = get_term_meta( $term->term_id, 'icon', true );
        echo '<span class="icon">' . esc_html( $icon ) . '</span>';
    }
}

// ============================================================
// CORRECT: Timezone Handling
// ============================================================

/**
 * Correct: Using time() for UTC timestamps in WC
 */
function get_recent_orders_good_tz() {
    $one_week_ago = time() - WEEK_IN_SECONDS;  // ✅ UTC consistent
    
    return wc_get_orders( array(
        'date_created' => '>' . $one_week_ago,
        'limit'        => 100,
    ) );
}

/**
 * Correct: Using WC-specific date handling
 */
function get_orders_by_date_range_good( $start, $end ) {
    return wc_get_orders( array(
        'date_created' => $start . '...' . $end,  // ✅ WC date format
        'limit'        => 500,
    ) );
}

// ============================================================
// CORRECT: Raw SQL with LIMIT
// ============================================================

/**
 * Correct: $wpdb with explicit LIMIT
 */
function get_custom_data_good() {
    global $wpdb;
    
    // ✅ Explicit LIMIT clause
    return $wpdb->get_results(
        $wpdb->prepare(
            "SELECT * FROM {$wpdb->posts} WHERE post_type = %s LIMIT %d",
            'custom_type',
            100
        )
    );
}

