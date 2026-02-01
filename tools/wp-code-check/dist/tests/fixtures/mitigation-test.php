<?php
/**
 * Test file for mitigation detection
 */

// Test 1: Unbounded query WITHOUT mitigation (should be CRITICAL)
function test_unbounded_no_mitigation() {
    $query = new WP_Query( array(
        'post_type' => 'post',
        'posts_per_page' => -1
    ) );
    
    return $query->posts;
}

// Test 2: Unbounded query WITH caching mitigation (should be downgraded to HIGH)
function test_unbounded_with_caching() {
    $cache_key = 'all_posts';
    $posts = get_transient( $cache_key );
    
    if ( false === $posts ) {
        $query = new WP_Query( array(
            'post_type' => 'post',
            'posts_per_page' => -1
        ) );
        $posts = $query->posts;
        set_transient( $cache_key, $posts, HOUR_IN_SECONDS );
    }
    
    return $posts;
}

// Test 3: Unbounded query WITH pagination mitigation (should be downgraded to HIGH)
function test_unbounded_with_pagination() {
    // Note: This query has posts_per_page set in the array, which mitigates the unbounded issue
    $paged = get_query_var( 'paged' ) ? get_query_var( 'paged' ) : 1;

    $query = new WP_Query( array(
        'post_type' => 'post',
        'posts_per_page' => -1,  // Unbounded, but...
        'per_page' => 50,  // ...mitigated by per_page limit
        'paged' => $paged
    ) );

    return $query->posts;
}

// Test 4: Unbounded query WITH hard cap mitigation (should be downgraded to HIGH)
function test_unbounded_with_hard_cap() {
    // Hard cap applied before query to limit results
    $limit = min( 100, 1000 );  // Hard cap detected by mitigation checker

    $query = new WP_Query( array(
        'post_type' => 'post',
        'posts_per_page' => -1
    ) );

    // Additional hard cap after query
    return array_slice( $query->posts, 0, $limit );
}

// Test 5: Unbounded query WITH capability check (should be downgraded to HIGH)
function test_unbounded_with_capability() {
    if ( ! current_user_can( 'manage_options' ) ) {
        return array();
    }
    
    $query = new WP_Query( array(
        'post_type' => 'post',
        'posts_per_page' => -1
    ) );
    
    return $query->posts;
}

