<?php
/**
 * Test file for mitigation detection
 * 
 * This file contains unbounded queries with various mitigating factors
 * to test the false positive reduction patterns.
 */

// ============================================================================
// Test 1: Unbounded query WITH caching (should reduce severity)
// ============================================================================
function get_all_product_variations_cached( $product_id ) {
    $cache_key = 'product_variations_' . $product_id;
    
    // Check cache first
    $cached = get_transient( $cache_key );
    if ( false !== $cached ) {
        return $cached;
    }
    
    // Unbounded query - but results are cached
    $variations = wc_get_products( array(
        'parent' => $product_id,
        'type'   => 'variation',
        'limit'  => -1,  // Unbounded - should be flagged but with reduced severity
        'return' => 'ids',
    ) );
    
    // Cache for 1 hour
    set_transient( $cache_key, $variations, HOUR_IN_SECONDS );
    
    return $variations;
}

// ============================================================================
// Test 2: Unbounded query WITH parent scoping (should reduce severity)
// ============================================================================
function get_child_pages( $parent_id ) {
    // Query is scoped to children of a single parent
    $children = get_posts( array(
        'post_type'      => 'page',
        'post_parent'    => $parent_id,  // Parent scoping
        'posts_per_page' => -1,  // Unbounded - but scoped to parent
        'orderby'        => 'menu_order',
        'order'          => 'ASC',
    ) );
    
    return $children;
}

// ============================================================================
// Test 3: Unbounded query WITH IDs only (should reduce severity)
// ============================================================================
function get_all_published_product_ids() {
    // Only fetching IDs, not full objects
    $product_ids = wc_get_products( array(
        'status' => 'publish',
        'limit'  => -1,  // Unbounded - but only IDs
        'return' => 'ids',  // IDs only - lower memory footprint
    ) );
    
    return $product_ids;
}

// ============================================================================
// Test 4: Unbounded query WITH admin context (should reduce severity)
// ============================================================================
function admin_get_all_users() {
    // Only runs in admin area
    if ( ! is_admin() ) {
        return array();
    }
    
    // Admin-only query
    $users = get_users( array(
        'orderby' => 'display_name',
        'order'   => 'ASC',
        // No limit - but admin-only
    ) );
    
    return $users;
}

// ============================================================================
// Test 5: Unbounded query WITH multiple mitigations (should reduce to LOW)
// ============================================================================
function get_all_variations_multi_mitigated( $product_id ) {
    // Admin check
    if ( ! current_user_can( 'manage_options' ) ) {
        return array();
    }
    
    $cache_key = 'admin_variations_' . $product_id;
    
    // Check cache
    $cached = wp_cache_get( $cache_key, 'products' );
    if ( false !== $cached ) {
        return $cached;
    }
    
    // Unbounded query with 3 mitigations:
    // 1. Caching (wp_cache_set below)
    // 2. Parent scoping (parent => $product_id)
    // 3. IDs only (return => 'ids')
    // 4. Admin context (current_user_can above)
    $variation_ids = wc_get_products( array(
        'parent' => $product_id,  // Parent scoping
        'type'   => 'variation',
        'limit'  => -1,  // Unbounded - but heavily mitigated
        'return' => 'ids',  // IDs only
    ) );
    
    // Cache the results
    wp_cache_set( $cache_key, $variation_ids, 'products', HOUR_IN_SECONDS );
    
    return $variation_ids;
}

// ============================================================================
// Test 6: Unbounded query WITHOUT mitigations (should be CRITICAL)
// ============================================================================
function get_all_products_no_mitigation() {
    // No caching, no scoping, no IDs-only, no admin check
    // This should remain CRITICAL severity
    $products = wc_get_products( array(
        'status' => 'publish',
        'limit'  => -1,  // Unbounded - NO mitigations
    ) );
    
    return $products;
}

// ============================================================================
// Test 7: get_users without number but WITH caching
// ============================================================================
function get_all_users_cached() {
    $cache_key = 'all_users_list';
    
    $cached = get_transient( $cache_key );
    if ( false !== $cached ) {
        return $cached;
    }
    
    // Unbounded get_users - but cached
    $users = get_users( array(
        'orderby' => 'display_name',
        'order'   => 'ASC',
        // No limit - but cached
    ) );
    
    set_transient( $cache_key, $users, DAY_IN_SECONDS );
    
    return $users;
}

