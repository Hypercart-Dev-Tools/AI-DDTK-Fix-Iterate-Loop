#!/usr/bin/env node

/**
 * WP AJAX Test - Lightweight WordPress AJAX endpoint testing
 * Part of AI-DDTK (AI Driven Development ToolKit)
 * 
 * Usage:
 *   wp-ajax-test --url https://site.local --action my_ajax_action
 *   wp-ajax-test --url https://site.local --action my_ajax_action --data '{"key":"value"}'
 *   wp-ajax-test --url https://site.local --action my_ajax_action --auth temp/auth.json
 */

const { program } = require('commander');
const axios = require('axios');
const cheerio = require('cheerio');
const fs = require('fs');
const path = require('path');

// Version
const VERSION = '1.0.0';

// Cookie storage
let cookies = {};

// Configure axios client
const client = axios.create({
  maxRedirects: 5,
  validateStatus: () => true // Accept all status codes
});

/**
 * Main program
 */
program
  .name('wp-ajax-test')
  .description('Lightweight WordPress AJAX endpoint testing')
  .version(VERSION)
  .requiredOption('-u, --url <url>', 'WordPress site URL')
  .requiredOption('-a, --action <action>', 'AJAX action name')
  .option('-d, --data <json>', 'JSON data payload', '{}')
  .option('--auth <file>', 'Auth file path (JSON)', null)
  .option('-f, --format <format>', 'Output format (human|json)', 'human')
  .option('--admin', 'Use admin AJAX endpoint (default)', true)
  .option('--nopriv', 'Use nopriv AJAX endpoint')
  .option('-m, --method <method>', 'HTTP method', 'POST')
  .option('-t, --timeout <ms>', 'Request timeout in ms', '30000')
  .option('-v, --verbose', 'Verbose output', false)
  .parse(process.argv);

const options = program.opts();

/**
 * Main execution
 */
async function main() {
  try {
    const startTime = Date.now();
    
    // Parse data payload
    let data;
    try {
      data = JSON.parse(options.data);
    } catch (e) {
      throw new Error(`Invalid JSON data: ${e.message}`);
    }

    // Load authentication if provided
    let auth = null;
    if (options.auth) {
      auth = await loadAuth(options.auth);
      if (options.verbose) {
        console.log(`Loaded auth from: ${options.auth}`);
      }
    }

    // Authenticate if needed
    if (auth && auth.username && auth.password) {
      await authenticate(options.url, auth);
    }

    // Get nonce if authenticated
    let nonce = null;
    if (auth) {
      nonce = await getNonce(options.url, auth);
      if (options.verbose && nonce) {
        console.log(`Extracted nonce: ${nonce.substring(0, 10)}...`);
      }
    }

    // Build AJAX endpoint URL
    const endpoint = options.nopriv 
      ? `${options.url}/wp-admin/admin-ajax.php`
      : `${options.url}/wp-admin/admin-ajax.php`;

    // Build request payload
    const payload = {
      action: options.action,
      ...data
    };

    if (nonce) {
      payload._ajax_nonce = nonce;
    }

    // Make AJAX request
    const response = await makeRequest(endpoint, payload, {
      method: options.method,
      timeout: parseInt(options.timeout)
    });

    const endTime = Date.now();
    const responseTime = endTime - startTime;

    // Output results
    if (options.format === 'json') {
      outputJSON({
        success: true,
        action: options.action,
        url: endpoint,
        status_code: response.status,
        response_time_ms: responseTime,
        response: response.data,
        headers: response.headers
      });
    } else {
      outputHuman({
        action: options.action,
        url: endpoint,
        status: response.status,
        responseTime,
        data: response.data
      });
    }

    process.exit(0);

  } catch (error) {
    handleError(error, options.format);
    process.exit(1);
  }
}

/**
 * Load authentication from file
 */
async function loadAuth(authFile) {
  try {
    const authPath = path.resolve(authFile);
    if (!fs.existsSync(authPath)) {
      throw new Error(`Auth file not found: ${authPath}`);
    }
    const content = fs.readFileSync(authPath, 'utf8');
    return JSON.parse(content);
  } catch (e) {
    throw new Error(`Failed to load auth file: ${e.message}`);
  }
}

/**
 * Authenticate with WordPress
 */
async function authenticate(siteUrl, auth) {
  const loginUrl = `${siteUrl}/wp-login.php`;

  try {
    const response = await client.post(loginUrl, new URLSearchParams({
      log: auth.username,
      pwd: auth.password,
      'wp-submit': 'Log In',
      redirect_to: `${siteUrl}/wp-admin/`,
      testcookie: '1'
    }), {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });

    // Store cookies from response
    if (response.headers['set-cookie']) {
      response.headers['set-cookie'].forEach(cookie => {
        const parts = cookie.split(';')[0].split('=');
        cookies[parts[0]] = parts[1];
      });
    }

    // Check if login was successful
    if (response.status === 200 && !response.data.includes('login_error')) {
      return true;
    }
    throw new Error('Authentication failed');
  } catch (e) {
    throw new Error(`Authentication failed: ${e.message}`);
  }
}

/**
 * Get nonce from WordPress admin page
 */
async function getNonce(siteUrl, auth) {
  try {
    // Try to get nonce from wp-admin
    const adminUrl = `${siteUrl}/wp-admin/`;
    const response = await client.get(adminUrl, {
      headers: {
        'Cookie': Object.entries(cookies).map(([k, v]) => `${k}=${v}`).join('; ')
      }
    });

    const $ = cheerio.load(response.data);

    // Look for common nonce patterns
    // 1. Check for _wpnonce in forms
    let nonce = $('input[name="_wpnonce"]').val();
    if (nonce) return nonce;

    // 2. Check for _ajax_nonce
    nonce = $('input[name="_ajax_nonce"]').val();
    if (nonce) return nonce;

    // 3. Check in inline scripts (wpApiSettings)
    const scripts = $('script').toArray();
    for (const script of scripts) {
      const content = $(script).html();
      if (content && content.includes('nonce')) {
        const match = content.match(/nonce["']?\s*:\s*["']([a-f0-9]+)["']/i);
        if (match) return match[1];
      }
    }

    // If no nonce found, return null (some endpoints don't require nonce)
    return null;
  } catch (e) {
    // Non-fatal: some endpoints work without nonce
    return null;
  }
}

/**
 * Make AJAX request
 */
async function makeRequest(url, payload, options = {}) {
  const config = {
    method: options.method || 'POST',
    url,
    timeout: options.timeout || 30000,
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'X-Requested-With': 'XMLHttpRequest'
    }
  };

  // Add cookies if we have them
  if (Object.keys(cookies).length > 0) {
    config.headers['Cookie'] = Object.entries(cookies).map(([k, v]) => `${k}=${v}`).join('; ');
  }

  if (config.method === 'POST') {
    config.data = new URLSearchParams(payload);
  } else {
    config.params = payload;
  }

  return await client(config);
}

/**
 * Output results in human-readable format
 */
function outputHuman(result) {
  console.log('');
  console.log(`✓ AJAX Test: ${result.action}`);
  console.log(`  URL: ${result.url}`);
  console.log(`  Status: ${result.status} ${result.status === 200 ? 'OK' : 'ERROR'}`);
  console.log(`  Response Time: ${result.responseTime}ms`);
  console.log('');
  console.log('  Response:');
  console.log('  ' + JSON.stringify(result.data, null, 2).split('\n').join('\n  '));
  console.log('');
}

/**
 * Output results in JSON format
 */
function outputJSON(result) {
  console.log(JSON.stringify(result, null, 2));
}

/**
 * Handle errors
 */
function handleError(error, format) {
  const errorObj = {
    success: false,
    error: {
      code: error.code || 'UNKNOWN_ERROR',
      message: error.message
    },
    suggestions: []
  };

  // Add specific suggestions based on error
  if (error.message.includes('Auth file not found')) {
    errorObj.error.code = 'AUTH_REQUIRED';
    errorObj.suggestions.push('Create temp/auth.json with username and password');
    errorObj.suggestions.push('Use --auth flag to specify auth file location');
  } else if (error.message.includes('Authentication failed')) {
    errorObj.error.code = 'AUTH_FAILED';
    errorObj.suggestions.push('Check username and password in auth file');
    errorObj.suggestions.push('Verify WordPress site URL is correct');
  } else if (error.message.includes('ENOTFOUND') || error.message.includes('ECONNREFUSED')) {
    errorObj.error.code = 'CONNECTION_ERROR';
    errorObj.suggestions.push('Check if WordPress site is running');
    errorObj.suggestions.push('Verify site URL is correct');
  } else if (error.message.includes('timeout')) {
    errorObj.error.code = 'TIMEOUT';
    errorObj.suggestions.push('Increase timeout with --timeout flag');
    errorObj.suggestions.push('Check server performance');
  }

  if (format === 'json') {
    console.error(JSON.stringify(errorObj, null, 2));
  } else {
    console.error('');
    console.error(`✗ Error: ${errorObj.error.message}`);
    if (errorObj.suggestions.length > 0) {
      console.error('');
      console.error('  Suggestions:');
      errorObj.suggestions.forEach(s => console.error(`  - ${s}`));
    }
    console.error('');
  }
}

// Run main
main();

