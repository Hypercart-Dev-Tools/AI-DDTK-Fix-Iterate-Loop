<?php
/**
 * Fixture: DB queries in __construct() methods
 * 
 * These patterns run on every class instantiation, often on every page load.
 * Expected: 4 errors (lines 10, 24, 38, 52)
 */

// VIOLATION 1: get_users() in constructor
class User_Manager_Bad {
    private $total_users;
    
    public function __construct() {
        // This runs on every page load if class is instantiated early
        $this->total_users = count( get_users( array( 'role' => 'subscriber' ) ) );
    }
}

// VIOLATION 2: WP_Query in constructor
class Post_Manager_Bad {
    private $recent_posts;
    
    public function __construct() {
        // Unbounded query in constructor
        $this->recent_posts = new WP_Query( array( 'post_type' => 'post' ) );
    }
}

// VIOLATION 3: Direct $wpdb query in constructor
class Order_Manager_Bad {
    private $pending_orders;
    
    public function __construct() {
        global $wpdb;
        // Direct DB query on every instantiation
        $this->pending_orders = $wpdb->get_results( 
            "SELECT * FROM {$wpdb->prefix}posts WHERE post_status = 'pending'"
        );
    }
}

// VIOLATION 4: get_posts() in constructor
class Product_Manager_Bad {
    private $featured_products;
    
    public function __construct() {
        // This could return thousands of products
        $this->featured_products = get_posts( array(
            'post_type' => 'product',
            'meta_key' => '_featured',
            'meta_value' => 'yes'
        ) );
    }
}

// SAFE: Lazy-loaded query (not in constructor)
class User_Manager_Good {
    private $total_users = null;
    
    public function __construct() {
        // Constructor is lightweight
    }
    
    public function get_total_users() {
        if ( is_null( $this->total_users ) ) {
            // Only query when actually needed
            $this->total_users = count( get_users( array( 'role' => 'subscriber' ) ) );
        }
        return $this->total_users;
    }
}

// SAFE: Admin-only query with guard
class Dashboard_Widget_Good {
    private $stats;
    
    public function __construct() {
        // Guard prevents frontend execution
        if ( ! is_admin() ) {
            return;
        }
        
        // Only runs in admin context
        $this->stats = get_users( array( 'role' => 'pending' ) );
    }
}

