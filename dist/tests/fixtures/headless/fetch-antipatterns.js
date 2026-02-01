/**
 * Headless WordPress Anti-patterns: Fetch/Axios
 * 
 * This fixture contains common anti-patterns found in headless WordPress frontends
 * when fetching data from the WordPress REST API.
 * 
 * Expected violations: 8
 * Expected safe patterns: 4
 */

// =============================================================================
// ANTI-PATTERNS (Should be flagged)
// =============================================================================

// VIOLATION 1: fetch without error handling (no .catch())
async function getPostsNoErrorHandling() {
  const response = await fetch('https://example.com/wp-json/wp/v2/posts');
  const posts = await response.json();
  return posts;
}

// VIOLATION 2: fetch without checking response.ok
async function getPostsNoResponseCheck() {
  try {
    const response = await fetch('/wp-json/wp/v2/posts');
    const posts = await response.json(); // Will fail silently on 404/500
    return posts;
  } catch (e) {
    console.log(e);
  }
}

// VIOLATION 3: Hardcoded API URL (should use environment variable)
const API_URL = 'https://mysite.com/wp-json/wp/v2';
async function getPages() {
  const response = await fetch('https://mysite.com/wp-json/wp/v2/pages');
  return response.json();
}

// VIOLATION 4: Missing credentials for authenticated endpoints
async function getPrivatePosts() {
  const response = await fetch('/wp-json/wp/v2/posts?status=draft');
  // Missing: credentials: 'include' for cookies
  // Missing: Authorization header for JWT/Application Password
  return response.json();
}

// VIOLATION 5: API key exposed in client-side code
const WORDPRESS_API_KEY = 'sk_live_abc123secret';
const WP_SECRET_TOKEN = 'my-super-secret-token';

// VIOLATION 6: Sensitive env vars exposed via NEXT_PUBLIC_
const apiSecret = process.env.NEXT_PUBLIC_API_SECRET_KEY;
const wpPassword = process.env.NEXT_PUBLIC_WP_APP_PASSWORD;

// VIOLATION 7: axios without error handling
import axios from 'axios';
async function axiosNoErrorHandling() {
  const { data } = await axios.get('/wp-json/wp/v2/posts');
  return data;
}

// VIOLATION 8: Missing authentication header on protected endpoint
async function updatePost(postId, data) {
  const response = await fetch(`/wp-json/wp/v2/posts/${postId}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(data),
    // Missing: Authorization header
  });
  return response.json();
}

// =============================================================================
// SAFE PATTERNS (Should NOT be flagged)
// =============================================================================

// SAFE 1: Proper error handling with try/catch and response check
async function getPostsSafe() {
  try {
    const response = await fetch(`${process.env.NEXT_PUBLIC_WP_URL}/wp-json/wp/v2/posts`);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const posts = await response.json();
    return posts;
  } catch (error) {
    console.error('Failed to fetch posts:', error);
    throw error;
  }
}

// SAFE 2: With credentials for authenticated requests
async function getPrivatePostsSafe() {
  const response = await fetch('/wp-json/wp/v2/posts?status=draft', {
    credentials: 'include',
    headers: {
      'Authorization': `Bearer ${getToken()}`,
    },
  });
  if (!response.ok) throw new Error('Failed to fetch');
  return response.json();
}

// SAFE 3: axios with proper error handling
async function axiosSafe() {
  try {
    const { data } = await axios.get('/wp-json/wp/v2/posts');
    return data;
  } catch (error) {
    if (axios.isAxiosError(error)) {
      console.error('API Error:', error.response?.data);
    }
    throw error;
  }
}

// SAFE 4: Environment variable for API URL (non-sensitive)
const wpApiUrl = process.env.NEXT_PUBLIC_WORDPRESS_URL;

