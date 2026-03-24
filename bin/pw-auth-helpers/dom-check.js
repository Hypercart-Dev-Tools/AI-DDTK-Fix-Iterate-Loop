// pw-auth: Playwright DOM inspection
// Usage: node <script> <url> <selector> <extract> <auth_file> <auth_origin> <result_json> <extract_file> <timeout_ms> <output_format>

const fs = require('node:fs');
const path = require('node:path');

let chromium;
try { ({ chromium } = require('playwright')); }
catch { ({ chromium } = require('playwright-core')); }

const [,, targetUrl, selector, extractMode, authFile, authOrigin, resultJson, extractFile, timeoutMsRaw, outputFormat] = process.argv;
const timeoutMs = Number.parseInt(timeoutMsRaw || '15000', 10) || 15000;
const parsedTargetUrl = new URL(targetUrl);
const effectiveAuthOrigin = authOrigin || parsedTargetUrl.origin;
const host = parsedTargetUrl.hostname.toLowerCase();
const ignoreHTTPSErrors = parsedTargetUrl.protocol === 'https:' && (
  host === 'localhost' ||
  host === '127.0.0.1' ||
  host === '::1' ||
  host.endsWith('.local') ||
  host.endsWith('.test')
);

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
    `[pw-auth] Selector: ${result.selector}`,
    `[pw-auth] Extract: ${result.extract}`,
    `[pw-auth] Auth used: ${result.auth_used ? 'yes' : 'no'}`,
    `[pw-auth] Result JSON: ${result.artifacts.result_json}`,
  ];

  if (result.artifacts.extract_file) {
    lines.push(`[pw-auth] Extract file: ${result.artifacts.extract_file}`);
  }

  if (result.status === 'ok') {
    if (result.extract === 'exists') {
      lines.push('[pw-auth] Value: true');
    } else if (typeof result.value === 'string') {
      lines.push(`[pw-auth] Value length: ${result.value.length}`);
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

async function finish(result, exitCode) {
  fs.mkdirSync(path.dirname(resultJson), { recursive: true });

  if (result.status === 'ok' && (extractMode === 'text' || extractMode === 'html') && extractFile) {
    fs.writeFileSync(extractFile, String(result.value ?? ''), 'utf8');
    result.artifacts.extract_file = displayPath(extractFile);
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
    selector,
    extract: extractMode,
    auth_used: false,
    value: extractMode === 'exists' ? false : null,
    artifacts: {
      output_dir: displayPath(path.dirname(resultJson)),
      result_json: displayPath(resultJson),
      extract_file: null,
    },
    errors: [],
  };

  try {
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
      return finish(result, 4);
    }

    const matchCount = await page.locator(selector).count();
    if (matchCount === 0) {
      result.status = 'not_found';
      result.errors.push(`Selector not found: ${selector}`);
      return finish(result, 3);
    }

    const target = page.locator(selector).first();

    if (extractMode === 'exists') {
      result.value = true;
    } else if (extractMode === 'text') {
      result.value = (await target.innerText({ timeout: timeoutMs })).trim();
    } else if (extractMode === 'html') {
      result.value = await target.evaluate((element) => element.innerHTML);
    } else {
      throw new Error(`Unsupported extract mode: ${extractMode}`);
    }

    result.status = 'ok';
    return finish(result, 0);
  } catch (error) {
    result.status = 'error';
    result.errors.push(error && error.message ? error.message : String(error));
    return finish(result, 5);
  } finally {
    if (browser) {
      await browser.close().catch(() => {});
    }
  }
})();
