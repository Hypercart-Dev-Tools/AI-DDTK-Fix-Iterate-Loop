<?php
/**
 * Test fixture for unvalidated cron interval detection
 *
 * Expected: 1 error (3 findings)
 * - Line 15: Direct variable multiplication without validation
 * - Line 24: get_option without absint
 * - Line 33: Settings value without validation
 */

// ANTI-PATTERN 1: Direct variable multiplication without validation
function bad_cron_interval_1() {
    $interval = get_option('my_interval', 15);
    add_filter('cron_schedules', function($schedules) use ($interval) {
        $schedules['my_schedule'] = array('interval' => $interval * 60); // ERROR: No validation
        return $schedules;
    });
}

// ANTI-PATTERN 2: Using option directly
function bad_cron_interval_2() {
    $custom_interval = get_option('custom_interval', 15);
    add_filter('cron_schedules', function($schedules) use ($custom_interval) {
        $schedules['custom'] = array('interval' => $custom_interval * MINUTE_IN_SECONDS); // ERROR: No validation
        return $schedules;
    });
}

// ANTI-PATTERN 3: Settings value without validation
function bad_cron_interval_3() {
    $interval = $this->get_setting('interval', 15);
    add_filter('cron_schedules', function($schedules) use ($interval) {
        $schedules['my_custom'] = array('interval' => $interval * 60); // ERROR: No validation
        return $schedules;
    });
}

// SAFE PATTERN 1: With absint() validation
function good_cron_interval_1() {
    $interval = absint(get_option('my_interval', 15));
    if ($interval < 1) $interval = 15;
    add_filter('cron_schedules', function($schedules) use ($interval) {
        $schedules['my_schedule'] = array('interval' => $interval * 60); // SAFE: absint used
        return $schedules;
    });
}

// SAFE PATTERN 2: With bounds checking
function good_cron_interval_2() {
    $interval = absint(get_option('custom_interval', 15));
    if ($interval < 1 || $interval > 1440) {
        $interval = 15;
    }
    add_filter('cron_schedules', function($schedules) use ($interval) {
        $schedules['custom'] = array('interval' => $interval * MINUTE_IN_SECONDS); // SAFE: bounds checked
        return $schedules;
    });
}

// SAFE PATTERN 3: Inline absint
function good_cron_interval_3() {
    $raw_interval = get_option('interval', 15);
    $interval = absint($raw_interval);
    if ($interval < 1) $interval = 15;
    add_filter('cron_schedules', function($schedules) use ($interval) {
        $schedules['validated'] = array('interval' => $interval * 60); // SAFE: validated before use
        return $schedules;
    });
}

// SAFE PATTERN 4: Hardcoded value (no variable)
function good_cron_interval_4() {
    add_filter('cron_schedules', function($schedules) {
        $schedules['fifteen_min'] = array('interval' => 15 * 60); // SAFE: hardcoded value
        return $schedules;
    });
}

