# local-wp Command Reference

Detailed guide to the Local by Flywheel WP-CLI wrapper for easy WordPress site management.

**Last Updated:** 2026-03-22  
**Version:** 1.0.0

---

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Basic Usage](#basic-usage)
4. [Common Commands](#common-commands)
5. [Environment Variables](#environment-variables)
6. [Exit Codes](#exit-codes)
7. [Troubleshooting](#troubleshooting)
8. [Examples](#examples)

---

## Overview

`local-wp` is a WP-CLI wrapper that simplifies running WordPress commands on Local by Flywheel sites. It automatically detects Local paths, PHP binaries, and MySQL sockets.

**Key Features:**
- ✅ Auto-detects Local site paths
- ✅ Auto-detects PHP binary and version
- ✅ Auto-configures MySQL socket
- ✅ Supports all WP-CLI commands
- ✅ Environment variable overrides
- ✅ Debug mode for troubleshooting

---

## Installation

`local-wp` is included with AI-DDTK. Verify installation:

```bash
local-wp --help
local-wp --list
```

---

## Basic Usage

### Syntax

```bash
local-wp <site-name> <wp-cli-command> [args...]
```

### Quick Examples

```bash
# List available sites
local-wp --list

# Get WordPress version
local-wp my-site core version

# List plugins
local-wp my-site plugin list

# Get site URL
local-wp my-site option get siteurl
```

---

## Common Commands

### Site Information

#### List Available Sites

```bash
local-wp --list
```

**Output:**
```
Available Local sites:
  • my-site (http://my-site.local)
  • another-site (http://another-site.local)
  • staging-site (http://staging-site.local)
```

#### Get WordPress Version

```bash
local-wp <site-name> core version
```

**Example:**
```bash
local-wp my-site core version
# Output: 6.4.2
```

#### Get Site URL

```bash
local-wp <site-name> option get siteurl
```

**Example:**
```bash
local-wp my-site option get siteurl
# Output: http://my-site.local
```

#### Get Site Info

```bash
local-wp <site-name> core version --extra
```

**Example:**
```bash
local-wp my-site core version --extra
# Output: WordPress version: 6.4.2
#         Database version: 8.0.35
#         PHP version: 8.2.0
```

---

### Plugin Management

#### List All Plugins

```bash
local-wp <site-name> plugin list
```

**Options:**
- `--status=active` — List only active plugins
- `--status=inactive` — List only inactive plugins
- `--format=table` — Table format (default)
- `--format=json` — JSON format
- `--format=csv` — CSV format

**Examples:**
```bash
# List all plugins
local-wp my-site plugin list

# List active plugins only
local-wp my-site plugin list --status=active

# JSON output
local-wp my-site plugin list --format=json

# Table format
local-wp my-site plugin list --format=table
```

#### Get Plugin Info

```bash
local-wp <site-name> plugin get <plugin-slug>
```

**Example:**
```bash
local-wp my-site plugin get woocommerce
# Output: Plugin Name: WooCommerce
#         Status: active
#         Version: 8.5.0
```

#### Activate Plugin

```bash
local-wp <site-name> plugin activate <plugin-slug>
```

**Example:**
```bash
local-wp my-site plugin activate my-plugin
# Output: Plugin 'my-plugin' activated.
```

#### Deactivate Plugin

```bash
local-wp <site-name> plugin deactivate <plugin-slug>
```

**Example:**
```bash
local-wp my-site plugin deactivate my-plugin
# Output: Plugin 'my-plugin' deactivated.
```

#### Install Plugin

```bash
local-wp <site-name> plugin install <plugin-slug>
```

**Example:**
```bash
local-wp my-site plugin install woocommerce
# Output: Installing WooCommerce (8.5.0)...
#         Plugin installed successfully.
```

#### Delete Plugin

```bash
local-wp <site-name> plugin delete <plugin-slug>
```

**Example:**
```bash
local-wp my-site plugin delete my-plugin
# Output: Plugin 'my-plugin' deleted.
```

---

### Theme Management

#### List Themes

```bash
local-wp <site-name> theme list
```

**Options:**
- `--status=active` — List only active theme
- `--format=json` — JSON format

**Examples:**
```bash
# List all themes
local-wp my-site theme list

# List active theme
local-wp my-site theme list --status=active

# JSON output
local-wp my-site theme list --format=json
```

#### Get Theme Info

```bash
local-wp <site-name> theme get <theme-slug>
```

**Example:**
```bash
local-wp my-site theme get twentytwentyfour
# Output: Theme Name: Twenty Twenty-Four
#         Status: active
#         Version: 1.0
```

#### Activate Theme

```bash
local-wp <site-name> theme activate <theme-slug>
```

**Example:**
```bash
local-wp my-site theme activate my-theme
# Output: Theme 'my-theme' activated.
```

---

### Database Operations

#### Run SQL Query

```bash
local-wp <site-name> db query "<sql>"
```

**Example:**
```bash
local-wp my-site db query "SELECT * FROM wp_options LIMIT 5"
```

#### Export Database

```bash
local-wp <site-name> db export [filename]
```

**Example:**
```bash
local-wp my-site db export backup.sql
# Output: Database exported to backup.sql
```

#### Import Database

```bash
local-wp <site-name> db import <filename>
```

**Example:**
```bash
local-wp my-site db import backup.sql
# Output: Database imported from backup.sql
```

#### Search and Replace

```bash
local-wp <site-name> search-replace <old> <new> [options]
```

**Options:**
- `--dry-run` — Show what would be replaced without making changes
- `--all-tables` — Search all tables (default: wp_* tables)

**Examples:**
```bash
# Replace URL
local-wp my-site search-replace 'old-url.com' 'new-url.com'

# Dry run (preview changes)
local-wp my-site search-replace 'old-url.com' 'new-url.com' --dry-run

# Replace in all tables
local-wp my-site search-replace 'old-url.com' 'new-url.com' --all-tables
```

#### Optimize Database

```bash
local-wp <site-name> db optimize
```

**Example:**
```bash
local-wp my-site db optimize
# Output: Database optimized.
```

#### Check Database

```bash
local-wp <site-name> db check
```

**Example:**
```bash
local-wp my-site db check
# Output: Database check completed.
```

---

### Post/Page Management

#### List Posts

```bash
local-wp <site-name> post list [options]
```

**Options:**
- `--post_type=post` — Post type (default: post)
- `--post_status=publish` — Post status
- `--format=json` — JSON format
- `--number=10` — Number of posts to list

**Examples:**
```bash
# List all posts
local-wp my-site post list

# List published posts
local-wp my-site post list --post_status=publish

# List pages
local-wp my-site post list --post_type=page

# JSON output
local-wp my-site post list --format=json
```

#### Get Post Info

```bash
local-wp <site-name> post get <post-id>
```

**Example:**
```bash
local-wp my-site post get 1
# Output: ID: 1
#         Title: Hello World
#         Status: publish
```

#### Create Post

```bash
local-wp <site-name> post create [options]
```

**Options:**
- `--post_title=<title>` — Post title
- `--post_content=<content>` — Post content
- `--post_status=<status>` — Post status (default: draft)
- `--post_type=<type>` — Post type (default: post)

**Example:**
```bash
local-wp my-site post create \
  --post_title="My New Post" \
  --post_content="This is the content" \
  --post_status=publish
# Output: Success: Created post 42.
```

#### Update Post

```bash
local-wp <site-name> post update <post-id> [options]
```

**Example:**
```bash
local-wp my-site post update 42 --post_title="Updated Title"
# Output: Success: Updated post 42.
```

#### Delete Post

```bash
local-wp <site-name> post delete <post-id>
```

**Example:**
```bash
local-wp my-site post delete 42
# Output: Success: Trashed post 42.
```

---

### User Management

#### List Users

```bash
local-wp <site-name> user list [options]
```

**Options:**
- `--role=<role>` — Filter by role (admin, editor, author, contributor, subscriber)
- `--format=json` — JSON format

**Examples:**
```bash
# List all users
local-wp my-site user list

# List admin users
local-wp my-site user list --role=admin

# JSON output
local-wp my-site user list --format=json
```

#### Get User Info

```bash
local-wp <site-name> user get <user-id-or-login>
```

**Example:**
```bash
local-wp my-site user get admin
# Output: ID: 1
#         Login: admin
#         Email: admin@example.com
#         Role: administrator
```

#### Create User

```bash
local-wp <site-name> user create <login> <email> [options]
```

**Options:**
- `--role=<role>` — User role (default: subscriber)
- `--user_pass=<password>` — User password

**Example:**
```bash
local-wp my-site user create testuser test@example.com --role=editor
# Output: Success: Created user 42 (testuser).
```

#### Update User

```bash
local-wp <site-name> user update <user-id> [options]
```

**Example:**
```bash
local-wp my-site user update 42 --user_email=newemail@example.com
# Output: Success: Updated user 42.
```

#### Delete User

```bash
local-wp <site-name> user delete <user-id>
```

**Example:**
```bash
local-wp my-site user delete 42
# Output: Success: Deleted user 42.
```

---

### Option Management

#### Get Option

```bash
local-wp <site-name> option get <option-name>
```

**Example:**
```bash
local-wp my-site option get siteurl
# Output: http://my-site.local
```

#### Set Option

```bash
local-wp <site-name> option set <option-name> <value>
```

**Example:**
```bash
local-wp my-site option set blogname "My Site"
# Output: Success: Updated option 'blogname'.
```

#### Delete Option

```bash
local-wp <site-name> option delete <option-name>
```

**Example:**
```bash
local-wp my-site option delete my_custom_option
# Output: Success: Deleted option 'my_custom_option'.
```

---

## Environment Variables

Override auto-detection with environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `LOCAL_SITES_DIR` | `$HOME/Local Sites` | Local sites directory |
| `LOCAL_RUN_DIR` | `$HOME/Library/Application Support/Local/run` | Local run directory |
| `WP_CLI_PHAR` | Auto-detected | Path to wp-cli.phar |
| `PHP_BIN` | Auto-detected | Path to PHP binary |
| `LOCAL_WP_MEMORY_LIMIT` | `512M` | PHP memory_limit for WP-CLI |
| `LOCAL_WP_DEBUG` | `0` | Enable debug mode (1 = on) |

### Examples

```bash
# Override sites directory
export LOCAL_SITES_DIR="/custom/path/to/sites"
local-wp my-site core version

# Increase PHP memory limit
export LOCAL_WP_MEMORY_LIMIT="1024M"
local-wp my-site db export large-backup.sql

# Enable debug mode
export LOCAL_WP_DEBUG=1
local-wp my-site core version
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | WP-CLI error |
| `2` | Site not found |
| `3` | Configuration error |
| `4` | Permission denied |
| `127` | Command not found |

---

## Troubleshooting

### "Site not found"

**Solution:**
```bash
# List available sites
local-wp --list

# Check site name spelling
local-wp my-site core version
```

### "PHP not found"

**Solution:**
```bash
# Enable debug mode
export LOCAL_WP_DEBUG=1
local-wp my-site core version

# Override PHP path
export PHP_BIN="/path/to/php"
local-wp my-site core version
```

### "MySQL socket error"

**Solution:**
```bash
# Check Local is running
# Restart Local by Flywheel

# Override run directory
export LOCAL_RUN_DIR="/custom/path"
local-wp my-site core version
```

### "Permission denied"

**Solution:**
```bash
# Check file permissions
ls -la ~/bin/ai-ddtk/bin/local-wp

# Make executable
chmod +x ~/bin/ai-ddtk/bin/local-wp
```

---

## Examples

### Complete Site Setup

```bash
# 1. List available sites
local-wp --list

# 2. Get site info
local-wp my-site core version --extra

# 3. Create admin user
local-wp my-site user create admin admin@example.com --role=administrator

# 4. Install plugin
local-wp my-site plugin install woocommerce

# 5. Activate plugin
local-wp my-site plugin activate woocommerce

# 6. Export database
local-wp my-site db export backup.sql
```

### Database Migration

```bash
# 1. Export from source
local-wp source-site db export backup.sql

# 2. Import to destination
local-wp dest-site db import backup.sql

# 3. Search and replace URL
local-wp dest-site search-replace 'source-site.local' 'dest-site.local'

# 4. Verify
local-wp dest-site option get siteurl
```

### Plugin Testing

```bash
# 1. List plugins
local-wp my-site plugin list

# 2. Activate test plugin
local-wp my-site plugin activate my-test-plugin

# 3. Run tests
npm test

# 4. Deactivate plugin
local-wp my-site plugin deactivate my-test-plugin
```

---

## See Also

- [CLI-REFERENCE.md](./CLI-REFERENCE.md) — All AI-DDTK commands
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) — Common errors and solutions
- [AGENTS.md](../AGENTS.md) — AI agent guidelines

