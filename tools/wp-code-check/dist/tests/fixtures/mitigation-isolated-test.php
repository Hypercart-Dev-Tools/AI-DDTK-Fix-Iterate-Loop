<?php
/**
 * Isolated test file for mitigation detection
 * Each test is in a separate file-like section with enough spacing
 */

// ============================================================================
// Test 1: Unbounded query WITHOUT mitigation (should be CRITICAL)
// ============================================================================

function test_unbounded_no_mitigation() {
    $query = new WP_Query( array(
        'post_type' => 'post',
        'posts_per_page' => -1
    ) );
    
    return $query->posts;
}

// Spacer to prevent context bleeding
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer

// ============================================================================
// Test 2: Unbounded query WITH caching mitigation (should be downgraded to HIGH)
// ============================================================================

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

// Spacer to prevent context bleeding
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer
// Spacer

// ============================================================================
// Test 3: Unbounded query WITH capability check (should be downgraded to HIGH)
// ============================================================================

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

