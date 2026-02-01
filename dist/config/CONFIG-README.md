# Severity Level Configuration

This directory contains configuration files for customizing WP Code Check severity levels.

## Files

- **`severity-levels.json`** - Factory default severity levels for all 28 checks
- **`severity-levels.example.json`** - Example showing how to customize levels and add comments

## Quick Start

### 1. Copy the Factory Defaults

```bash
cp dist/config/severity-levels.json my-severity-config.json
```

### 2. Edit Severity Levels

Open `my-severity-config.json` and change the `level` field for any check:

```json
{
  "n-plus-one-pattern": {
    "id": "n-plus-one-pattern",
    "name": "Potential N+1 patterns (meta in loops)",
    "level": "CRITICAL",           // ← Change this (was MEDIUM)
    "factory_default": "MEDIUM",    // ← Don't change (reference)
    "category": "performance",
    "description": "get_post_meta, get_user_meta, or get_term_meta called inside foreach loops"
  }
}
```

### 3. Add Comments to Document Your Changes

Any field starting with underscore (`_`) is ignored by the parser:

```json
{
  "n-plus-one-pattern": {
    "id": "n-plus-one-pattern",
    "name": "Potential N+1 patterns (meta in loops)",
    "level": "CRITICAL",
    "factory_default": "MEDIUM",
    "category": "performance",
    "description": "get_post_meta, get_user_meta, or get_term_meta called inside foreach loops",
    "_comment": "Upgraded to CRITICAL - we had a production incident",
    "_ticket": "INC-1234",
    "_date": "2025-12-31",
    "_author": "john@example.com"
  }
}
```

### 4. Use Your Custom Config

```bash
./bin/check-performance.sh --severity-config my-severity-config.json
```

## Comment Field Examples

You can use any underscore-prefixed field name for documentation:

| Field Name | Purpose | Example |
|------------|---------|---------|
| `_comment` | General comment | `"Upgraded per security audit"` |
| `_note` | Additional notes | `"Only affects admin area"` |
| `_reason` | Why you changed it | `"Production incident on 2025-12-15"` |
| `_ticket` | Reference ticket | `"JIRA-1234"` or `"INC-5678"` |
| `_date` | When changed | `"2025-12-31"` |
| `_author` | Who requested | `"security-team@example.com"` |

**All underscore-prefixed fields are ignored during parsing** - use them freely for documentation!

## Severity Levels

Valid severity levels (case-sensitive):

- **`CRITICAL`** - Blocks deployment, must be fixed immediately
- **`HIGH`** - Should be fixed before production
- **`MEDIUM`** - Should be addressed soon
- **`LOW`** - Nice to fix, low priority

## Field Reference

Each check has these fields:

| Field | Editable? | Description |
|-------|-----------|-------------|
| `id` | ❌ No | Unique rule identifier (don't change) |
| `name` | ❌ No | Human-readable check name (don't change) |
| `level` | ✅ **YES** | **Current severity level (edit this!)** |
| `factory_default` | ❌ No | Original severity (reference only) |
| `category` | ❌ No | Check category (security/performance/maintenance) |
| `description` | ❌ No | What the check detects |
| `_comment` | ✅ Optional | Your documentation (ignored by parser) |

## Best Practices

### ✅ DO

- Copy `severity-levels.json` to a new file before editing
- Add `_comment` fields to document why you changed severity levels
- Reference tickets/incidents in `_ticket` or `_reason` fields
- Keep `factory_default` unchanged (it's your reference)
- Use version control for your custom config files

### ❌ DON'T

- Don't edit `severity-levels.json` directly (it may be overwritten on updates)
- Don't change `factory_default` values (defeats the purpose)
- Don't change `id`, `name`, `category`, or `description` fields
- Don't use invalid severity levels (must be CRITICAL, HIGH, MEDIUM, or LOW)

## Example Workflow

```bash
# 1. Copy factory defaults
cp dist/config/severity-levels.json .hcc-severity.json

# 2. Edit your config
vim .hcc-severity.json

# 3. Add to .gitignore if it contains sensitive comments
echo ".hcc-severity.json" >> .gitignore

# 4. Run checks with your config
./bin/check-performance.sh --severity-config .hcc-severity.json

# 5. Or set as default in your CI/CD pipeline
export HCC_SEVERITY_CONFIG=".hcc-severity.json"
./bin/check-performance.sh
```

## See Also

- **`severity-levels.example.json`** - Full example with comments
- **`../CHANGELOG.md`** - Version history
- **`../README.md`** - Main documentation
- **`../../DISCLOSURE-POLICY.md`** - Responsible disclosure and public report publication policy

