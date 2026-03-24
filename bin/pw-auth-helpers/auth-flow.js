// pw-auth: Playwright login + storageState capture / validation
// Usage: node <script> <mode> <site_url> <auth_file> <login_url> <headless>

let chromium;
try { ({ chromium } = require('playwright')); }
catch { ({ chromium } = require('playwright-core')); }

const [,, mode, siteUrl, authFile, loginUrl, headlessFlag] = process.argv;
const headless = headlessFlag !== 'false';
const parsedSiteUrl = new URL(siteUrl);
const origin = parsedSiteUrl.origin;
const baseUrl = siteUrl.replace(/\/+$/, '');
const host = parsedSiteUrl.hostname.toLowerCase();
const ignoreHTTPSErrors = parsedSiteUrl.protocol === 'https:' && (
    host === 'localhost' ||
    host === '127.0.0.1' ||
    host === '::1' ||
    host.endsWith('.local') ||
    host.endsWith('.test')
);

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

async function assertAuthCookie(context) {
    const cookies = await context.cookies(origin);
    const authCookie = cookies.find(cookie => cookie.name.startsWith('wordpress_logged_in_'));

    if (!authCookie) {
        throw new Error('No wordpress_logged_in_ cookie found. Cookies present: ' + cookies.map(cookie => cookie.name).join(', '));
    }
}

async function assertWpAdminAccessible(page) {
    await page.goto(baseUrl + '/wp-admin/', {
        waitUntil: 'domcontentloaded',
        timeout: 15000,
    });

    if (page.url().includes('wp-login.php')) {
        throw new Error('wp-admin redirected to wp-login.php — session is not valid.');
    }
}

(async () => {
    let browser;

    try {
        browser = await chromium.launch({ headless });
        const contextOptions = ignoreHTTPSErrors ? { ignoreHTTPSErrors: true } : {};

        if (mode === 'validate') {
            contextOptions.storageState = authFile;
        }

        const context = await browser.newContext(contextOptions);
        const page = await context.newPage();

        if (mode === 'login') {
            await page.goto(loginUrl, { waitUntil: 'networkidle', timeout: 30000 });

            if (page.url().includes('wp-login.php')) {
                throw new Error('Login failed — landed on wp-login.php. The login token may have expired or the mu-plugin may not be active.');
            }

            await assertNotWpErrorPage(page);
            await assertAuthCookie(context);
            await assertWpAdminAccessible(page);
            await assertNotWpErrorPage(page);

            await context.storageState({ path: authFile });
            console.log('[pw-auth] Auth state saved to: ' + authFile);
            console.log('[pw-auth] Verified: wordpress_logged_in_ cookie present, wp-admin accessible.');
        } else if (mode === 'validate') {
            await assertWpAdminAccessible(page);
            await assertNotWpErrorPage(page);
            await assertAuthCookie(context);
            console.log('[pw-auth] Cached auth is still valid.');
        } else {
            throw new Error('Unknown mode: ' + mode);
        }
    } catch (err) {
        console.error('[pw-auth] ERROR: ' + err.message);
        process.exit(1);
    } finally {
        if (browser) {
            await browser.close();
        }
    }
})();
