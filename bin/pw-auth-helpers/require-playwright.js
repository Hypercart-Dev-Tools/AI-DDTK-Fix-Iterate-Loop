// pw-auth-helpers: require-playwright.js
// Centralised Playwright resolver for all toolkit helper scripts.
//
// Resolution order:
//   1. Standard require('playwright')        — local node_modules or existing NODE_PATH
//   2. require('playwright-core')            — same search paths
//   3. npm root -g bridge                    — appends the global npm module root to
//                                              NODE_PATH and retries both packages
//
// If all three strategies fail the process exits with an actionable error message
// rather than a raw module-not-found stack trace.
//
// Usage:
//   const { chromium } = require('./require-playwright');
//   // or destructure only what you need:
//   const playwright = require('./require-playwright');

'use strict';

const { execSync } = require('child_process');
const Module = require('module');

/**
 * Try to load playwright or playwright-core under the current module resolution
 * paths (which may have been augmented by a previous call to this function).
 * Returns the module on success, null on failure.
 */
function tryLoad() {
  try { return require('playwright'); } catch (_) {}
  try { return require('playwright-core'); } catch (_) {}
  return null;
}

/**
 * Attempt to retrieve the npm global module root via `npm root -g`.
 * Returns null if npm is unavailable or the command fails.
 */
function npmGlobalRoot() {
  try {
    return execSync('npm root -g', { stdio: ['ignore', 'pipe', 'ignore'] })
      .toString()
      .trim();
  } catch (_) {
    return null;
  }
}

/**
 * Append a directory to Node's live module search paths so that subsequent
 * require() calls can find packages installed there.
 */
function appendToNodePaths(dir) {
  // Update the process-level NODE_PATH env so child processes inherit it.
  const current = process.env.NODE_PATH || '';
  const parts = current.split(':').filter(Boolean);
  if (!parts.includes(dir)) {
    parts.push(dir);
    process.env.NODE_PATH = parts.join(':');
  }

  // Also patch Module._nodeModulePaths cache so require() in this process
  // picks up the new path immediately without a re-exec.
  if (!Module.globalPaths.includes(dir)) {
    Module.globalPaths.push(dir);
  }

  // Force the internal paths cache to refresh.
  try { Module._initPaths(); } catch (_) {}
}

// ── Resolution ────────────────────────────────────────────────────────────────

let playwright = tryLoad();

if (!playwright) {
  const globalRoot = npmGlobalRoot();

  if (globalRoot) {
    appendToNodePaths(globalRoot);
    playwright = tryLoad();

    if (playwright) {
      // Emit a one-time informational note so operators know the bridge fired.
      // Writing to stderr keeps stdout clean for scripts that parse JSON output.
      process.stderr.write(
        '[pw-auth] Note: Playwright resolved via global npm root (' + globalRoot + ').\n' +
        '[pw-auth] To avoid this fallback, add to your shell profile:\n' +
        '[pw-auth]   export NODE_PATH="$(npm root -g)"\n'
      );
    }
  }
}

if (!playwright) {
  const globalRoot = npmGlobalRoot();
  const nodePath = process.env.NODE_PATH || '(not set)';

  process.stderr.write(
    '[pw-auth] ERROR: Cannot find module \'playwright\' or \'playwright-core\'.\n' +
    '\n' +
    'Troubleshooting:\n' +
    '  1. Install Playwright locally in this project:\n' +
    '       npm install playwright\n' +
    '\n' +
    '  2. Or install Playwright globally and bridge the module path:\n' +
    '       npm install -g playwright\n' +
    '       export NODE_PATH="$(npm root -g)"\n' +
    '\n' +
    '  3. Install the required browser binary:\n' +
    '       npx playwright install chromium\n' +
    '\n' +
    'Diagnostic info:\n' +
    '  NODE_PATH : ' + nodePath + '\n' +
    '  npm root -g: ' + (globalRoot || '(npm unavailable)') + '\n' +
    '\n' +
    'Run `pw-auth doctor --site-url <url>` for a full readiness report.\n'
  );
  process.exit(1);
}

module.exports = playwright;
