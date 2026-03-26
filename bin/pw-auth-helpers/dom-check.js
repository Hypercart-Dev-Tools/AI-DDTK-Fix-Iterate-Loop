// pw-auth: Playwright DOM inspection
// Usage: node <script> <url> <selector> <extract> <auth_file> <auth_origin> <result_json> <extract_file> <timeout_ms> <output_format> <selectors_csv> <wait_for> <assertion> <assertion_value> <assertion_attr> <screenshot_mode>

const fs = require('node:fs');
const path = require('node:path');

let chromium;
try { ({ chromium } = require('playwright')); }
catch { ({ chromium } = require('playwright-core')); }

const [,, targetUrl, selectorArg, extractModeRaw, authFile, authOrigin, resultJson, extractFile, timeoutMsRaw, outputFormatRaw, selectorsRaw, waitForSelectorRaw, assertionTypeRaw, assertionValueRaw, assertionAttrRaw, screenshotModeRaw] = process.argv;
const extractMode = extractModeRaw || 'exists';
const outputFormat = outputFormatRaw || 'text';
const timeoutMs = Number.parseInt(timeoutMsRaw || '15000', 10) || 15000;
const waitForSelector = waitForSelectorRaw || null;
const assertionType = assertionTypeRaw || null;
const assertionValue = assertionValueRaw || '';
const assertionAttr = assertionAttrRaw || '';
const screenshotMode = screenshotModeRaw || 'never';
const parsedTargetUrl = new URL(targetUrl);
const effectiveAuthOrigin = authOrigin || parsedTargetUrl.origin;
const host = parsedTargetUrl.hostname.toLowerCase();
const outputDir = path.dirname(resultJson);
const ignoreHTTPSErrors = parsedTargetUrl.protocol === 'https:' && (
  host === 'localhost' ||
  host === '127.0.0.1' ||
  host === '::1' ||
  host.endsWith('.local') ||
  host.endsWith('.test')
);

function parseSelectors(listValue, singleValue) {
  if (listValue && listValue.trim()) {
    return listValue
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean);
  }

  if (singleValue && singleValue.trim()) {
    return [singleValue.trim()];
  }

  return [];
}

const selectors = parseSelectors(selectorsRaw, selectorArg);

function displayPath(targetPath) {
  if (!targetPath) {
    return null;
  }

  const relative = path.relative(process.cwd(), targetPath);
  if (relative && !relative.startsWith('..') && !path.isAbsolute(relative)) {
    return relative;
  }

  return targetPath;
}

function slugify(value) {
  return String(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48) || 'selector';
}

async function assertNotWpErrorPage(page) {
  const bodyText = await page.textContent('body').catch(() => '');
  const pageTitle = await page.title().catch(() => '');
  const bodyId = await page.getAttribute('body', 'id').catch(() => '');
  const hasWpDieMarkup = (await page.locator('#error-page, .wp-die-message').count().catch(() => 0)) > 0;
  const fatalMarkers = [
    'There has been a critical error on this website.',
    'has been a critical error on this website.',
    'Dev login is disabled in production environments.',
    'Dev login is not allowed on this host.',
    'Invalid or expired login link.',
    'Invalid user.',
    'Error establishing a database connection'
  ];

  const looksLikeWpErrorPage =
    bodyId === 'error-page' ||
    hasWpDieMarkup ||
    pageTitle.includes('WordPress › Error') ||
    fatalMarkers.some(marker => bodyText.includes(marker));

  if (looksLikeWpErrorPage) {
    throw new Error('WordPress returned an error page. Body: ' + bodyText.substring(0, 200));
  }
}

async function hasAuthCookie(context, origin) {
  try {
    const cookies = await context.cookies(origin);
    return cookies.some(cookie => cookie.name.startsWith('wordpress_logged_in_'));
  } catch {
    return false;
  }
}

function buildTextOutput(result) {
  const lines = [
    `[pw-auth] DOM check status: ${result.status}`,
    `[pw-auth] URL: ${result.url}`,
    `[pw-auth] Selectors: ${result.selectors.join(', ')}`,
    `[pw-auth] Extract: ${result.extract}`,
    `[pw-auth] Auth used: ${result.auth_used ? 'yes' : 'no'}`,
    `[pw-auth] Result JSON: ${result.artifacts.result_json}`,
  ];

  if (result.wait_for) {
    lines.push(`[pw-auth] Wait for: ${result.wait_for}`);
  }

  if (result.assertion) {
    lines.push(`[pw-auth] Assertion: ${result.assertion.type}`);
  }

  if (result.artifacts.extract_file) {
    lines.push(`[pw-auth] Extract file: ${result.artifacts.extract_file}`);
  }

  if (result.artifacts.failure_screenshot) {
    lines.push(`[pw-auth] Failure screenshot: ${result.artifacts.failure_screenshot}`);
  }

  if (Array.isArray(result.results) && result.results.length > 0) {
    lines.push('[pw-auth] Results:');
    for (const item of result.results) {
      lines.push(`[pw-auth]   - ${item.status}: ${item.selector} (matches: ${item.match_count})`);
      if (typeof item.value === 'string') {
        lines.push(`[pw-auth]     value length: ${item.value.length}`);
      } else if (item.value === true) {
        lines.push('[pw-auth]     value: true');
      }
      if (item.screenshot_path) {
        lines.push(`[pw-auth]     screenshot: ${item.screenshot_path}`);
      }
      if (item.assertion && !item.assertion.passed) {
        lines.push(`[pw-auth]     assertion: ${item.assertion.message}`);
      }
    }
  }

  if (result.errors.length > 0) {
    lines.push('[pw-auth] Errors:');
    for (const message of result.errors) {
      lines.push(`[pw-auth]   - ${message}`);
    }
  }

  return lines.join('\n') + '\n';
}

function buildAssertionMessage(selector, type, details) {
  switch (type) {
    case 'visible':
      return `Assertion failed for ${selector}: expected element to be visible.`;
    case 'hidden':
      return `Assertion failed for ${selector}: expected element to be hidden.`;
    case 'text-contains':
      return `Assertion failed for ${selector}: expected text to contain "${details.expected}".`;
    case 'attr-equals':
      return `Assertion failed for ${selector}: expected attribute ${details.attribute} to equal "${details.expected}".`;
    default:
      return `Assertion failed for ${selector}.`;
  }
}

async function evaluateExtract(target, mode) {
  if (mode === 'exists') {
    return true;
  }

  if (mode === 'text') {
    return (await target.innerText({ timeout: timeoutMs })).trim();
  }

  if (mode === 'html') {
    return await target.evaluate((element) => element.innerHTML);
  }

  throw new Error(`Unsupported extract mode: ${mode}`);
}

async function evaluateAssertion(target, selector) {
  if (!assertionType) {
    return null;
  }

  if (assertionType === 'visible') {
    const actual = await target.isVisible();
    return {
      type: assertionType,
      passed: actual,
      expected: true,
      actual,
      message: actual ? null : buildAssertionMessage(selector, assertionType, {}),
    };
  }

  if (assertionType === 'hidden') {
    const actual = await target.isVisible();
    return {
      type: assertionType,
      passed: !actual,
      expected: false,
      actual,
      message: !actual ? null : buildAssertionMessage(selector, assertionType, {}),
    };
  }

  if (assertionType === 'text-contains') {
    const actual = (await target.innerText({ timeout: timeoutMs })).trim();
    const passed = actual.includes(assertionValue);
    return {
      type: assertionType,
      passed,
      expected: assertionValue,
      actual,
      message: passed ? null : buildAssertionMessage(selector, assertionType, { expected: assertionValue }),
    };
  }

  if (assertionType === 'attr-equals') {
    const actual = await target.getAttribute(assertionAttr);
    const passed = actual === assertionValue;
    return {
      type: assertionType,
      attribute: assertionAttr,
      passed,
      expected: assertionValue,
      actual,
      message: passed ? null : buildAssertionMessage(selector, assertionType, { attribute: assertionAttr, expected: assertionValue }),
    };
  }

  throw new Error(`Unsupported assertion mode: ${assertionType}`);
}

function summarizeStatus(results) {
  if (results.some((item) => item.status === 'assertion_failed')) {
    return 'assertion_failed';
  }

  if (results.some((item) => item.status === 'not_found')) {
    return 'not_found';
  }

  return 'ok';
}

function exitCodeForStatus(status) {
  switch (status) {
    case 'ok':
      return 0;
    case 'not_found':
      return 3;
    case 'auth_required':
      return 4;
    case 'assertion_failed':
      return 6;
    default:
      return 5;
  }
}

async function captureScreenshot(page, selector, index, suffix = '') {
  if (screenshotMode === 'never') {
    return null;
  }

  const filename = `selector-${String(index + 1).padStart(2, '0')}-${slugify(selector)}${suffix}.png`;
  const screenshotPath = path.join(outputDir, filename);
  await page.screenshot({ path: screenshotPath, fullPage: true });
  return displayPath(screenshotPath);
}

async function captureFailureScreenshot(page, label) {
  if (screenshotMode === 'never') {
    return null;
  }

  const screenshotPath = path.join(outputDir, `failure-${slugify(label)}.png`);
  await page.screenshot({ path: screenshotPath, fullPage: true }).catch(() => {});
  return displayPath(screenshotPath);
}

async function finish(result, exitCode) {
  fs.mkdirSync(path.dirname(resultJson), { recursive: true });

  if (result.status === 'ok' && (extractMode === 'text' || extractMode === 'html')) {
    if (result.results.length === 1 && extractFile) {
      fs.writeFileSync(extractFile, String(result.value ?? ''), 'utf8');
      result.artifacts.extract_file = displayPath(extractFile);
    } else if (result.results.length > 1) {
      const multiExtractFile = path.join(outputDir, 'extracts.json');
      const extractPayload = result.results.map((item) => ({
        selector: item.selector,
        status: item.status,
        value: item.value,
      }));
      fs.writeFileSync(multiExtractFile, JSON.stringify(extractPayload, null, 2) + '\n', 'utf8');
      result.artifacts.extract_file = displayPath(multiExtractFile);
    }
  }

  fs.writeFileSync(resultJson, JSON.stringify(result, null, 2) + '\n', 'utf8');

  if (outputFormat === 'json') {
    process.stdout.write(JSON.stringify(result, null, 2) + '\n');
  } else {
    process.stdout.write(buildTextOutput(result));
  }

  process.exit(exitCode);
}

(async () => {
  let browser;

  const result = {
    status: 'error',
    url: targetUrl,
    selector: selectors.length === 1 ? selectors[0] : null,
    selectors,
    extract: extractMode,
    wait_for: waitForSelector,
    assertion: assertionType
      ? {
          type: assertionType,
          value: assertionValue || null,
          attribute: assertionAttr || null,
        }
      : null,
    auth_used: false,
    value: extractMode === 'exists' ? false : null,
    results: [],
    artifacts: {
      output_dir: displayPath(outputDir),
      result_json: displayPath(resultJson),
      extract_file: null,
      failure_screenshot: null,
    },
    errors: [],
  };

  try {
    if (selectors.length === 0) {
      throw new Error('At least one selector is required.');
    }

    const authFileExists = Boolean(authFile) && fs.existsSync(authFile);
    const contextOptions = ignoreHTTPSErrors ? { ignoreHTTPSErrors: true } : {};

    if (authFileExists) {
      contextOptions.storageState = authFile;
      result.auth_used = true;
    }

    browser = await chromium.launch({ headless: true });
    const context = await browser.newContext(contextOptions);
    const page = await context.newPage();
    const authCookiePresent = authFileExists ? await hasAuthCookie(context, effectiveAuthOrigin) : false;

    await page.goto(targetUrl, { waitUntil: 'domcontentloaded', timeout: timeoutMs });
    await assertNotWpErrorPage(page);

    if (page.url().includes('wp-login.php')) {
      result.status = 'auth_required';
      if (!authFileExists) {
        result.errors.push(
          authFile
            ? `Auth state file not found or unreadable: ${displayPath(authFile)}`
            : 'This page redirected to wp-login.php and requires cached auth.'
        );
      } else if (!authCookiePresent) {
        result.errors.push(`Cached auth did not provide a wordpress_logged_in_ cookie for ${effectiveAuthOrigin}.`);
      } else {
        result.errors.push('Cached auth did not grant access to the requested URL. Refresh auth and retry.');
      }
      result.artifacts.failure_screenshot = await captureFailureScreenshot(page, 'auth-required');
      return finish(result, 4);
    }

    if (waitForSelector) {
      await page.waitForSelector(waitForSelector, { timeout: timeoutMs });
    }

    for (const [index, selector] of selectors.entries()) {
      const item = {
        selector,
        status: 'ok',
        match_count: 0,
        value: extractMode === 'exists' ? false : null,
        assertion: null,
        screenshot_path: null,
        errors: [],
      };

      const target = page.locator(selector);
      item.match_count = await target.count();

      if (item.match_count === 0) {
        item.status = 'not_found';
        item.errors.push(`Selector not found: ${selector}`);
        if (screenshotMode !== 'never') {
          item.screenshot_path = await captureScreenshot(page, selector, index, '-failure');
        }
        result.results.push(item);
        result.errors.push(...item.errors);
        continue;
      }

      const firstMatch = target.first();
      item.value = await evaluateExtract(firstMatch, extractMode);
      item.assertion = await evaluateAssertion(firstMatch, selector);

      if (item.assertion && !item.assertion.passed) {
        item.status = 'assertion_failed';
        item.errors.push(item.assertion.message);
      }

      if (screenshotMode === 'always' || (screenshotMode === 'on-failure' && item.status !== 'ok')) {
        item.screenshot_path = await captureScreenshot(page, selector, index, item.status === 'ok' ? '' : '-failure');
      }

      if (item.errors.length > 0) {
        result.errors.push(...item.errors);
      }

      result.results.push(item);
    }

    result.status = summarizeStatus(result.results);
    if (result.results.length === 1) {
      result.value = result.results[0].value;
    } else if (extractMode !== 'exists') {
      result.value = null;
    }

    return finish(result, exitCodeForStatus(result.status));
  } catch (error) {
    result.status = 'error';
    result.errors.push(error && error.message ? error.message : String(error));
    if (browser) {
      const context = browser.contexts()[0];
      const page = context ? context.pages()[0] : null;
      if (page) {
        result.artifacts.failure_screenshot = await captureFailureScreenshot(page, 'runtime-error');
      }
    }
    return finish(result, 5);
  } finally {
    if (browser) {
      await browser.close().catch(() => {});
    }
  }
})();
