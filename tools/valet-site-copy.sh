#!/usr/bin/env bash
# ============================================================
# AI-DDTK Valet Clone Helper (Optional, macOS)
# Creates disposable WordPress clones for Valet-based testing.
# ============================================================

set -euo pipefail

CLONE_ROOT_DEFAULT="${VALET_CLONE_ROOT:-$HOME/Valet-Sites}"
DB_HOST_DEFAULT="${VALET_DB_HOST:-127.0.0.1}"
DB_USER_DEFAULT="${VALET_DB_USER:-root}"
DB_PASS_DEFAULT="${VALET_DB_PASS:-}"

show_help() {
  cat <<'EOF'
AI-DDTK Valet Clone Helper (Optional)

Usage:
  tools/valet-site-copy.sh clone <source-site> <target-site> [options]
  tools/valet-site-copy.sh teardown <target-site> [options]
  tools/valet-site-copy.sh <source-site> <target-site> [options]

Commands:
  clone       Copy a seed site into a new disposable clone (default command)
  teardown    Drop the clone database and remove clone files

Options:
  --root <path>         Clone root directory (default: ~/Valet-Sites)
  --source-url <url>    Source URL for search-replace (default: http://<source>.test)
  --target-url <url>    Target URL for search-replace (default: http://<target>.test)
  --db-host <host>      MySQL host for db create/drop (default: 127.0.0.1)
  --db-user <user>      MySQL username (default: root)
  --db-pass <pass>      MySQL password (default: empty)
  --force               Overwrite existing target clone and database
  --yes                 Skip confirmation prompt for teardown
  --help, -h            Show this help

Examples:
  tools/valet-site-copy.sh clone clone-source clone-test-01
  tools/valet-site-copy.sh clone-source clone-test-01
  tools/valet-site-copy.sh teardown clone-test-01 --yes
EOF
}

log() {
  printf '[valet-site-copy] %s\n' "$*"
}

die() {
  printf '[valet-site-copy] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

sanitize_name_for_db() {
  local raw="$1"

  echo "$raw" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//; s/__+/_/g'
}

mysql_exec() {
  local sql="$1"

  if [ -n "$DB_PASS" ]; then
    mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "$sql"
  else
    mysql -h "$DB_HOST" -u "$DB_USER" -e "$sql"
  fi
}

clone_site() {
  local source_name="$1"
  local target_name="$2"

  local source_dir="$ROOT/$source_name"
  local target_dir="$ROOT/$target_name"
  local source_url="${SOURCE_URL:-http://$source_name.test}"
  local target_url="${TARGET_URL:-http://$target_name.test}"
  local db_suffix
  local db_name

  [ -d "$source_dir" ] || die "Source site directory not found: $source_dir"
  [ -f "$source_dir/wp-config.php" ] || die "Source does not look like a WP site (missing wp-config.php): $source_dir"

  db_suffix="$(sanitize_name_for_db "$target_name")"
  [ -n "$db_suffix" ] || die "Could not derive database name from target: $target_name"

  db_name="valet_${db_suffix}"
  db_name="${db_name:0:64}"

  if [ -e "$target_dir" ]; then
    if [ "$FORCE" = "1" ]; then
      log "Removing existing target directory: $target_dir"
      rm -rf "$target_dir"
    else
      die "Target directory already exists: $target_dir (use --force to overwrite)"
    fi
  fi

  mkdir -p "$target_dir"
  cp -a "$source_dir/." "$target_dir/"

  if [ "$FORCE" = "1" ]; then
    mysql_exec "DROP DATABASE IF EXISTS \`$db_name\`; CREATE DATABASE \`$db_name\`;"
  else
    mysql_exec "CREATE DATABASE \`$db_name\`;"
  fi

  wp --path="$target_dir" --dbhost="$DB_HOST" config set DB_NAME "$db_name" --type=constant >/dev/null
  wp --path="$target_dir" --dbhost="$DB_HOST" search-replace "$source_url" "$target_url" --all-tables --skip-columns=guid >/dev/null

  log "Clone created"
  log "  Source: $source_dir"
  log "  Target: $target_dir"
  log "  URL:    $target_url"
  log "  DB:     $db_name"
}

teardown_site() {
  local target_name="$1"
  local target_dir="$ROOT/$target_name"

  [ -d "$target_dir" ] || die "Target site directory not found: $target_dir"
  [ -f "$target_dir/wp-config.php" ] || die "Target does not look like a WP site (missing wp-config.php): $target_dir"

  if [ "$YES" != "1" ]; then
    printf 'Teardown %s (drop DB + delete files)? [y/N] ' "$target_name"
    read -r answer
    case "$answer" in
      y|Y|yes|YES) ;;
      *)
        log "Cancelled"
        exit 0
        ;;
    esac
  fi

  wp --path="$target_dir" --dbhost="$DB_HOST" db drop --yes >/dev/null
  rm -rf "$target_dir"

  log "Teardown complete: $target_name"
}

require_command wp
require_command mysql

COMMAND="clone"
ROOT="$CLONE_ROOT_DEFAULT"
SOURCE_URL=""
TARGET_URL=""
DB_HOST="$DB_HOST_DEFAULT"
DB_USER="$DB_USER_DEFAULT"
DB_PASS="$DB_PASS_DEFAULT"
FORCE="0"
YES="0"

if [ "$#" -eq 0 ]; then
  show_help
  exit 1
fi

case "$1" in
  clone|teardown)
    COMMAND="$1"
    shift
    ;;
  --help|-h)
    show_help
    exit 0
    ;;
esac

POSITIONAL=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT="${2:-}"
      shift 2
      ;;
    --source-url)
      SOURCE_URL="${2:-}"
      shift 2
      ;;
    --target-url)
      TARGET_URL="${2:-}"
      shift 2
      ;;
    --db-host)
      DB_HOST="${2:-}"
      shift 2
      ;;
    --db-user)
      DB_USER="${2:-}"
      shift 2
      ;;
    --db-pass)
      DB_PASS="${2:-}"
      shift 2
      ;;
    --force)
      FORCE="1"
      shift
      ;;
    --yes)
      YES="1"
      shift
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL[@]}"

if [ "$COMMAND" = "clone" ]; then
  [ "$#" -eq 2 ] || die "Clone requires: <source-site> <target-site>"
  clone_site "$1" "$2"
elif [ "$COMMAND" = "teardown" ]; then
  [ "$#" -eq 1 ] || die "Teardown requires: <target-site>"
  teardown_site "$1"
else
  die "Unknown command: $COMMAND"
fi