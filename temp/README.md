# /temp - Sensitive Data & Temporary Files

**Purpose**: Store sensitive data, credentials, reports, and temporary analysis files that should never be committed to git.

**Security**: This entire folder is excluded from git via `.gitignore`. Nothing here will ever be committed.

---

## 📁 Recommended Folder Structure

```
temp/
├── credentials/          # API keys, passwords, tokens
│   ├── auth.json        # Authentication credentials
│   ├── api-keys.json    # API keys for services
│   └── .env.local       # Environment variables
│
├── reports/             # Analysis reports, scan results
│   ├── wpcc/           # WP Code Check scan reports
│   ├── phpstan/        # PHPStan analysis results
│   └── performance/    # Performance profiling data
│
├── data/               # Temporary data files
│   ├── exports/        # Database exports, CSV files
│   ├── imports/        # Data to be imported
│   └── backups/        # Temporary backups
│
├── playwright/         # Playwright test data
│   └── .auth/         # Authentication state files
│
├── logs/              # Temporary log files
│   ├── debug.log      # Debug output
│   └── tmux/          # AI-DDTK tmux session captures
│
└── analysis/          # AI agent analysis files
    ├── notes/         # Temporary notes and findings
    └── drafts/        # Draft documents before moving to PROJECT/
```

---

## 🎯 What Goes Where

### `/temp/credentials/` - Sensitive Authentication
**Store**:
- API keys, passwords, tokens
- OAuth credentials
- Database connection strings
- SSH keys (temporary)
- Service account credentials

**Example**:
```bash
# Store credentials
echo '{"username":"admin","password":"secret123"}' > temp/credentials/auth.json

# Load in code
const auth = JSON.parse(fs.readFileSync('temp/credentials/auth.json', 'utf8'));
```

### `/temp/reports/` - Analysis & Scan Results
**Store**:
- WPCC scan reports (JSON, HTML)
- PHPStan analysis results
- Performance profiling data
- Security audit reports
- Code quality reports

**Example**:
```bash
# WPCC scan output
wpcc --paths . --format json > temp/reports/wpcc/scan-$(date +%Y%m%d).json

# PHPStan results
phpstan analyse --error-format=json > temp/reports/phpstan/analysis.json
```

### `/temp/data/` - Temporary Data Files
**Store**:
- Database exports with real data
- CSV files with PII
- Test data with real user information
- Temporary backups
- Data imports/exports

**Example**:
```bash
# Export database
wp db export temp/data/backups/db-backup-$(date +%Y%m%d).sql

# Export users (contains PII)
wp user list --format=csv > temp/data/exports/users.csv
```

### `/temp/playwright/` - Playwright Test Data
**Store**:
- Authentication state files (managed by `pw-auth`)
- Session storage data
- Cookies and local storage
- Test screenshots (if sensitive)

**Automated auth with `pw-auth`** (recommended):

`pw-auth` stores auth state in the **current working directory's** `temp/playwright/.auth/` folder, so each project gets its own cache. Run `pw-auth` from your project root.

If Playwright was installed globally but Node cannot resolve it in the current shell, `pw-auth` now auto-attempts `NODE_PATH="$(npm root -g)"` before failing. Manual `NODE_PATH` export is only the fallback.

```bash
# Authenticate and cache storageState automatically
pw-auth login --site-url http://my-site.local

# Check cached auth status
pw-auth status

# Auth state saved to: ./temp/playwright/.auth/<user>.json
# Cached for 12 hours, auto-refreshes on next pw-auth login
```

**Using cached auth in Playwright scripts**:
```javascript
// Load auth state — no login form interaction needed
const context = await browser.newContext({
  storageState: 'temp/playwright/.auth/admin.json'
});
const page = await context.newPage();
await page.goto('http://my-site.local/wp-admin/');
```

**Manual save** (if not using `pw-auth`):
```javascript
await page.context().storageState({ path: 'temp/playwright/.auth/admin.json' });
```

### `/temp/logs/` - Debug & Temporary Logs
**Store**:
- Debug output
- Verbose logging
- Error traces
- Performance logs
- `aiddtk-tmux` session captures

**Example**:
```bash
# Redirect verbose output
wpcc --paths . --verbose > temp/logs/wpcc-debug.log 2>&1

# AI-DDTK tmux proxy output
aiddtk-tmux start --cwd .
aiddtk-tmux send --command "~/bin/ai-ddtk/bin/wpcc --paths . --verbose"
```

### `/temp/analysis/` - AI Agent Working Files
**Store**:
- Temporary notes and findings
- Draft documents before moving to PROJECT/
- Analysis in progress
- Scratch files

**AI Agent Guidance**:
- Use `temp/analysis/notes/` for temporary findings
- Move finalized docs to `PROJECT/1-INBOX/` when complete
- Use `temp/analysis/drafts/` for work-in-progress documents

---

## 🤖 AI Agent Guidelines

### When to Use `/temp`

| Scenario | Folder | Example |
|----------|--------|---------|
| User provides credentials | `temp/credentials/` | `temp/credentials/auth.json` |
| WPCC scan output | `temp/reports/wpcc/` | `temp/reports/wpcc/scan-20260207.json` |
| PHPStan results | `temp/reports/phpstan/` | `temp/reports/phpstan/analysis.json` |
| Database export | `temp/data/backups/` | `temp/data/backups/db-backup.sql` |
| Playwright auth | `temp/playwright/.auth/` | `temp/playwright/.auth/admin.json` |
| Debug logging | `temp/logs/` | `temp/logs/debug.log` |
| Tmux session log | `temp/logs/tmux/` | `temp/logs/tmux/aiddtk-my-plugin.log` |
| Temporary notes | `temp/analysis/notes/` | `temp/analysis/notes/findings.md` |
| Draft documents | `temp/analysis/drafts/` | `temp/analysis/drafts/feature-spec.md` |

### Path Recommendations

```javascript
// ✅ CORRECT - Use temp/ for sensitive data
const auth = JSON.parse(fs.readFileSync('temp/credentials/auth.json', 'utf8'));

// ❌ WRONG - Never hardcode credentials
const auth = { username: 'admin', password: 'secret123' };

// ✅ CORRECT - Store reports in temp/
fs.writeFileSync('temp/reports/wpcc/scan.json', JSON.stringify(results));

// ❌ WRONG - Don't store reports in project root
fs.writeFileSync('scan-results.json', JSON.stringify(results));
```

---

## 🔒 Security Best Practices

1. **Never commit `/temp` contents** - Already excluded in `.gitignore`
2. **Load credentials at runtime** - Never hardcode in source files
3. **Clear sensitive data** - Delete when no longer needed
4. **Use environment variables** - For production deployments
5. **Rotate credentials** - If accidentally exposed

---

## 📋 Quick Commands

```bash
# Create recommended folder structure
mkdir -p temp/{credentials,reports/{wpcc,phpstan,performance},data/{exports,imports,backups},playwright/.auth,logs/tmux,analysis/{notes,drafts}}

# Check what's in temp (without showing contents)
find temp -type f | head -20

# Clear old reports (older than 30 days)
find temp/reports -type f -mtime +30 -delete

# Clear all temp data (use with caution!)
rm -rf temp/*
```

---

## 📚 Related Documentation

- **[AGENTS.md - Sensitive Data Handling](../AGENTS.md#sensitive-data-handling)** - Complete security guidelines
- **[AGENTS.md - Playwright Auth](../AGENTS.md#-playwright-auth-wp-admin-login)** - `pw-auth` setup and usage
- **[AGENTS.md - Tmux Proxy for Flaky Agent Terminals](../AGENTS.md#-tmux-proxy-for-flaky-agent-terminals)** - Resilient session workflow
- **[AGENTS.md - WPCC Orchestration](../AGENTS.md#wpcc-orchestration)** - Where to store WPCC reports
- **[README.md](../README.md)** - Project overview and setup

---

**Remember**: Everything in `/temp` is temporary and sensitive. Never commit, never share, never log.

