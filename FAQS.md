# WP Code Check - Frequently Asked Questions

---

## Why should I care about this Code Check Tool?

**Because WordPress sites crash in production from issues that slip through code review.** These aren't syntax errors — they're performance antipatterns that work perfectly in development but explode at scale:

- A `posts_per_page => -1` query works fine with 10 posts, but crashes the server when your client has 50,000 posts
- N+1 query patterns that turn 1 request into 1,000 database calls
- Missing capability checks that let subscribers delete your entire site
- Debug code (`var_dump`, `console.log`) that exposes sensitive data to users

**WP Code Check catches these issues in seconds** — before they cause downtime, security breaches, or angry 3 AM support calls.

---

## What does this catch that PHP Lint and PHP CS don't catch?

| Issue Type | PHP Lint | PHPCS/WPCS | WP Code Check |
|------------|----------|------------|---------------|
| **Unbounded queries** (`posts_per_page => -1`) | ❌ | ❌ | ✅ |
| **N+1 patterns** (queries in loops) | ❌ | ❌ | ✅ |
| **Missing capability checks** | ❌ | ⚠️ Partial | ✅ |
| **AJAX without nonce validation** | ❌ | ⚠️ Partial | ✅ |
| **Insecure deserialization** | ❌ | ❌ | ✅ |
| **Debug code in production** | ❌ | ⚠️ Partial | ✅ |
| **SQL without LIMIT** | ❌ | ❌ | ✅ |
| **file_get_contents() with URLs** | ❌ | ❌ | ✅ |
| **Syntax errors** | ✅ | ✅ | ❌ |
| **Coding standards** | ❌ | ✅ | ❌ |

**Bottom line:** PHP Lint catches broken code. PHPCS catches ugly code. WP Code Check catches **dangerous** code that will crash your production site.

---

## How fast can I install it?

**About 30 seconds:**

```bash
# Clone the repo
git clone https://github.com/YOUR_ORG/wp-code-check.git

# Run it
./wp-code-check/dist/bin/check-performance.sh --paths /your/plugin
```

That's it. No Composer. No PHP extensions. No configuration files. It's just Bash + grep, so it runs anywhere.

---

## Can I use this in my CI/CD pipeline?

**Absolutely. That's the primary use case.** WP Code Check is designed for automated CI/CD integration:

```yaml
# GitHub Actions example
- name: Run WP Code Check
  run: |
    git clone https://github.com/YOUR_ORG/wp-code-check.git
    ./wp-code-check/dist/bin/check-performance.sh --paths . --format json
```

**Key CI/CD features:**
- **JSON output** (`--format json`) for machine parsing
- **Exit codes** — returns non-zero on errors for pipeline failure
- **Strict mode** (`--strict`) — fail on warnings too
- **Baseline support** — only flag new issues in legacy codebases
- **Fast execution** — scans 10,000 files in under 5 seconds

Works with GitHub Actions, GitLab CI, Bitbucket Pipelines, Jenkins, CircleCI, and any other CI system.

---

## What if I have a legacy codebase with hundreds of existing issues?

**Use the baseline feature.** It lets you "snapshot" your current state and only flag **new** issues going forward:

```bash
# Step 1: Generate baseline from current state
./dist/bin/check-performance.sh --paths . --generate-baseline

# Step 2: Future scans only report NEW issues
./dist/bin/check-performance.sh --paths .
```

This is perfect for:
- Legacy projects you inherited
- Large plugins/themes where fixing everything at once isn't practical
- Teams that want to prevent regression without a massive refactor

The baseline file (`.hcc-baseline`) is human-readable and can be committed to version control.

---

*Have more questions? Open an issue on [GitHub](https://github.com/YOUR_ORG/wp-code-check/issues).*

