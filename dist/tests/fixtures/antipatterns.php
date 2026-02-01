<?php
/**
 * Test Fixture: Antipatterns
 *
 * This file contains intentional performance antipatterns for testing detection.
 * The check-performance.sh script should flag ALL of these.
 * It also intentionally exercises warning-level checks (timezone-sensitive code,
 * ORDER BY RAND, LIKE leading wildcards, and transients without expiration).
 *
 * @package Neochrome\WPPerformanceTests
 */

// ============================================================
// CRITICAL: Unbounded Query Patterns (should FAIL)
// ============================================================

/**
 * Antipattern 1: posts_per_page => -1
 * Risk: Memory exhaustion with large post counts
 */
function get_all_posts_bad() {
    $args = array(
        'post_type'      => 'post',
        'posts_per_page' => -1,  // 🚨 ANTIPATTERN: Unbounded
        'post_status'    => 'publish',
    );
    return new WP_Query( $args );
}

/**
 * Antipattern 2: numberposts => -1
 * Risk: Same as posts_per_page
 */
function get_all_products_bad() {
    return get_posts( array(
        'post_type'   => 'product',
        'numberposts' => -1,  // 🚨 ANTIPATTERN: Unbounded
    ) );
}

/**
 * Antipattern 3: nopaging => true
 * Risk: Disables all pagination limits
 */
function get_everything_bad() {
    $query = new WP_Query( array(
        'post_type' => 'any',
        'nopaging'  => true,  // 🚨 ANTIPATTERN: Disables limits
    ) );
    return $query->posts;
}

/**
 * Antipattern 4: WooCommerce unbounded order query
 * Risk: Memory exhaustion with large order counts
 */
function get_all_orders_bad() {
    return wc_get_orders( array(
        'limit' => -1,  // 🚨 ANTIPATTERN: Unbounded
    ) );
}

// ============================================================
// WARNING: N+1 Query Patterns (should WARN)
// ============================================================

/**
 * Antipattern 5: get_post_meta inside loop
 * Risk: N+1 queries, one per post
 */
function display_posts_with_meta_bad( $posts ) {
    foreach ( $posts as $post ) {
        // 🚨 ANTIPATTERN: N+1 - one query per iteration
        $custom_field = get_post_meta( $post->ID, 'custom_field', true );
        echo esc_html( $custom_field );
    }
}

/**
 * Antipattern 6: get_term_meta inside loop
 * Risk: N+1 queries for terms
 */
function display_categories_with_meta_bad( $terms ) {
    foreach ( $terms as $term ) {
        // 🚨 ANTIPATTERN: N+1 - one query per term
        $icon = get_term_meta( $term->term_id, 'icon', true );
        echo '<span class="icon">' . esc_html( $icon ) . '</span>';
    }
}

// ============================================================
// WARNING: Timezone Issues (should WARN)
// ============================================================

/**
 * Antipattern 7: current_time('timestamp') in WC context
 * Risk: Timezone inconsistencies in order queries
 */
function get_recent_orders_bad() {
    $one_week_ago = current_time( 'timestamp' ) - WEEK_IN_SECONDS;  // 🚨 ANTIPATTERN

    return wc_get_orders( array(
        'date_created' => '>' . $one_week_ago,
        'limit'        => 100,
    ) );
}

/**
 * Antipattern 8: date() in query context
 * Risk: Timezone inconsistencies, cache invalidation issues
 */
function get_posts_by_date_bad() {
    $today = date( 'Y-m-d' );  // 🚨 ANTIPATTERN - use gmdate() for UTC

    return new WP_Query( array(
        'post_type'      => 'post',
        'posts_per_page' => 10,
        'date_query'     => array(
            array(
                'after' => $today,
            ),
        ),
    ) );
}

/**
 * Antipattern 9: get_terms() without number parameter
 * Risk: Memory exhaustion on sites with many terms (e.g., large product catalogs)
 */
function get_all_categories_bad() {
    // 🚨 ANTIPATTERN - no 'number' limit, returns ALL terms
    return get_terms( array(
        'taxonomy'   => 'category',
        'hide_empty' => false,
    ) );
}

/**
 * GOOD: get_terms() WITH number parameter
 */
function get_categories_good() {
    return get_terms( array(
        'taxonomy'   => 'category',
        'hide_empty' => false,
        'number'     => 100,  // ✅ Bounded
    ) );
}

// ============================================================
// WARNING: Randomized Ordering (should WARN)
// ============================================================

/**
 * Antipattern 10: orderby => 'rand'
 * Risk: Full table scan + sort, extremely slow on large tables
 */
function get_random_posts_bad() {
    return new WP_Query( array(
        'post_type'      => 'post',
        'posts_per_page' => 5,
        'orderby'        => 'rand',  // 🚨 ANTIPATTERN: Full table scan
    ) );
}

/**
 * Antipattern 11: ORDER BY RAND() in raw SQL
 * Risk: Same as above, but in direct SQL
 */
function get_random_products_sql_bad() {
    global $wpdb;
    // 🚨 ANTIPATTERN: ORDER BY RAND() causes full scan
    return $wpdb->get_results( "SELECT * FROM {$wpdb->posts} WHERE post_type = 'product' ORDER BY RAND() LIMIT 5" );
}

// ============================================================
// CRITICAL: pre_get_posts Unbounded (should FAIL)
// ============================================================

/**
 * Antipattern 12: pre_get_posts setting posts_per_page to -1
 * Risk: Sitewide unbounded queries on main query
 */
add_action( 'pre_get_posts', function( $query ) {
    if ( ! is_admin() && $query->is_main_query() && is_post_type_archive( 'product' ) ) {
        // 🚨 ANTIPATTERN: Unbounded main query
        $query->set( 'posts_per_page', -1 );
    }
} );

/**
 * Antipattern 13: pre_get_posts setting nopaging to true
 * Risk: Disables pagination on main query
 */
add_action( 'pre_get_posts', function( $query ) {
    if ( $query->is_search() ) {
        // 🚨 ANTIPATTERN: Disables pagination
        $query->set( 'nopaging', true );
    }
} );

// ============================================================
// CRITICAL: Unbounded Term SQL (should FAIL)
// ============================================================

/**
 * Antipattern 14: Direct SQL on wp_terms without LIMIT
 * Risk: Memory exhaustion with many terms
 */
function get_all_terms_sql_bad() {
    global $wpdb;
    // 🚨 ANTIPATTERN: No LIMIT on terms table
    return $wpdb->get_results( "SELECT * FROM {$wpdb->terms} WHERE name LIKE '%test%'" );
}

/**
 * GOOD: Direct SQL on wp_terms WITH LIMIT
 */
function get_terms_sql_good() {
    global $wpdb;
    return $wpdb->get_results( "SELECT * FROM {$wpdb->terms} WHERE name LIKE '%test%' LIMIT 100" );
}

// ============================================================
// Edge Cases for Testing
// ============================================================

/**
 * Antipattern with different quote styles
 */
function edge_case_quotes() {
    // Double quotes
    $a = array( "posts_per_page" => -1 );

    // Single quotes
    $b = array( 'numberposts' => -1 );

    // Mixed with spaces
    $c = array(
        'nopaging'   =>   true,
    );

    return array( $a, $b, $c );
}

// ============================================================
// WARNING: Transient Abuse (should WARN)
// ============================================================

/**
 * Antipattern 15: set_transient without expiration
 * Risk: Data persists indefinitely, potential stale data and bloated options table
 */
function cache_data_without_expiration_bad() {
    $data = get_expensive_data();
    // 🚨 ANTIPATTERN: Missing third parameter (expiration)
    set_transient( 'my_cached_data', $data );
    return $data;
}

/**
 * Antipattern 16: Another transient without expiration
 * Risk: Same as above - no automatic cleanup
 */
function store_user_preferences_bad( $user_id, $prefs ) {
    // 🚨 ANTIPATTERN: Only 2 parameters, missing expiration
    set_transient( 'user_prefs_' . $user_id, $prefs );
}

/**
 * GOOD: set_transient WITH expiration
 */
function cache_data_with_expiration_good() {
    $data = get_expensive_data();
    // ✅ Has expiration (1 hour)
    set_transient( 'my_cached_data', $data, HOUR_IN_SECONDS );
    return $data;
}

// ============================================================
// WARNING: Timezone patterns WITHOUT phpcs:ignore (should WARN)
// ============================================================

/**
 * Antipattern 17: current_time without suppression comment
 * Risk: Timezone inconsistencies, should be flagged
 */
function get_timestamp_no_ignore_bad() {
    // 🚨 ANTIPATTERN: No suppression comment - should be caught
    $now = current_time( 'timestamp' );
    return $now;
}

/**
 * Antipattern 18: date() without suppression comment
 * Risk: Timezone inconsistencies, should be flagged
 */
function format_date_no_ignore_bad() {
    // 🚨 ANTIPATTERN: No suppression - should be caught
    $today = date( 'Y-m-d' );
    return $today;
}

// ============================================================
// FILTERED: Timezone patterns WITH phpcs:ignore (should NOT warn)
// ============================================================

/**
 * Documented intentional usage - should be filtered out
 */
function get_timestamp_with_ignore_ok() {
    // phpcs:ignore WordPress.DateTime.CurrentTimeTimestamp.Requested -- Intentional for local display
    $now = current_time( 'timestamp' );
    return $now;
}

/**
 * Another documented intentional usage - should be filtered out
 */
function format_date_with_ignore_ok() {
    // phpcs:ignore WordPress.DateTime.RestrictedFunctions.date_date -- Display only
    $today = date( 'Y-m-d' );
    return $today;
}

// ============================================================
// WARNING: LIKE Queries with Leading Wildcards (should WARN)
// ============================================================

/**
 * Antipattern 19: meta_query with LIKE and leading wildcard
 * Risk: Leading % prevents index use, causes full table scan
 */
function search_products_by_sku_bad( $partial_sku ) {
    return new WP_Query( array(
        'post_type'  => 'product',
        'meta_query' => array(
            array(
                'key'     => '_sku',
                // 🚨 ANTIPATTERN: Leading wildcard prevents index use
                'value'   => '%' . $partial_sku,
                'compare' => 'LIKE',
            ),
        ),
    ) );
}

/**
 * Antipattern 20: Raw SQL with LIKE '%...
 * Risk: Full table scan on large tables
 */
function search_postmeta_bad( $search_term ) {
    global $wpdb;
    // 🚨 ANTIPATTERN: LIKE with leading wildcard
    return $wpdb->get_results(
        $wpdb->prepare(
            "SELECT * FROM {$wpdb->postmeta} WHERE meta_value LIKE %s LIMIT 100",
            '%' . $search_term . '%'
        )
    );
}

/**
 * GOOD: LIKE with trailing wildcard only (can use index)
 */
function search_products_by_sku_prefix_good( $sku_prefix ) {
    return new WP_Query( array(
        'post_type'  => 'product',
        'meta_query' => array(
            array(
                'key'     => '_sku',
                'value'   => $sku_prefix . '%',  // ✅ Trailing wildcard only - can use index
                'compare' => 'LIKE',
            ),
        ),
    ) );
}

// ============================================================
// WARNING: array_merge in loop (should WARN)
// ============================================================

/**
 * Antipattern 19: array_merge in loop
 * Risk: Quadratic memory usage
 */
function merge_results_bad() {
    $result = array();
    foreach ( get_posts() as $post ) {
        $result = array_merge( $result, get_post_meta( $post->ID ) );  // 🚨 ANTIPATTERN
    }
    return $result;
}

/**
 * GOOD: array_merge outside loop
 */
function merge_results_good() {
    $chunks = array();
    foreach ( get_posts() as $post ) {
        $chunks[] = get_post_meta( $post->ID );
    }
    return array_merge( ...$chunks );  // ✓ Single merge operation
}

