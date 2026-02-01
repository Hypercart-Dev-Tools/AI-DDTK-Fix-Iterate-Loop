# AI Agent Tools Reference

**Location:** `/Users/noelsaw/bin/`  
**Last Updated:** 2026-02-01  
**Purpose:** Quick reference for AI agents working with Local WordPress sites and browser automation

---

## 🛠️ Available Tools

### 1. **Local WP-CLI Wrapper** (`local-wp`)
### 2. **Playwright Browser Automation** (`playwright`, `npx`)

---

## 📦 Tool 1: Local WP-CLI Wrapper

### **Purpose**
Run WP-CLI commands on Local by Flywheel WordPress sites without manual MySQL socket configuration.

### **Location**
- Script: `/Users/noelsaw/bin/local-wp`
- Executable: Yes (`chmod +x`)

### **Basic Syntax**
```bash
local-wp <site-name> <wp-cli-command> [args...]
```

### **Common Commands**

#### **Site Information**
```bash
# List available sites
local-wp --list

# Get WordPress version
local-wp <site-name> core version

# Get site URL
local-wp <site-name> option get siteurl

# Get site info
local-wp <site-name> core version --extra
```

#### **Plugin Management**
```bash
# List all plugins
local-wp <site-name> plugin list

# List active plugins only
local-wp <site-name> plugin list --status=active --format=table

# Activate a plugin
local-wp <site-name> plugin activate <plugin-slug>

# Deactivate a plugin
local-wp <site-name> plugin deactivate <plugin-slug>

# Get plugin info
local-wp <site-name> plugin get <plugin-slug>
```

#### **Theme Management**
```bash
# List themes
local-wp <site-name> theme list

# Activate a theme
local-wp <site-name> theme activate <theme-slug>

# Get active theme
local-wp <site-name> theme list --status=active
```

#### **Database Operations**
```bash
# Run SQL query
local-wp <site-name> db query "SELECT * FROM wp_options LIMIT 5"

# Export database
local-wp <site-name> db export backup.sql

# Search and replace
local-wp <site-name> search-replace 'old-url.com' 'new-url.com'

# Optimize database
local-wp <site-name> db optimize
```

#### **Post/Page Management**
```bash
# List posts
local-wp <site-name> post list --post_type=post

# Create a post
local-wp <site-name> post create --post_title="Title" --post_content="Content" --post_status=publish

# Delete a post
local-wp <site-name> post delete <post-id>
```

#### **User Management**
```bash
# List users
local-wp <site-name> user list

# Create admin user
local-wp <site-name> user create username email@example.com --role=administrator

# Update user password
local-wp <site-name> user update <user-id> --user_pass=newpassword
```

#### **Cache & Transients**
```bash
# Flush cache
local-wp <site-name> cache flush

# Delete transients
local-wp <site-name> transient delete --all

# Flush rewrite rules
local-wp <site-name> rewrite flush
```

### **Available Local Sites**
- `neochrome-timesheets`
- `ace-website-mbp-14`
- `appwpcodecheckcom`
- `autovinylhub-size-cpt`
- `macnerd-prod`
- `macnerdxyz-05-25`
- `neochrome-hypercart-redesign`
- `1-bloomzhemp-production-sync-07-24`

### **How It Works**
1. Auto-detects MySQL socket path from Local's configuration
2. Creates temporary PHP ini with socket configuration
3. Executes WP-CLI with custom PHP settings
4. Cleans up temporary files automatically

### **Requirements**
- Local by Flywheel must be running
- Site must be started in Local
- MySQL service must be active for the target site

### **Error Handling**
```bash
# If you get "Error establishing database connection":
# 1. Check if Local is running
# 2. Check if the site is started in Local
# 3. Verify site name with: local-wp --list
```

---

## 🌐 Tool 2: Playwright Browser Automation

### **Purpose**
Headless browser automation for testing, scraping, and web interaction across multiple browsers.

### **Location**
- Playwright CLI: `/Users/noelsaw/bin/playwright` (symlink to `/opt/homebrew/bin/playwright`)
- NPX: `/Users/noelsaw/bin/npx`
- Browser binaries: `/Users/noelsaw/Library/Caches/ms-playwright/`

### **Version**
- Playwright: `1.58.1`

### **Installed Browsers**
- ✅ Chrome/Chromium (v1208) - Headless Shell included
- ✅ Firefox (v146.0.1)
- ✅ WebKit (v26.0)
- ✅ FFmpeg (v1011) - for video recording

### **Basic Usage**

#### **Command Line**
```bash
# Run Playwright codegen (record actions)
npx playwright codegen https://example.com

# Run a test file
npx playwright test

# Run tests in headed mode (visible browser)
npx playwright test --headed

# Run tests in specific browser
npx playwright test --project=chromium
npx playwright test --project=firefox
npx playwright test --project=webkit

# Show test report
npx playwright show-report

# Run specific test file
npx playwright test tests/example.spec.js
```

#### **Screenshot & PDF Generation**
```bash
# Take screenshot (requires a script)
npx playwright screenshot https://example.com screenshot.png

# Generate PDF (requires a script)
npx playwright pdf https://example.com output.pdf
```

### **Programmatic Usage (Node.js)**

#### **Basic Example**
```javascript
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto('https://example.com');
  await page.screenshot({ path: 'screenshot.png' });
  await browser.close();
})();
```

#### **WordPress Testing Example**
```javascript
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();
  
  // Navigate to WordPress admin
  await page.goto('https://neochrome-timesheets.local/wp-admin');
  
  // Login
  await page.fill('#user_login', 'admin');
  await page.fill('#user_pass', 'password');
  await page.click('#wp-submit');
  
  // Wait for dashboard
  await page.waitForSelector('#wpadminbar');
  
  // Take screenshot
  await page.screenshot({ path: 'wp-admin.png' });
  
  await browser.close();
})();
```

#### **Multi-Browser Testing**
```javascript
const { chromium, firefox, webkit } = require('playwright');

for (const browserType of [chromium, firefox, webkit]) {
  const browser = await browserType.launch();
  const page = await browser.newPage();
  await page.goto('https://example.com');
  // Run tests...
  await browser.close();
}
```

### **Common Playwright Patterns**

#### **Wait for Elements**
```javascript
// Wait for selector
await page.waitForSelector('.my-element');

// Wait for navigation
await page.waitForNavigation();

// Wait for load state
await page.waitForLoadState('networkidle');
```

#### **Interact with Elements**
```javascript
// Click
await page.click('button#submit');

// Fill input
await page.fill('input[name="email"]', 'test@example.com');

// Select dropdown
await page.selectOption('select#country', 'US');

// Check checkbox
await page.check('input[type="checkbox"]');
```

#### **Extract Data**
```javascript
// Get text content
const text = await page.textContent('.title');

// Get attribute
const href = await page.getAttribute('a.link', 'href');

// Evaluate JavaScript
const result = await page.evaluate(() => {
  return document.title;
});
```

### **WordPress-Specific Use Cases**

#### **Test Plugin Activation**
```javascript
// Navigate to plugins page
await page.goto('https://site.local/wp-admin/plugins.php');

// Activate plugin
await page.click('tr[data-slug="my-plugin"] .activate a');

// Verify activation
const isActive = await page.isVisible('tr[data-slug="my-plugin"].active');
```

#### **Test WooCommerce Checkout**
```javascript
// Add to cart
await page.goto('https://site.local/product/test-product');
await page.click('button.single_add_to_cart_button');

// Go to checkout
await page.goto('https://site.local/checkout');

// Fill billing details
await page.fill('#billing_first_name', 'John');
await page.fill('#billing_last_name', 'Doe');
await page.fill('#billing_email', 'john@example.com');

// Place order
await page.click('#place_order');
```

### **Installation & Setup**

#### **For New Projects**
```bash
# Initialize Playwright in a project
cd /path/to/project
npm init playwright@latest

# Install Playwright
npm install -D @playwright/test

# Install browsers
npx playwright install
```

#### **Global Access**
```bash
# Already installed globally at:
/Users/noelsaw/bin/playwright
/Users/noelsaw/bin/npx

# Verify installation
playwright --version
# Output: Version 1.58.1
```

### **Configuration**

#### **playwright.config.js Example**
```javascript
module.exports = {
  testDir: './tests',
  timeout: 30000,
  use: {
    headless: true,
    viewport: { width: 1280, height: 720 },
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
    { name: 'firefox', use: { browserName: 'firefox' } },
    { name: 'webkit', use: { browserName: 'webkit' } },
  ],
};
```

### **Debugging**

```bash
# Run in headed mode (see browser)
npx playwright test --headed

# Run in debug mode
npx playwright test --debug

# Open Playwright Inspector
PWDEBUG=1 npx playwright test

# Generate trace
npx playwright test --trace on
npx playwright show-trace trace.zip
```

---

## 🔗 Combining Tools

### **Example: Test WordPress Plugin with WP-CLI + Playwright**

```bash
#!/bin/bash
SITE="neochrome-timesheets"

# 1. Activate plugin via WP-CLI
local-wp $SITE plugin activate my-plugin

# 2. Verify with Playwright
node << 'SCRIPT'
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('https://neochrome-timesheets.local/wp-admin/plugins.php');
  const isActive = await page.isVisible('tr[data-slug="my-plugin"].active');
  console.log('Plugin active:', isActive);
  await browser.close();
})();
SCRIPT

# 3. Check plugin status via WP-CLI
local-wp $SITE plugin status my-plugin
```

---

## 📚 Additional Resources

### **WP-CLI Documentation**
- Official Docs: https://wp-cli.org/
- Command Reference: https://developer.wordpress.org/cli/commands/

### **Playwright Documentation**
- Official Docs: https://playwright.dev/
- API Reference: https://playwright.dev/docs/api/class-playwright
- Examples: https://playwright.dev/docs/examples

---

## 🎯 Quick Tips for AI Agents

1. **Always verify Local is running** before using `local-wp`
2. **Use `--list` flag** to see available sites
3. **Playwright works globally** - no need to install per-project
4. **Combine tools** for comprehensive WordPress testing
5. **Use headless mode** for faster automation
6. **Use headed mode** for debugging
7. **Check browser cache location** if disk space is an issue: `~/Library/Caches/ms-playwright/`

---

**End of Tools Reference**

---

## 🔄 Tool 3: Automated Testing & Iteration Pattern

### **Purpose**
A systematic approach for AI agents to test, verify, and iterate on changes with minimal human intervention.

### **Location**
- Guide: `/Users/noelsaw/bin/fix-iterate-loop.md`
- **READ THIS BEFORE** starting any automated testing workflow

### **When to Use This Pattern**

✅ **Use when:**
- Importing/generating data that needs verification (JSON, SQL, CSV)
- Testing WordPress plugins, themes, or page builder layouts
- Running database migrations or schema changes
- Debugging CSS embedded in JSON (Beaver Builder, Elementor)
- API endpoint testing and validation
- Any task requiring multiple attempts to get right

❌ **Don't use when:**
- Simple one-off commands (just run it)
- Human review is required for each step
- Changes are irreversible (backups required first)

### **Quick Reference: The Core Loop**

```bash
# 1. Generate test data
# 2. Submit to system (using local-wp, curl, etc.)
# 3. Verify programmatically (grep, jq, SQL query)
# 4. Analyze results
# 5. If fail → adjust and repeat
# 6. If pass → document and complete
```

### **Critical Rules for AI Agents**

#### **Stop Conditions**
- ⛔ **After 5 failed iterations** → Report findings to human
- ⛔ **After 10 total iterations** → Stop and request guidance
- ⛔ **Before destructive operations** → Always confirm with human

#### **Simplification Checkpoints**
Ask human for help if you find yourself:
- Writing >50 lines of verification code
- Creating multi-step workarounds instead of fixing root cause
- Repeating the same verification pattern 3+ times
- Unable to verify results programmatically

### **Integration with Tools**

#### **Using with local-wp**
```bash
# Example: Test plugin activation loop
for i in {1..5}; do
  echo "ITERATION $i:"
  
  # 1. Activate plugin
  local-wp mysite plugin activate my-plugin
  
  # 2. Verify activation
  STATUS=$(local-wp mysite plugin status my-plugin --field=status)
  
  # 3. Check result
  if [ "$STATUS" = "active" ]; then
    echo "✅ PASS: Plugin activated"
    break
  else
    echo "❌ FAIL: Plugin status is $STATUS"
    # 4. Analyze and adjust (check logs, dependencies, etc.)
  fi
done
```

#### **Using with Playwright**
```javascript
// Example: Visual regression testing loop
const { chromium } = require('playwright');

async function testLoop() {
  for (let i = 1; i <= 5; i++) {
    console.log(`ITERATION ${i}:`);
    
    const browser = await chromium.launch();
    const page = await browser.newPage();
    
    // 1. Navigate to test page
    await page.goto('https://mysite.local/test-page');
    
    // 2. Verify element exists
    const element = await page.$('.expected-element');
    
    if (element) {
      // 3. Verify styling
      const color = await element.evaluate(el => 
        window.getComputedStyle(el).color
      );
      
      if (color === 'rgb(255, 0, 0)') {
        console.log('✅ PASS: Element has correct color');
        await browser.close();
        return true;
      } else {
        console.log(`❌ FAIL: Color is ${color}, expected rgb(255, 0, 0)`);
        // 4. Adjust JSON/CSS and retry
      }
    } else {
      console.log('❌ FAIL: Element not found');
    }
    
    await browser.close();
  }
  
  console.log('⛔ Max iterations reached, requesting human help');
  return false;
}
```

### **Iteration Template**

Use this structure for each test cycle:

```
ITERATION N:
1. What I'm testing: [describe goal]
2. Generated data: [show test data]
3. Submission command: [show exact command]
4. Expected result: [what should happen]
5. Actual result: [what happened]
6. Verification output: [show curl/CLI output]
7. Status: ✅ PASS / ❌ FAIL
8. Next action: [if fail, what to adjust]
```

### **Common Patterns**

#### **WordPress JSON Import & Verify**
```bash
# Generate Beaver Builder layout
cat > test-layout.json << 'EOF'
{"version":"2.8","rows":[...]}
