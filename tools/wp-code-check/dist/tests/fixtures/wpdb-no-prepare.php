<?php
/**
 * Test Fixture: Direct Database Queries Without $wpdb->prepare()
 * 
 * This file contains examples of SQL injection vulnerabilities
 * that should be detected by the check-performance.sh script.
 * 
 * WordPress requires all database queries to use $wpdb->prepare()
 * to prevent SQL injection attacks.
 */

global $wpdb;

// ============================================================
// VIOLATIONS - These should be detected
// ============================================================

// Direct query without prepare - VIOLATION
$wpdb->query( "DELETE FROM {$wpdb->posts} WHERE ID = {$_GET['id']}" );

// get_var without prepare - VIOLATION
$count = $wpdb->get_var( "SELECT COUNT(*) FROM {$wpdb->posts} WHERE post_author = {$user_id}" );

// get_row without prepare - VIOLATION
$post = $wpdb->get_row( "SELECT * FROM {$wpdb->posts} WHERE ID = {$post_id}" );

// get_results without prepare - VIOLATION
$results = $wpdb->get_results( "SELECT * FROM {$wpdb->postmeta} WHERE post_id = {$id}" );

// get_col without prepare - VIOLATION
$ids = $wpdb->get_col( "SELECT ID FROM {$wpdb->posts} WHERE post_status = '{$status}'" );

// Complex query without prepare - VIOLATION
$wpdb->query(
    "UPDATE {$wpdb->options} 
     SET option_value = '{$value}' 
     WHERE option_name = '{$name}'"
);

// ============================================================
// VALID CODE - These should NOT be detected
// ============================================================

// Properly prepared query - VALID
$wpdb->query( $wpdb->prepare(
    "DELETE FROM {$wpdb->posts} WHERE ID = %d",
    $_GET['id']
) );

// get_var with prepare - VALID
$count = $wpdb->get_var( $wpdb->prepare(
    "SELECT COUNT(*) FROM {$wpdb->posts} WHERE post_author = %d",
    $user_id
) );

// get_row with prepare - VALID
$post = $wpdb->get_row( $wpdb->prepare(
    "SELECT * FROM {$wpdb->posts} WHERE ID = %d",
    $post_id
) );

// get_results with prepare - VALID
$results = $wpdb->get_results( $wpdb->prepare(
    "SELECT * FROM {$wpdb->postmeta} WHERE post_id = %d",
    $id
) );

// get_col with prepare - VALID
$ids = $wpdb->get_col( $wpdb->prepare(
    "SELECT ID FROM {$wpdb->posts} WHERE post_status = %s",
    $status
) );

// Complex prepared query - VALID
$wpdb->query( $wpdb->prepare(
    "UPDATE {$wpdb->options} 
     SET option_value = %s 
     WHERE option_name = %s",
    $value,
    $name
) );

// Static query without variables - VALID (no injection risk)
$wpdb->query( "DELETE FROM {$wpdb->options} WHERE option_name LIKE '_transient_%'" );

// Comment mentioning $wpdb->query - VALID (should be ignored)
// This function uses $wpdb->query to delete old data

