<?php
/**
 * Test fixture: file_get_contents() with external URLs
 *
 * Expected: 4 errors
 * - Direct HTTP URL
 * - Direct HTTPS URL
 * - Variable that looks like URL ($api_url)
 * - Variable that looks like URL ($endpoint)
 */

// BAD: Direct HTTP URL
$response = file_get_contents('http://api.example.com/data');

// BAD: Direct HTTPS URL
$data = file_get_contents("https://api.example.com/endpoint");

// BAD: Variable that looks like a URL
$api_url = 'https://example.com/api';
$result = file_get_contents($api_url);

// BAD: Another URL variable pattern
$endpoint = get_option('external_endpoint');
$content = file_get_contents($endpoint);

// GOOD: Local file (should not trigger)
$local_data = file_get_contents('/var/www/data.json');

// GOOD: Relative path (should not trigger)
$template = file_get_contents('templates/email.html');

// GOOD: Using wp_remote_get instead (should not trigger)
$response = wp_remote_get('https://api.example.com/data', array(
    'timeout' => 10
));

