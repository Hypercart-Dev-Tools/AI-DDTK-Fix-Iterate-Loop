<?php
/**
 * Test File B - admin/settings.php
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

function format_phone_number($phone) {
    $clean = preg_replace('/[^0-9]/', '', $phone);
    
    if (strlen($clean) === 10) {
        return sprintf('(%s) %s-%s', 
            substr($clean, 0, 3),
            substr($clean, 3, 3),
            substr($clean, 6, 4)
        );
    }
    
    return $phone;
}

