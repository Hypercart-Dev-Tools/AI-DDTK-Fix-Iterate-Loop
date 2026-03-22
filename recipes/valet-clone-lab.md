# Valet Clone Lab (Optional, macOS)

Use this workflow when you need very fast throwaway WordPress clones for testing copy detection, migration behavior, or plugin regressions.

This is an optional path. It is not part of the default AI-DDTK setup and does not replace Local WP.

## Scope

- Primary environment stays Local WP.
- Valet is a disposable clone lab for rapid spin up and teardown.
- Local development only. Do not use production data unless it is sanitized.

## Support Level

- Status: Experimental optional workflow.
- Audience: Users on macOS who already use Homebrew and want fast clone iteration.
- Non-goal: Cross-platform parity.

## Prerequisites

- macOS
- Homebrew
- Composer
- Laravel Valet
- MySQL (Homebrew service)
- WP-CLI

## Quick Verification

Run these checks before cloning:

```bash
command -v valet wp mysql composer
valet loopback
if command -v rg >/dev/null 2>&1; then
  brew services list | rg mysql
else
  brew services list | grep mysql
fi
```

Expected:
- commands resolve on PATH
- loopback prints 127.0.0.2
- mysql service is started

## Setup (One Time)

```bash
# 1) Install dependencies
brew install mysql wp-cli composer
brew services start mysql

# 2) Install Valet
composer global require laravel/valet
export PATH="$(composer global config bin-dir --absolute):$PATH"
valet install
valet trust

# 3) Keep Valet isolated from Local WP routing
valet loopback 127.0.0.2

# 4) Park clone workspace
mkdir -p "$HOME/Valet-Sites"
cd "$HOME/Valet-Sites"
valet park
```

## Seed Site Pattern

Create one clean seed site, then clone from it repeatedly.

```bash
mkdir -p "$HOME/Valet-Sites/clone-source"
cd "$HOME/Valet-Sites/clone-source"

wp core download
mysql -u root -e "CREATE DATABASE valet_clone_source"
wp config create --dbname=valet_clone_source --dbuser=root --dbpass="" --dbhost=127.0.0.1
wp core install \
  --url=http://clone-source.test \
  --title="Clone Source" \
  --admin_user=admin \
  --admin_pass="$(openssl rand -base64 32)" \
  --admin_email=dev@test.local
```

If you use AI-DDTK browser auth flows, copy the dev-login mu-plugin into the seed site:

```bash
mkdir -p "$HOME/Valet-Sites/clone-source/wp-content/mu-plugins"
cp "$HOME/bin/ai-ddtk/templates/dev-login-cli.php" \
  "$HOME/Valet-Sites/clone-source/wp-content/mu-plugins/dev-login-cli.php"
```

## Clone and Teardown

If your repo includes a Valet clone helper script, use it as the canonical entry point.

```bash
# Example clone (script name may vary by repo)
./tools/valet-site-copy.sh clone-source clone-test-01

# Teardown
cd "$HOME/Valet-Sites/clone-test-01" && wp db drop --yes && rm -rf "$HOME/Valet-Sites/clone-test-01"
```

If no helper script is present, clone manually by copying files, creating a new database with a `valet_` prefix, and running a search/replace for the target URL.

```bash
mkdir -p "$HOME/Valet-Sites/clone-test-01"
cp -a "$HOME/Valet-Sites/clone-source/." "$HOME/Valet-Sites/clone-test-01/"
mysql -u root -e "CREATE DATABASE valet_clone_test_01"
cd "$HOME/Valet-Sites/clone-test-01"
wp config set DB_NAME valet_clone_test_01 --type=constant
wp search-replace 'http://clone-source.test' 'http://clone-test-01.test' --all-tables --skip-columns=guid
```

If the cloned site uses absolute filesystem paths or custom domain mappings, update those too before running tests.

## Guardrails

- Keep all test credentials and artifacts in temp.
- Prefix Valet databases with valet_.
- Always pass --dbhost=127.0.0.1 for Valet WP-CLI operations.
- Do not modify Local WP site files during Valet clone-lab runs.
- Treat this as disposable infrastructure; reset often.

## Coexistence Notes

- Local WP and Valet can run at the same time when Valet loopback is set to 127.0.0.2.
- If .test routing behaves unexpectedly, re-run valet loopback 127.0.0.2 and verify again.

## AI Agent Usage Hint

When an agent is working in this mode, include this in the prompt:

- Target environment is Valet clone lab, not Local WP.
- Clone root is ~/Valet-Sites.
- Use disposable test sites and cleanup after verification.
- Prefer recipe steps over ad hoc shell changes.
