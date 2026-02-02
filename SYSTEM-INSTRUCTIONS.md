# AI-DDTK System Instructions for AI Agents

**Copy this into your AI agent's custom instructions (Augment, Claude Code, etc.)**

---

## AI-DDTK Toolkit Integration

This workspace has access to **AI-DDTK** (AI Driven Development ToolKit) installed at `~/bin/ai-ddtk`.

### Before Starting Any Task

1. **Check for AI-DDTK availability**:
   ```bash
   ls ~/bin/ai-ddtk/AGENTS.md
   ```

2. **For WordPress projects**, read the guidelines:
   ```bash
   cat ~/bin/ai-ddtk/AGENTS.md
   ```

3. **Check available tools**:
   ```bash
   which wpcc
   wpcc --features
   ```

---

## Available Tools

### WPCC (WordPress Code Check)
- **Purpose**: Security and performance static analysis for WordPress code
- **Usage**: `wpcc --paths <path> --format json`
- **Features**: `wpcc --features` (shows all capabilities)
- **Documentation**: `~/bin/ai-ddtk/tools/wp-code-check/dist/TEMPLATES/_AI_INSTRUCTIONS.md`

### WP Performance Timer
- **Purpose**: Runtime performance profiling (requires WordPress plugin)
- **Usage**: Insert timers with `perf_timer_start()` / `perf_timer_stop()`
- **Documentation**: `~/bin/ai-ddtk/AGENTS.md` (Performance Profiling section)

### Workflow Recipes
- **Location**: `~/bin/ai-ddtk/recipes/`
- **Available**: `performance-audit.md` (WPCC → Performance Timer pipeline)

---

## WordPress Development Guidelines

**Always follow SOLID principles** alongside WordPress patterns:
- **Single Responsibility**: One reason to change per class/function
- **Open/Closed**: Extend, don't modify
- **Liskov Substitution**: Subtypes must be replaceable
- **Interface Segregation**: Small, focused interfaces
- **Dependency Inversion**: Depend on abstractions, not concrete implementations

**Key practices**:
- Sanitize inputs, escape outputs, verify nonces, check capabilities
- Use `$wpdb->prepare()` for all database queries
- No unbounded queries (always use LIMIT)
- Cache expensive operations via Transients API
- Set timeouts for HTTP requests with retry logic
- Never expose sensitive data in logs or commits

**Full guidelines**: `~/bin/ai-ddtk/AGENTS.md`

---

## Security: Sensitive Data Handling

### Never Commit Sensitive Data

**Always use `/temp` folder for**:
- Credentials (API keys, passwords, tokens)
- PII (Personally Identifiable Information)
- Server configuration data
- Test data with real user information
- Playwright authentication state files
- Database dumps with real data

### Required Setup for Every Project

1. **Create `/temp` folder**:
   ```bash
   mkdir -p temp
   ```

2. **Add to `.gitignore`**:
   ```
   # Sensitive data - never commit
   /temp/
   temp/
   *.credentials
   *.env.local
   auth.json
   playwright/.auth/
   ```

3. **Store credentials in `/temp`**:
   ```bash
   # Example: Playwright auth
   temp/playwright-auth.json
   
   # Example: API credentials
   temp/api-credentials.json
   
   # Example: Database config
   temp/db-config.local.php
   ```

### When User Provides Credentials

**If user provides credentials for Playwright, testing, or API access**:

1. ✅ **DO**: Save to `/temp` folder
2. ✅ **DO**: Add to `.gitignore` immediately
3. ✅ **DO**: Use environment variables when possible
4. ✅ **DO**: Document in `/temp/README.md` what files are needed
5. ❌ **DON'T**: Save credentials in source code
6. ❌ **DON'T**: Commit credentials to git (even temporarily)
7. ❌ **DON'T**: Log credentials in debug output

**Example**:
```javascript
// ❌ WRONG - hardcoded credentials
const auth = { username: 'admin', password: 'secret123' };

// ✅ CORRECT - load from /temp
const auth = JSON.parse(fs.readFileSync('temp/auth.json', 'utf8'));
```

---

## Workflow Triggers

### When to Use WPCC

- User mentions: "scan", "audit", "security check", "performance check"
- Before deploying WordPress code
- After making significant changes to WordPress plugins/themes
- When investigating potential security issues

### When to Use Performance Timer

- User mentions: "slow", "performance", "bottleneck", "profile"
- After WPCC flags performance warnings (confirm with runtime data)
- Before/after optimization comparisons
- Pre-deploy performance baselines

### When to Use Recipes

- User asks for "performance audit" → `recipes/performance-audit.md`
- Complex multi-tool workflows → Check `~/bin/ai-ddtk/recipes/`

---

## Task Management

Use task management tools frequently for:
- Complex sequences of work
- Breaking down large tasks
- Tracking progress
- Giving user visibility

Mark tasks COMPLETE immediately when done (don't batch).

---

## Scope Control

- **Do what's asked, nothing more**
- **No refactoring/renaming** unless explicitly requested, but **do point out code that violates SOLID principles** and recommend improvements
- **No speculative improvements** or architectural changes
- **Preserve existing data structures** and naming conventions
- **Ask before**: committing, pushing, installing dependencies, deploying

---

## Quick Reference

```bash
# Check AI-DDTK is available
ls ~/bin/ai-ddtk/

# Read WordPress guidelines
cat ~/bin/ai-ddtk/AGENTS.md

# Scan WordPress code
wpcc --paths /path/to/plugin --format json

# Show all WPCC features
wpcc --features

# View workflow recipes
ls ~/bin/ai-ddtk/recipes/
```

---

**Remember**: AI-DDTK is an orchestration layer. It's not just tools—it's tools + instructions for using them effectively.

