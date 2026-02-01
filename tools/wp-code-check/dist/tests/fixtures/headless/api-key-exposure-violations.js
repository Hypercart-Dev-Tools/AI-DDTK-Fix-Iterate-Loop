/**
 * Test Fixture: HWP-001 - API Key Exposure in Client-Side Code
 * 
 * Pattern: headless-api-key-exposure
 * Severity: CRITICAL
 * 
 * Expected Violations: 10
 * Expected Safe Patterns: 4
 * 
 * Context: In headless WordPress (Next.js, Nuxt, etc.), any code in client
 * bundles is visible to users via browser DevTools. API keys, secrets, and
 * tokens must NEVER be in client-side code.
 */

// =============================================================================
// VIOLATIONS - These should ALL be flagged by the scanner
// =============================================================================

// VIOLATION 1: Hardcoded API key
const WORDPRESS_API_KEY = 'sk_live_abc123def456ghi789';

// VIOLATION 2: Hardcoded secret
const API_SECRET = 'super_secret_value_12345';

// VIOLATION 3: Hardcoded token
const AUTH_TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.secret';

// VIOLATION 4: NEXT_PUBLIC_ with sensitive name (exposed to browser)
const wpKey = process.env.NEXT_PUBLIC_WP_API_KEY;

// VIOLATION 5: NEXT_PUBLIC_ with SECRET in name
const secret = process.env.NEXT_PUBLIC_SECRET_KEY;

// VIOLATION 6: NEXT_PUBLIC_ with TOKEN
const token = process.env.NEXT_PUBLIC_AUTH_TOKEN;

// VIOLATION 7: NEXT_PUBLIC_ with PASSWORD
const dbPass = process.env.NEXT_PUBLIC_DB_PASSWORD;

// VIOLATION 8: Nuxt public runtime config with secret
const nuxtSecret = process.env.NUXT_PUBLIC_API_SECRET;

// VIOLATION 9: Vite exposed secret
const viteKey = import.meta.env.VITE_SECRET_KEY;

// VIOLATION 10: Hardcoded in fetch header
fetch('/api/data', {
  headers: {
    'Authorization': 'Bearer sk_test_hardcoded_token_12345',
    'X-API-Key': 'hardcoded_api_key_value'
  }
});

// =============================================================================
// SAFE PATTERNS - These should NOT be flagged
// =============================================================================

// SAFE 1: Server-only environment variable (no NEXT_PUBLIC_ prefix)
const serverOnlyKey = process.env.WP_API_KEY;  // Only accessible on server

// SAFE 2: NEXT_PUBLIC_ with non-sensitive value
const publicUrl = process.env.NEXT_PUBLIC_WORDPRESS_URL;  // URL is fine to expose

// SAFE 3: NEXT_PUBLIC_ with non-sensitive config
const publicSiteId = process.env.NEXT_PUBLIC_SITE_ID;  // ID is fine to expose

// SAFE 4: Dynamic authorization from secure source
async function fetchWithAuth() {
  const token = await getTokenFromSecureStorage();  // Token fetched at runtime
  return fetch('/api/data', {
    headers: { 'Authorization': `Bearer ${token}` }
  });
}

// SAFE 5: Reference to key without actual value
const keyName = 'API_KEY';  // Just a string, not an actual key

// =============================================================================
// EDGE CASES
// =============================================================================

// EDGE 1: Comment with API key (should NOT be flagged)
// API_KEY = 'abc123';  // Example in documentation

// EDGE 2: Variable name contains KEY but value is safe
const PRIMARY_KEY = 'id';  // Database column name, not an API key

// EDGE 3: Encrypted/hashed value (may be flagged - context dependent)
const hashedKey = 'sha256:a1b2c3d4e5f6...';

// EDGE 4: Public API key that's meant to be exposed (may be flagged)
const STRIPE_PUBLIC_KEY = 'pk_test_abc123';  // Stripe publishable keys ARE public

// =============================================================================
// REAL-WORLD VULNERABLE PATTERNS
// =============================================================================

// Pattern seen in leaked Next.js apps
export const config = {
  wordpress: {
    apiKey: 'wp_key_12345abcdef',  // CRITICAL: Exposed in client bundle
    graphqlEndpoint: process.env.NEXT_PUBLIC_GRAPHQL_URL
  }
};

// Pattern seen in misconfigured Nuxt apps
const runtimeConfig = {
  public: {
    secretKey: 'sk_live_exposed_to_browser'  // CRITICAL: In public config
  }
};

