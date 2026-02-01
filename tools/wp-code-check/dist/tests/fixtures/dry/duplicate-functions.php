<?php
/**
 * Test Fixture: Duplicate Function Definitions
 *
 * This fixture simulates exact function clones (Type 1) scattered across
 * multiple "files" (represented as different sections in this single file).
 *
 * Expected Violations:
 * - validate_user_email() - Duplicated 3 times (should be detected)
 * - sanitize_api_key() - Duplicated 2 times (should be detected)
 * - format_phone_number() - Appears only once (should NOT be detected)
 *
 * @package WP_Code_Check
 * @subpackage Tests
 */

// ============================================================================
// "File 1" - includes/user-validation.php
// ============================================================================

/**
 * Validate user email address.
 * ❌ DUPLICATE #1 - This function is copy-pasted in 3 locations
 */
function validate_user_email($email) {
    // Check if email is empty
    if (empty($email)) {
        return false;
    }
    
    // Validate email format
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return false;
    }
    
    return true;
}

/**
 * Sanitize API key.
 * ❌ DUPLICATE #1 - This function is copy-pasted in 2 locations
 */
function sanitize_api_key($key) {
    // Remove all non-alphanumeric characters
    $clean = preg_replace('/[^a-zA-Z0-9]/', '', $key);
    
    // Convert to uppercase
    return strtoupper($clean);
}

// ============================================================================
// "File 2" - admin/settings.php
// ============================================================================

/**
 * Validate user email address.
 * ❌ DUPLICATE #2 - Exact copy of function from includes/user-validation.php
 */
function validate_user_email($email) {
    // Check if email is empty
    if (empty($email)) {
        return false;
    }
    
    // Validate email format
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return false;
    }
    
    return true;
}

/**
 * Format phone number.
 * ✅ UNIQUE - This function appears only once (should NOT be flagged)
 */
function format_phone_number($phone) {
    // Remove all non-numeric characters
    $clean = preg_replace('/[^0-9]/', '', $phone);
    
    // Format as (XXX) XXX-XXXX
    if (strlen($clean) === 10) {
        return sprintf('(%s) %s-%s', 
            substr($clean, 0, 3),
            substr($clean, 3, 3),
            substr($clean, 6, 4)
        );
    }
    
    return $phone;
}

// ============================================================================
// "File 3" - ajax/handlers.php
// ============================================================================

/**
 * Validate user email address.
 * ❌ DUPLICATE #3 - Exact copy of function from includes/user-validation.php
 */
function validate_user_email($email) {
    // Check if email is empty
    if (empty($email)) {
        return false;
    }
    
    // Validate email format
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        return false;
    }
    
    return true;
}

/**
 * Sanitize API key.
 * ❌ DUPLICATE #2 - Exact copy of function from includes/user-validation.php
 */
function sanitize_api_key($key) {
    // Remove all non-alphanumeric characters
    $clean = preg_replace('/[^a-zA-Z0-9]/', '', $key);
    
    // Convert to uppercase
    return strtoupper($clean);
}

// ============================================================================
// "File 4" - includes/helpers.php (GOOD EXAMPLE)
// ============================================================================

/**
 * ✅ GOOD EXAMPLE: This is where duplicated functions SHOULD be extracted to.
 * 
 * After refactoring, all the duplicated functions above should be moved here,
 * and the other files should require this file and use these functions.
 */

// This section intentionally left empty to show where refactored code should go

// ============================================================================
// Edge Cases (Should NOT be detected)
// ============================================================================

/**
 * Short function (< 5 lines) - Should NOT be detected due to min_lines threshold
 */
function get_plugin_version() {
    return '1.0.0';
}

/**
 * Magic method - Should be excluded by pattern config
 */
function __construct() {
    // Constructor logic
}

/**
 * Test method - Should be excluded by pattern config
 */
function test_something() {
    // Test logic
}

