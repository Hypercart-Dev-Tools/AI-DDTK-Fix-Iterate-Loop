/**
 * TEST FIXTURE - NOT REAL SECRETS
 *
 * This file contains FAKE API keys and tokens for testing pattern detection.
 * These are intentionally invalid and used only for testing purposes.
 *
 * DO NOT use real secrets in test files.
 */

// Test file for JavaScript pattern detection
// This should trigger the api-key-exposure pattern

// FAKE Hardcoded API key (should be detected) - NOT A REAL SECRET
const API_KEY = "sk_live_1234567890abcdef1234567890abcdef"; // FAKE TEST KEY

// FAKE NEXT_PUBLIC secret (should be detected) - NOT A REAL SECRET
const secret = process.env.NEXT_PUBLIC_API_SECRET_KEY;

// Safe public URL (should NOT be detected)
const publicUrl = process.env.NEXT_PUBLIC_WORDPRESS_URL;

// FAKE hardcoded secret (should be detected) - NOT A REAL SECRET
const TOKEN = "ghp_1234567890abcdefghijklmnopqrstuvwxyz"; // FAKE TEST TOKEN

console.log("Testing JavaScript pattern detection");

