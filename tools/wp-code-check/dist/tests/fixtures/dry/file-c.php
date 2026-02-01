<?php
/**
 * Test File C - ajax/handlers.php
 */

function validate_user_email($email) {
    if (empty($email)) {
        return false;
    }
    
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return false;
    }
    
    return true;
}

function sanitize_api_key($key) {
    $clean = preg_replace('/[^a-zA-Z0-9]/', '', $key);
    return strtoupper($clean);
}

