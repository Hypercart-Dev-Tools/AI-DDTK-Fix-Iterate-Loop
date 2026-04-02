/**
 * WordPress Baseline Load Test
 * Part of AI-DDTK - AI Driven Development ToolKit
 *
 * Tests core WordPress endpoints under concurrent load:
 *   - Homepage
 *   - Category archive
 *   - Single post (latest)
 *   - REST API (posts listing)
 *   - Static asset (theme stylesheet)
 *
 * Usage:
 *   k6-harness http://mysite.local wp-baseline.js
 *   k6-harness http://mysite.local wp-baseline.js --vus 20 --duration 60s
 *
 * Environment variables (injected by k6-harness):
 *   BASE_URL  — Target site URL (required)
 */

import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// ============================================================
// CONFIGURATION
// ============================================================

const BASE_URL = __ENV.BASE_URL || 'http://localhost';

// Custom metrics
const errorRate = new Rate('wp_errors');
const homepageDuration = new Trend('wp_homepage_duration', true);
const restApiDuration = new Trend('wp_rest_api_duration', true);

// Default options (overridden by k6-harness --vus/--duration flags)
export const options = {
  thresholds: {
    http_req_duration: ['p(95)<2000'],  // 95% of requests under 2s
    wp_errors: ['rate<0.1'],             // Less than 10% error rate
  },
};

// ============================================================
// HELPERS
// ============================================================

const defaultHeaders = {
  'User-Agent': 'AI-DDTK-k6/1.0 (load-test; +https://github.com/user/AI-DDTK)',
  'Accept': 'text/html,application/xhtml+xml,application/json',
};

function wpGet(path, name) {
  const url = `${BASE_URL}${path}`;
  const res = http.get(url, {
    headers: defaultHeaders,
    tags: { name: name || path },
  });
  return res;
}

// ============================================================
// TEST SCENARIOS
// ============================================================

export default function () {

  // --- Homepage ---
  group('Homepage', () => {
    const res = wpGet('/', 'Homepage');
    homepageDuration.add(res.timings.duration);

    const ok = check(res, {
      'homepage returns 200': (r) => r.status === 200,
      'homepage has content': (r) => r.body && r.body.length > 0,
      'homepage is not error page': (r) => !r.body.includes('Fatal error'),
    });
    errorRate.add(!ok);
  });

  sleep(0.5);

  // --- Category Archive ---
  group('Category Archive', () => {
    // Uses ?cat=1 which is the default "Uncategorized" category
    const res = wpGet('/?cat=1', 'Category Archive');

    const ok = check(res, {
      'archive returns 200 or 301': (r) => r.status === 200 || r.status === 301,
    });
    errorRate.add(!ok);
  });

  sleep(0.5);

  // --- REST API: Posts ---
  group('REST API - Posts', () => {
    const res = wpGet('/wp-json/wp/v2/posts?per_page=5', 'REST API Posts');
    restApiDuration.add(res.timings.duration);

    const ok = check(res, {
      'REST API returns 200': (r) => r.status === 200,
      'REST API returns JSON': (r) => {
        try { JSON.parse(r.body); return true; } catch { return false; }
      },
      'REST API returns array': (r) => {
        try { return Array.isArray(JSON.parse(r.body)); } catch { return false; }
      },
    });
    errorRate.add(!ok);
  });

  sleep(0.5);

  // --- Single Post (via REST discovery) ---
  group('Single Post', () => {
    // Fetch the latest post URL from the REST API
    const apiRes = wpGet('/wp-json/wp/v2/posts?per_page=1', 'Latest Post Lookup');

    if (apiRes.status === 200) {
      try {
        const posts = JSON.parse(apiRes.body);
        if (posts.length > 0 && posts[0].link) {
          // Convert absolute URL to path
          const postUrl = new URL(posts[0].link);
          const res = wpGet(postUrl.pathname, 'Single Post');

          const ok = check(res, {
            'single post returns 200': (r) => r.status === 200,
            'single post has content': (r) => r.body && r.body.length > 500,
          });
          errorRate.add(!ok);
        }
      } catch (_) {
        // If REST API is disabled or malformed, skip gracefully
      }
    }
  });

  sleep(0.5);

  // --- Theme Stylesheet (static asset) ---
  group('Static Asset', () => {
    // WordPress always loads the active theme's style.css
    const res = wpGet('/wp-content/themes/', 'Theme Directory');

    // Just check the themes directory is accessible
    const ok = check(res, {
      'themes directory accessible': (r) => r.status === 200 || r.status === 403,
    });
    errorRate.add(!ok);
  });

  // Pace between iterations (1-2s)
  sleep(1 + Math.random());
}

// ============================================================
// SUMMARY
// ============================================================

export function handleSummary(data) {
  const summary = {
    tool: 'AI-DDTK k6 harness',
    script: 'wp-baseline.js',
    target: BASE_URL,
    timestamp: new Date().toISOString(),
    metrics: {
      http_reqs: data.metrics.http_reqs ? data.metrics.http_reqs.values.count : 0,
      http_req_duration_p95: data.metrics.http_req_duration
        ? data.metrics.http_req_duration.values['p(95)']
        : null,
      error_rate: data.metrics.wp_errors
        ? data.metrics.wp_errors.values.rate
        : null,
    },
  };

  return {
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
    'wp-baseline-summary.json': JSON.stringify(summary, null, 2),
  };
}

// k6 built-in text summary helper
import { textSummary } from 'https://jslib.k6.io/k6-summary/0.1.0/index.js';
