# CI/CD Integration Guide

Integrate AI-DDTK (`pw-auth`, `wpcc`, Playwright) into automated CI/CD pipelines for WordPress end-to-end testing.

**Last Updated:** 2026-03-22  
**Version:** 1.0.0

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Key Concepts for CI/CD](#key-concepts-for-cicd)
4. [GitHub Actions Integration](#github-actions-integration)
5. [GitLab CI Integration](#gitlab-ci-integration)
6. [Handling Auth State in CI](#handling-auth-state-in-ci)
7. [Common CI/CD Issues & Fixes](#common-cicd-issues--fixes)
8. [Environment Variables Reference](#environment-variables-reference)
9. [Security Best Practices](#security-best-practices)

---

## Overview

AI-DDTK provides production-ready tooling for automating WordPress end-to-end tests in CI/CD pipelines. By combining `pw-auth` (passwordless WordPress authentication) with Playwright, you can:

- Authenticate into any WordPress admin without managing static credentials in test code
- Spin up ephemeral WordPress environments using Docker service containers
- Run full Playwright browser test suites as part of every commit or pull request
- Parallelize test execution using GitHub Actions matrix or GitLab CI parallel jobs
- Upload test reports, screenshots, and auth state as CI artifacts for debugging

### Why AI-DDTK for CI/CD?

Traditional WordPress E2E testing in CI requires either:
1. **Hardcoded credentials** — brittle, a security risk, breaks when passwords rotate
2. **Static test users** — needs manual setup in each environment
3. **Session cookie injection** — complex to maintain across WordPress versions

AI-DDTK solves this with `pw-auth login`, which generates one-time WP-CLI login URLs and captures the resulting Playwright session to disk. In CI:
- No credentials appear in test code
- Auth works on a freshly installed WordPress with no prior state
- The auth state file can be shared between jobs as an artifact

---

## Prerequisites

### Node.js

AI-DDTK requires **Node.js 18 or later**. Node 20 LTS is recommended for CI.

```bash
# Verify version
node --version  # should be >= 18.0.0
```

### AI-DDTK Installation

Install from the repository:

```bash
# Install globally (recommended for CI)
npm install -g ai-ddtk

# Or install locally
npm ci
```

Verify `pw-auth` is available:

```bash
pw-auth --version
```

### Docker (for service containers)

Both the GitHub Actions and GitLab CI examples spin up WordPress and MySQL using Docker service containers. These require:

- **GitHub Actions**: Available on all `ubuntu-latest` runners (Docker is pre-installed)
- **GitLab CI**: Requires a GitLab Runner configured with the `docker` executor. Set `privileged = true` in the runner config for Docker-in-Docker support.

### WP-CLI

`pw-auth login` requires WP-CLI to generate one-time login URLs. In CI:

```bash
# Install WP-CLI
curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
wp --info
```

### dev-login-cli.php

This WordPress mu-plugin is required for `pw-auth login` to work. It must be installed at `wp-content/mu-plugins/dev-login-cli.php` inside the WordPress container before authentication runs.

See the [GitHub Actions walkthrough](#step-by-step-explanation) for how to copy it into the container.

### Secrets Setup

Never hardcode WordPress credentials. Use the secrets mechanism of your CI platform:

| Platform | How to add secrets |
|---|---|
| GitHub Actions | Repository → Settings → Secrets and variables → Actions → New repository secret |
| GitLab CI | Project → Settings → CI/CD → Variables → Add variable (mark as Masked) |

---

## Key Concepts for CI/CD

### Ephemeral Environments: Always Re-Login

CI runners are stateless. Each run starts from a clean workspace — no files from previous runs exist. This means:

- **Auth state files do not persist between runs**
- **You must call `pw-auth login --force` on every CI run**
- The `--force` flag bypasses pw-auth's 12-hour cache check (irrelevant in CI since there is no cache to check)

Without `--force`, pw-auth would check for an existing `./temp/playwright/.auth/admin.json` and may return an error or stale state rather than authenticating fresh.

```bash
# CORRECT for CI — always re-authenticate
pw-auth login --site-url "$WP_SITE_URL" --user "$WP_ADMIN_USER" --force

# WRONG for CI — relies on a cache that doesn't exist
pw-auth login --site-url "$WP_SITE_URL" --user "$WP_ADMIN_USER"
```

### Secrets Management

Never hardcode credentials in YAML workflows or test code. Canonical patterns:

**GitHub Actions:**
```yaml
env:
  WP_ADMIN_USER: ${{ secrets.WP_ADMIN_USER }}
  WP_ADMIN_PASS: ${{ secrets.WP_ADMIN_PASS }}
  WP_SITE_URL: ${{ secrets.WP_SITE_URL }}
```

**GitLab CI:**
```yaml
variables:
  WP_ADMIN_USER: $WP_ADMIN_USER    # from CI/CD variable settings
  WP_ADMIN_PASS: $WP_ADMIN_PASS
  WP_SITE_URL: $WP_SITE_URL
```

### Service Containers for WordPress + MySQL

CI platforms support "service containers" — Docker containers that run alongside the job container. The examples use:

| Service | Image | Purpose |
|---|---|---|
| `mysql` | `mysql:8.0` | WordPress database backend |
| `wordpress` | `wordpress:latest` | WordPress + Apache |

Services share a Docker network with the job container. WordPress can reach MySQL via the hostname `mysql` (or `db`), and the job container reaches WordPress via `wordpress` (GitLab) or `localhost:8080` (GitHub Actions with port mapping).

### Waiting for WordPress Readiness

Service containers start before job steps, but WordPress initialization takes time:
1. Apache starts
2. WordPress auto-configures the database connection
3. WordPress runs DB migrations on first request

Always poll WordPress before attempting auth:

```bash
until curl -sf "$WP_SITE_URL/wp-login.php" -o /dev/null; do
  sleep 5
done
echo "WordPress is ready"
```

### Running the WordPress Installer

The `wordpress:latest` Docker image creates database tables on first request, but does **not** run the WordPress CLI installer. The `wp core install` command creates the admin user that `pw-auth login` needs:

```bash
wp core install \
  --url="$WP_SITE_URL" \
  --title="CI Test Site" \
  --admin_user="$WP_ADMIN_USER" \
  --admin_password="$WP_ADMIN_PASS" \
  --admin_email="ci@example.com" \
  --skip-email
```

---

## GitHub Actions Integration

### Example File

See: [`examples/ci-cd/github-actions.yml`](../examples/ci-cd/github-actions.yml)

The workflow contains two jobs:
1. `e2e-tests` — single-runner sequential test run (suitable for small suites)
2. `e2e-tests-parallel` — matrix-sharded parallel run (for larger test suites)

### Step-by-Step Explanation

#### Trigger configuration

```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
```

Runs on pushes to `main`/`develop` and on all pull requests targeting `main`.

#### Service containers

```yaml
services:
  mysql:
    image: mysql:8.0
    env:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wordpress
      MYSQL_PASSWORD: wordpresspassword
    options: >-
      --health-cmd="mysqladmin ping --silent"
      --health-interval=10s
      --health-retries=5
    ports:
      - 3306:3306

  wordpress:
    image: wordpress:latest
    env:
      WORDPRESS_DB_HOST: mysql:3306
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: wordpresspassword
      WP_ENVIRONMENT_TYPE: development
    options: >-
      --health-cmd="curl -f http://localhost:80/"
      --health-interval=15s
      --health-retries=10
    ports:
      - 8080:80
```

`WP_ENVIRONMENT_TYPE: development` is required so that `dev-login-cli.php` is permitted to issue login tokens. This plugin blocks itself when `WP_ENVIRONMENT_TYPE` is `production`.

#### Installing dev-login-cli.php

```yaml
- name: Install dev-login-cli.php into WordPress container
  run: |
    CONTAINER_ID=$(docker ps --filter "ancestor=wordpress:latest" --format "{{.ID}}" | head -1)
    docker exec "$CONTAINER_ID" mkdir -p /var/www/html/wp-content/mu-plugins
    docker cp templates/dev-login-cli.php \
      "$CONTAINER_ID":/var/www/html/wp-content/mu-plugins/dev-login-cli.php
```

The template is bundled in the AI-DDTK repository at `templates/dev-login-cli.php`.

#### Creating a WP-CLI Docker wrapper

`pw-auth login` calls WP-CLI to generate a login URL, but WP-CLI needs access to the WordPress filesystem — which lives inside the Docker container, not on the runner. We solve this with a thin wrapper script:

```yaml
- name: Create WP-CLI wrapper for Docker container
  run: |
    CONTAINER_ID=$(docker ps --filter "ancestor=wordpress:latest" --format "{{.ID}}" | head -1)
    cat > /usr/local/bin/wp-docker <<EOF
    #!/bin/bash
    docker exec "$CONTAINER_ID" wp --allow-root --path=/var/www/html "\$@"
    EOF
    chmod +x /usr/local/bin/wp-docker
```

Then pass `--wp-cli "wp-docker"` to `pw-auth login`.

#### Authentication step

```yaml
- name: Run pw-auth login
  run: |
    mkdir -p temp/playwright/.auth
    pw-auth login \
      --site-url "$WP_SITE_URL" \
      --user "$WP_ADMIN_USER" \
      --wp-cli "wp-docker" \
      --force
```

#### Playwright test run

```yaml
- name: Run Playwright tests
  run: |
    npx playwright test \
      --reporter=html,list \
      --output="$PLAYWRIGHT_OUTPUT_DIR"
  env:
    WP_SITE_URL: ${{ env.WP_SITE_URL }}
    PLAYWRIGHT_CHROMIUM_LAUNCH_ARGS: '--no-sandbox --disable-setuid-sandbox'
```

The `--no-sandbox` flag is **required** in Docker containers (see [Common Issues](#browser-launch-failures)).

#### Artifact upload

```yaml
- name: Upload Playwright test report
  uses: actions/upload-artifact@v4
  if: always()
  with:
    name: playwright-report
    path: playwright-report/
    retention-days: 14
```

`if: always()` ensures the report is uploaded even when tests fail.

### Configuring Secrets in GitHub

1. Navigate to your repository → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add each secret:

| Secret Name | Example Value | Notes |
|---|---|---|
| `WP_ADMIN_USER` | `admin` | WordPress admin username |
| `WP_ADMIN_PASS` | `securepassword123` | WordPress admin password — mark as secret |
| `WP_SITE_URL` | `http://localhost:8080` | URL inside the CI job |

For organization-wide secrets (shared across repos): **Organization** → Settings → Secrets and variables → Actions.

### Artifact Collection

After each workflow run, artifacts are accessible from the **Actions** tab:

- **`playwright-report`** — HTML report with test results, screenshots, videos
- **`pw-auth-state`** — Auth state JSON files (expires after 1 day)

Download artifacts via the GitHub API:
```bash
gh run download <run-id> --name playwright-report
```

### Parallel Test Execution with Matrix Strategy

The `e2e-tests-parallel` job in the example uses GitHub Actions matrix sharding:

```yaml
strategy:
  fail-fast: false
  matrix:
    shard: [1, 2, 3]
```

Each shard runs independently with its own WordPress container and re-authenticates. The `--shard` flag tells Playwright which subset of tests to run:

```bash
npx playwright test --shard="${{ matrix.shard }}/${{ strategy.job-total }}"
```

**Choosing the right shard count:**
- 3 shards ≈ 3× speedup (assuming sufficient test count)
- For very small test suites, sharding adds overhead without benefit
- For large suites (100+ tests), consider 4–6 shards

### Caching Strategies

**npm cache** (via `actions/setup-node`):
```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'
```

**Playwright browser cache:**
```yaml
- uses: actions/cache@v4
  with:
    path: ~/.cache/ms-playwright
    key: playwright-${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}
```

Even on a cache hit, run `npx playwright install-deps` to ensure OS system libraries are up to date (they are not cached).

---

## GitLab CI Integration

### Example File

See: [`examples/ci-cd/gitlab-ci.yml`](../examples/ci-cd/gitlab-ci.yml)

The pipeline has four stages:
1. `setup` — install dependencies and browsers
2. `auth` — run `pw-auth login`, produce auth artifact
3. `test` — run Playwright tests (single job + parallel matrix job)
4. `report` — merge per-shard HTML reports

### Configuring CI/CD Variables in GitLab

1. Navigate to your project → **Settings** → **CI/CD** → **Variables**
2. Click **Add variable**
3. Configure each variable:

| Variable | Value | Options |
|---|---|---|
| `WP_ADMIN_USER` | `admin` | Masked: No (not sensitive) |
| `WP_ADMIN_PASS` | `securepassword123` | Masked: **Yes**, Protected: Yes |
| `WP_SITE_URL` | `http://wordpress` | Masked: No |

**Note:** GitLab masked variables cannot contain certain characters (e.g., `@`, `$`). For complex passwords, consider base64-encoding the value and decoding in the script.

### Artifact and Cache Configuration

**node_modules cache** (shared across jobs in same pipeline):
```yaml
cache:
  key:
    files:
      - package-lock.json
  paths:
    - .npm/
    - node_modules/
  policy: pull-push   # install job writes; test jobs read
```

**Auth state artifact** (passed from `authenticate` → `e2e-tests`):
```yaml
artifacts:
  paths:
    - temp/playwright/.auth/
  expire_in: 1 hour   # auth tokens are short-lived
```

**Test report artifact:**
```yaml
artifacts:
  when: always   # upload even on failure
  paths:
    - playwright-report/
  reports:
    junit: playwright-report/results.xml   # GitLab test report UI
  expire_in: 14 days
```

The `reports: junit` key enables GitLab's built-in test report visualization (found in the pipeline's **Tests** tab).

### Job Dependencies with `needs`

```yaml
e2e-tests:
  needs:
    - job: authenticate
      artifacts: true   # download auth state from authenticate job
```

`artifacts: true` tells GitLab to download the auth artifact produced by the `authenticate` job before running `e2e-tests`. Without this, the auth file would not be present.

### Parallel Execution with `parallel: matrix`

```yaml
e2e-tests-parallel:
  parallel:
    matrix:
      - SHARD_INDEX: ["1", "2", "3"]
        TOTAL_SHARDS: ["3"]
```

This creates three jobs: `e2e-tests-parallel: [1/3]`, `[2/3]`, `[3/3]`. Each job has `SHARD_INDEX` and `TOTAL_SHARDS` as environment variables:

```bash
npx playwright test --shard="${SHARD_INDEX}/${TOTAL_SHARDS}"
```

Note: Unlike GitHub Actions, GitLab matrix jobs each get their own service containers, so each shard must re-authenticate independently (no shared auth artifact between matrix jobs).

### GitLab Runner Configuration

For Docker service containers to work, your GitLab Runner must use the **docker executor**:

```toml
# /etc/gitlab-runner/config.toml
[[runners]]
  executor = "docker"
  [runners.docker]
    image = "node:20"
    privileged = true     # required for Docker-in-Docker
    disable_cache = false
    volumes = ["/cache"]
```

`privileged = true` is required if you need Docker-in-Docker (running Docker commands inside the job container). For service containers only (no nested Docker), you can set `privileged = false`.

---

## Handling Auth State in CI

### Why Re-Authentication Is Required on Every Run

Ephemeral CI environments create a fresh workspace for every job run. There is no persistent file storage between runs. This means:

1. `temp/playwright/.auth/admin.json` does not exist at job start
2. pw-auth's 12-hour cache check is irrelevant — there is nothing to check
3. `pw-auth login` with `--force` is the correct approach

**Always use `--force` in CI:**
```bash
pw-auth login --site-url "$WP_SITE_URL" --force
```

### How pw-auth login Works Headlessly in CI

When `pw-auth login` runs in CI:

1. Calls WP-CLI to generate a one-time login URL:
   ```bash
   wp user one-time-login "$WP_ADMIN_USER"
   ```
2. Launches a headless Playwright/Chromium browser (no display required in CI)
3. Navigates to the login URL
4. WordPress sets session cookies
5. Playwright captures the session as `storageState` and writes it to `temp/playwright/.auth/admin.json`

Playwright's headless mode works out of the box on most CI runners (no display server needed). The only requirement is the `--no-sandbox` Chromium flag (see [Browser Launch Failures](#browser-launch-failures)).

### Sharing Auth State Between Jobs as an Artifact

If you have multiple jobs that need authenticated access (e.g., a test job and a visual regression job), the most efficient approach is:

1. Authenticate once in a dedicated `auth` job
2. Upload auth state as an artifact
3. Download the artifact in downstream jobs

**GitHub Actions — upload:**
```yaml
- uses: actions/upload-artifact@v4
  with:
    name: pw-auth-state
    path: temp/playwright/.auth/
    retention-days: 1
```

**GitHub Actions — download in downstream job:**
```yaml
- uses: actions/download-artifact@v4
  with:
    name: pw-auth-state
    path: temp/playwright/.auth/
```

**GitLab CI — in the authenticate job:**
```yaml
artifacts:
  paths:
    - temp/playwright/.auth/
  expire_in: 1 hour
```

**GitLab CI — in the test job:**
```yaml
needs:
  - job: authenticate
    artifacts: true
```

### Validating Auth State Before Tests

After downloading the auth artifact, validate it before running tests to fail fast:

```bash
# Check file exists
if [ ! -f "temp/playwright/.auth/admin.json" ]; then
  echo "ERROR: Auth state not found"
  exit 1
fi

# Use pw-auth status for a richer check
pw-auth status
```

### Auth State in Playwright Tests

Tests load the auth state via Playwright's `storageState` option:

```javascript
// playwright.config.js
module.exports = {
  use: {
    storageState: 'temp/playwright/.auth/admin.json',
    baseURL: process.env.WP_SITE_URL,
  },
};
```

Or per-context:
```javascript
const context = await browser.newContext({
  storageState: 'temp/playwright/.auth/admin.json',
});
```

---

## Common CI/CD Issues & Fixes

### Browser Launch Failures

**Symptom:**
```
Error: Failed to launch chromium because executable doesn't exist at ...
  or
browserType.launch: Cannot find chromium
  or
chromium: error while loading shared libraries: libnss3.so
```

**Root cause:** Missing Playwright browser binaries or missing OS system libraries.

**Fix:**
```bash
# Install browsers WITH system dependencies
npx playwright install --with-deps chromium

# On cache hit (browsers exist but OS deps may not be installed):
npx playwright install-deps
```

---

**Symptom:**
```
Error: Failed to launch the browser process!
...
FATAL:zygote_host_impl_linux.cc ... No usable sandbox
```

**Root cause:** Chromium requires a user namespace sandbox that is disabled in most Docker containers.

**Fix:** Pass `--no-sandbox` flag to Chromium. This can be done several ways:

1. **Via environment variable** (in CI step):
   ```yaml
   env:
     PLAYWRIGHT_CHROMIUM_LAUNCH_ARGS: '--no-sandbox --disable-setuid-sandbox'
   ```

2. **Via `playwright.config.js`:**
   ```javascript
   module.exports = {
     use: {
       launchOptions: {
         args: ['--no-sandbox', '--disable-setuid-sandbox'],
       },
     },
   };
   ```

3. **Per-browser launch:**
   ```javascript
   const browser = await chromium.launch({
     args: ['--no-sandbox', '--disable-setuid-sandbox'],
   });
   ```

---

### WordPress Not Ready

**Symptom:**
```
curl: (7) Failed to connect to localhost port 8080: Connection refused
  or
Error: wp core install failed: Error establishing a database connection
```

**Root cause:** Tests or auth ran before WordPress finished initializing.

**Fix:** Add a readiness poll before any WordPress operations:

```bash
MAX_ATTEMPTS=30
ATTEMPT=0
until curl -sf "$WP_SITE_URL/wp-login.php" -o /dev/null; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ "$ATTEMPT" -ge "$MAX_ATTEMPTS" ]; then
    echo "ERROR: WordPress did not become ready"
    exit 1
  fi
  echo "Attempt $ATTEMPT/$MAX_ATTEMPTS — waiting 5s..."
  sleep 5
done
echo "WordPress is ready"
```

Adjust `MAX_ATTEMPTS` and sleep duration for slow CI environments. Cold Docker pulls (first run after image update) can take 2–3 minutes.

**Health check configuration in service definitions:**
```yaml
# GitHub Actions
options: >-
  --health-cmd="curl -f http://localhost:80/"
  --health-interval=15s
  --health-retries=10
  --health-start-period=30s  # Give WP extra time before first check
```

---

### Auth State Expiration Mid-Run

**Symptom:** Tests fail with `401 Unauthorized` or redirect to the login page mid-run.

**Root cause:** The 12-hour auth cache expired while a long-running test suite was executing.

**Prevention:**
- Always re-authenticate at the start of each CI run (use `--force`)
- Keep test suites under 30 minutes for safety
- For very long test runs, add mid-run re-auth between test groups:
  ```bash
  pw-auth login --site-url "$WP_SITE_URL" --force
  npx playwright test tests/group1/
  pw-auth login --site-url "$WP_SITE_URL" --force
  npx playwright test tests/group2/
  ```

---

### Timeout Tuning for Slow CI Environments

**Symptom:** Tests fail with `TimeoutError: page.goto() exceeded ...ms`

**Root cause:** CI environments (especially free-tier runners) can be 2–5× slower than local machines. Default Playwright timeouts (30s for navigation, 5s for assertions) may be too tight.

**Fix:** Increase timeouts in `playwright.config.js`:
```javascript
module.exports = {
  timeout: 60000,       // 60s per test (default: 30s)
  expect: {
    timeout: 10000,     // 10s for assertions (default: 5s)
  },
  use: {
    navigationTimeout: 30000,  // 30s for navigations
    actionTimeout: 15000,      // 15s for clicks, fills, etc.
  },
};
```

For pw-auth specifically:
```bash
# Increase selector timeout for slow CI environments
pw-auth check dom \
  --url "$WP_SITE_URL/wp-admin/" \
  --selector "#wpbody" \
  --extract exists \
  --timeout-ms 30000
```

---

### WP-CLI Cannot Connect to WordPress in Docker

**Symptom:**
```
Error: Error establishing a database connection
```

**Root cause:** WP-CLI is running on the runner host and cannot reach the WordPress filesystem or database inside the Docker container.

**Fix:** Use a WP-CLI wrapper that runs inside the container via `docker exec`:

```bash
# Create the wrapper
CONTAINER_ID=$(docker ps --filter "ancestor=wordpress:latest" --format "{{.ID}}" | head -1)
cat > /usr/local/bin/wp-docker <<'EOF'
#!/bin/bash
docker exec "$CONTAINER_ID" wp --allow-root --path=/var/www/html "$@"
EOF
chmod +x /usr/local/bin/wp-docker

# Use it with pw-auth
pw-auth login --site-url "$WP_SITE_URL" --wp-cli "wp-docker" --force
```

---

### GitLab: Services Not Reachable

**Symptom:** `curl: (6) Could not resolve host: wordpress`

**Root cause:** GitLab CI service aliases are only available when using the `docker` executor. The `shell` executor does not support service containers.

**Fix:** Verify your runner uses the `docker` executor:
```bash
gitlab-runner list
# Should show: Executor=docker
```

Also check the service alias matches what you reference in the pipeline:
```yaml
services:
  - name: wordpress:latest
    alias: wordpress   # use "wordpress" as the hostname
```

---

### npm ci Fails: package-lock.json Missing

**Symptom:** `npm ci` can only install packages when your package.json and package-lock.json or npm-shrinkwrap.json are in sync.

**Fix:** Commit `package-lock.json` to the repository. Never add it to `.gitignore`.

---

## Environment Variables Reference

All environment variables used across the CI examples:

| Variable | Required | Default | Description |
|---|---|---|---|
| `WP_SITE_URL` | Yes | — | WordPress site URL inside CI (e.g. `http://localhost:8080`) |
| `WP_ADMIN_USER` | Yes | `admin` | WordPress admin username for pw-auth login |
| `WP_ADMIN_PASS` | Yes | — | WordPress admin password (secret) |
| `WP_ENVIRONMENT_TYPE` | Yes | — | Must be set to `development` in the WP container |
| `PLAYWRIGHT_OUTPUT_DIR` | No | `playwright-report` | Directory for Playwright HTML report output |
| `PLAYWRIGHT_CHROMIUM_LAUNCH_ARGS` | No | — | Extra Chromium launch flags (e.g. `--no-sandbox`) |
| `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD` | No | `0` | Set to `1` to skip browser download during `npm ci` |
| `MYSQL_ROOT_PASSWORD` | Yes | — | MySQL root password for service container |
| `MYSQL_DATABASE` | Yes | `wordpress` | MySQL database name for WordPress |
| `MYSQL_USER` | Yes | `wordpress` | MySQL user for WordPress |
| `MYSQL_PASSWORD` | Yes | — | MySQL password for the WordPress user |
| `NODE_VERSION` | No | `20` | Node.js version for `actions/setup-node` |

### pw-auth Environment Variable Support

`pw-auth` reads these environment variables as fallbacks when CLI flags are not provided:

| Variable | pw-auth Flag | Description |
|---|---|---|
| `PW_AUTH_SITE_URL` | `--site-url` | WordPress site URL |
| `PW_AUTH_USER` | `--user` | WordPress username |
| `PW_AUTH_WP_CLI` | `--wp-cli` | WP-CLI command prefix |
| `PW_AUTH_AUTH_FILE` | `--auth-file` | Custom auth state file path |

---

## Security Best Practices

### Never Hardcode Credentials

Credentials hardcoded in YAML files or test code will be leaked in:
- Repository history (even after `git rm`)
- Build logs visible to all collaborators
- Forked repositories

**Always use platform secrets:**
- GitHub: `${{ secrets.MY_SECRET }}`
- GitLab: `$MY_VARIABLE` (masked variable)

### Least-Privilege WordPress User

For read-only test scenarios, authenticate as an Editor or Contributor rather than Admin:

```bash
pw-auth login --site-url "$WP_SITE_URL" --user "$WP_EDITOR_USER" --force
```

Reserve Admin-level auth only for tests that specifically require admin capabilities.

### Artifact Retention Policies

Auth state files contain session tokens. Set short retention periods:

```yaml
# GitHub Actions
- uses: actions/upload-artifact@v4
  with:
    retention-days: 1   # auth tokens expire in 12h anyway
```

```yaml
# GitLab CI
artifacts:
  expire_in: 1 hour
```

For test reports (no sensitive data), 14 days is a reasonable default.

### Do Not Run dev-login-cli.php in Production

The `dev-login-cli.php` mu-plugin generates authentication tokens without requiring a password. This is intentional for development and CI use only.

The plugin self-blocks when `WP_ENVIRONMENT_TYPE` is `production`:

```php
if ( 'production' === wp_get_environment_type() ) {
    return; // Do nothing
}
```

Never install this plugin on a production WordPress site.

### Restrict Secret Scope

**GitHub Actions:**
- Use environment-scoped secrets for staging/production differentiation
- Enable "Required reviewers" for deployments to production environments
- Use `permissions:` to limit job token scopes:
  ```yaml
  permissions:
    contents: read
    actions: read
  ```

**GitLab CI:**
- Mark sensitive variables as **Protected** to restrict them to protected branches
- Mark sensitive variables as **Masked** to hide values in logs
- Use GitLab environments to scope credentials to specific deployment targets

### Validate Inputs in CI Scripts

When using CI variables in shell scripts, quote variables to prevent word splitting:

```bash
# Safe — quoted
pw-auth login --site-url "$WP_SITE_URL" --user "$WP_ADMIN_USER" --force

# Unsafe — unquoted (could break on spaces or special characters)
pw-auth login --site-url $WP_SITE_URL --user $WP_ADMIN_USER --force
```

### Audit Workflow Permissions

For GitHub Actions, review third-party actions before use. This guide uses only official GitHub actions:
- `actions/checkout@v4` — official
- `actions/setup-node@v4` — official
- `actions/upload-artifact@v4` — official
- `actions/download-artifact@v4` — official
- `actions/cache@v4` — official

Pin action versions with full SHA for maximum security in regulated environments:
```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

---

## See Also

- [PW-AUTH-COMMANDS.md](./PW-AUTH-COMMANDS.md) — Complete pw-auth command reference
- [CLI-REFERENCE.md](./CLI-REFERENCE.md) — All AI-DDTK commands
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) — Common errors and solutions
- [WORDPRESS-TESTING-QUICKSTART.md](./WORDPRESS-TESTING-QUICKSTART.md) — 5-minute setup guide
- [AGENTS.md](../AGENTS.md) — AI agent guidelines and toolkit overview
- [`examples/ci-cd/github-actions.yml`](../examples/ci-cd/github-actions.yml) — GitHub Actions example
- [`examples/ci-cd/gitlab-ci.yml`](../examples/ci-cd/gitlab-ci.yml) — GitLab CI example
