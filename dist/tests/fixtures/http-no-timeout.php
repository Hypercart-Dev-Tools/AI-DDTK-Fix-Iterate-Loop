<?php
/**
 * Test fixture: HTTP requests without timeout
 * 
 * Expected: 4 warnings
 * - wp_remote_get without timeout
 * - wp_remote_post without timeout
 * - wp_remote_request without timeout
 * - wp_remote_head without timeout
 */

// BAD: wp_remote_get without timeout
$response = wp_remote_get('https://api.example.com/data', array(
    'headers' => array('Authorization' => 'Bearer token')
));

// BAD: wp_remote_post without timeout
$response = wp_remote_post('https://api.example.com/submit', array(
    'body' => array('key' => 'value')
));

// BAD: wp_remote_request without timeout
$response = wp_remote_request('https://api.example.com/endpoint', array(
    'method' => 'PUT'
));

// BAD: wp_remote_head without timeout
$response = wp_remote_head('https://api.example.com/check');

// GOOD: wp_remote_get WITH timeout (should not trigger)
$response = wp_remote_get('https://api.example.com/data', array(
    'timeout' => 10,
    'headers' => array('Authorization' => 'Bearer token')
));

// GOOD: wp_remote_post WITH timeout (should not trigger)
$response = wp_remote_post('https://api.example.com/submit', array(
    'timeout' => 15,
    'body' => array('key' => 'value')
));

// GOOD: Timeout on separate line (should not trigger)
$args = array(
    'headers' => array('Authorization' => 'Bearer token'),
    'timeout' => 10
);
$response = wp_remote_get('https://api.example.com/data', $args);

