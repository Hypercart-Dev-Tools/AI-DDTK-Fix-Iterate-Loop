<?php

// Intentional anti-patterns for hardcoded credentials in PHP

function bad_api_key_variable() {
    // Hardcoded secret-style API key
    $api_key = 'sk_live_abc123def456ghi789';
}

function bad_secret_constant() {
    // Hardcoded secret constant
    define('API_SECRET_KEY', 'super-secret-value-xyz-123');
}

function bad_password_variable() {
    // Hardcoded password
    $password = 'admin123';
}

function bad_authorization_header() {
    // Hardcoded bearer token in Authorization header
    $headers = array(
        'Authorization' => 'Bearer sk_live_abc123def456ghi789',
    );
}

function safe_public_key_constant() {
    // This should NOT be treated as a secret (publishable key)
    define('STRIPE_PUBLISHABLE_KEY', 'pk_live_example_publishable_key');
}

