<?php
/**
 * Test Fixture: PHP Short Tags Detection
 * 
 * This file contains examples of disallowed PHP short tags
 * that should be detected by the check-performance.sh script.
 * 
 * WordPress Coding Standards require full <?php tags for compatibility.
 */

// ============================================================
// VIOLATIONS - These should be detected
// ============================================================

// Short echo tag (<?=) - VIOLATION
<h1><?= get_bloginfo('name') ?></h1>

// Short open tag with space (<? ) - VIOLATION
<? echo 'This is not allowed'; ?>

// Another short echo tag - VIOLATION
<div class="site-title"><?= esc_html($site_title) ?></div>

// Short open tag in template - VIOLATION
<? 
  $user = wp_get_current_user();
  echo $user->display_name;
?>

// ============================================================
// VALID CODE - These should NOT be detected
// ============================================================

// Full PHP tag - VALID
<?php echo 'This is correct'; ?>

// Full PHP tag with echo - VALID
<?php echo get_bloginfo('name'); ?>

// XML declaration - VALID (should not be flagged)
<?xml version="1.0" encoding="UTF-8"?>

// Full PHP tag in template - VALID
<?php
  $user = wp_get_current_user();
  echo $user->display_name;
?>

// Full PHP tag with short syntax alternative - VALID
<?php echo esc_html($site_title); ?>

