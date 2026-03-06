#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_WP="${LOCAL_WP:-$TOOLKIT_ROOT/local-wp}"
AIDDTK_TMUX="${AIDDTK_TMUX:-$TOOLKIT_ROOT/bin/aiddtk-tmux}"

SITE_NAME=""
PROJECT_ROOT="$(pwd)"
WP_PATH=""
SITE_ROOT=""
SITE_URL=""
RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR=""
DEBUG_LOG=""
PHP_LOG=""
NGINX_LOG=""
FALLBACK_TEMPLATE="twentytwentyone"
FALLBACK_STYLESHEET="twentytwentyone"
FALLBACK_NAME="Twenty Twenty-One"
TARGET_TEMPLATE=""
TARGET_STYLESHEET=""
TARGET_NAME=""
USE_TMUX=0
TMUX_SESSION=""
DRY_RUN=0
REVERTED=0

show_help() {
    cat <<'EOF'
AI-DDTK Experimental Theme Crash Loop

Runs a fallback -> target theme repro loop against a Local site, probes key URLs,
and stores artifacts under the target project's temp/theme-crash-loop/ folder.

Usage:
  experimental/theme-crash-loop.sh --site-name <local-site> --target-stylesheet <slug> [options]

Required:
  --site-name <name>            Local site name
  --target-stylesheet <slug>    Theme stylesheet to activate for the repro pass

Options:
  --project-root <path>         Target project root for temp output (default: current directory)
  --wp-path <path>              WordPress app/public path (default: ~/Local Sites/<site>/app/public)
  --site-url <url>              Override home URL lookup
  --target-template <slug>      Theme template slug (default: target stylesheet)
  --target-name <name>          current_theme label (default: target stylesheet)
  --fallback-template <slug>    Fallback template slug (default: twentytwentyone)
  --fallback-stylesheet <slug>  Fallback stylesheet slug (default: twentytwentyone)
  --fallback-name <name>        Fallback current_theme label
  --run-id <id>                 Override run id (default: timestamp)
  --run-dir <path>              Override output directory
  --debug-log <path>            Override wp-content/debug.log path
  --php-log <path>              Override Local PHP-FPM log path
  --nginx-log <path>            Override Local nginx error log path
  --tmux                        Launch the run inside aiddtk-tmux and exit
  --session <name>              Optional tmux session name
  --dry-run                     Print resolved configuration without making changes
  --help                        Show this help

Examples:
  experimental/theme-crash-loop.sh \
    --site-name my-local-site \
    --project-root "$(pwd)" \
    --target-stylesheet my-child-theme \
    --target-template astra \
    --tmux
EOF
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

resolve_path_for_mode() {
    local path="$1"
    local label="$2"

    if [ -d "$path" ]; then
        (
            cd "$path" && pwd
        )
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%s\n' "$path"
        return 0
    fi

    fail "$label does not exist: $path"
}

resolve_tool() {
    local configured_path="$1"
    local fallback_command="$2"

    if [ -x "$configured_path" ]; then
        printf '%s\n' "$configured_path"
        return 0
    fi

    if command -v "$fallback_command" >/dev/null 2>&1; then
        command -v "$fallback_command"
        return 0
    fi

    return 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --site-name) SITE_NAME="$2"; shift 2 ;;
        --project-root) PROJECT_ROOT="$2"; shift 2 ;;
        --wp-path) WP_PATH="$2"; shift 2 ;;
        --site-root) SITE_ROOT="$2"; shift 2 ;;
        --site-url) SITE_URL="$2"; shift 2 ;;
        --target-template) TARGET_TEMPLATE="$2"; shift 2 ;;
        --target-stylesheet) TARGET_STYLESHEET="$2"; shift 2 ;;
        --target-name) TARGET_NAME="$2"; shift 2 ;;
        --fallback-template) FALLBACK_TEMPLATE="$2"; shift 2 ;;
        --fallback-stylesheet) FALLBACK_STYLESHEET="$2"; shift 2 ;;
        --fallback-name) FALLBACK_NAME="$2"; shift 2 ;;
        --run-id) RUN_ID="$2"; shift 2 ;;
        --run-dir) RUN_DIR="$2"; shift 2 ;;
        --debug-log) DEBUG_LOG="$2"; shift 2 ;;
        --php-log) PHP_LOG="$2"; shift 2 ;;
        --nginx-log) NGINX_LOG="$2"; shift 2 ;;
        --tmux|--use-tmux) USE_TMUX=1; shift ;;
        --no-tmux) USE_TMUX=0; shift ;;
        --session) TMUX_SESSION="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done

[ -n "$SITE_NAME" ] || fail "--site-name is required"
[ -n "$TARGET_STYLESHEET" ] || fail "--target-stylesheet is required"

LOCAL_WP="$(resolve_tool "$LOCAL_WP" local-wp)" || fail "local-wp not found; expected $TOOLKIT_ROOT/local-wp or PATH"
if [ "$USE_TMUX" -eq 1 ]; then
    AIDDTK_TMUX="$(resolve_tool "$AIDDTK_TMUX" aiddtk-tmux)" || fail "aiddtk-tmux not found; expected $TOOLKIT_ROOT/bin/aiddtk-tmux or PATH"
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
WP_PATH="${WP_PATH:-$HOME/Local Sites/$SITE_NAME/app/public}"
WP_PATH="$(resolve_path_for_mode "$WP_PATH" 'WordPress path')"
SITE_ROOT="${SITE_ROOT:-$WP_PATH/../..}"
SITE_ROOT="$(resolve_path_for_mode "$SITE_ROOT" 'Local site root')"

if [ -z "$SITE_URL" ]; then
    if [ "$DRY_RUN" -eq 1 ] && [ ! -d "$WP_PATH" ]; then
        SITE_URL="https://$SITE_NAME.local"
    else
        SITE_URL="$($LOCAL_WP "$SITE_NAME" --path="$WP_PATH" --skip-themes --skip-plugins option get home 2>/dev/null | tail -n 1 || echo "https://$SITE_NAME.local")"
    fi
fi

SITE_URL="${SITE_URL%/}"
RUN_DIR="${RUN_DIR:-$PROJECT_ROOT/temp/theme-crash-loop/$RUN_ID}"
DEBUG_LOG="${DEBUG_LOG:-$WP_PATH/wp-content/debug.log}"
PHP_LOG="${PHP_LOG:-$SITE_ROOT/logs/php/php-fpm.log}"
NGINX_LOG="${NGINX_LOG:-$SITE_ROOT/logs/nginx/error.log}"
TARGET_TEMPLATE="${TARGET_TEMPLATE:-$TARGET_STYLESHEET}"
TARGET_NAME="${TARGET_NAME:-$TARGET_STYLESHEET}"
SUMMARY="$RUN_DIR/summary.txt"

launch_in_tmux() {
    local session_name="${TMUX_SESSION:-$(basename "$PROJECT_ROOT")-theme-crash-loop}"
    local command=(
        "$SCRIPT_DIR/theme-crash-loop.sh"
        --site-name "$SITE_NAME"
        --project-root "$PROJECT_ROOT"
        --wp-path "$WP_PATH"
        --site-url "$SITE_URL"
        --target-template "$TARGET_TEMPLATE"
        --target-stylesheet "$TARGET_STYLESHEET"
        --target-name "$TARGET_NAME"
        --fallback-template "$FALLBACK_TEMPLATE"
        --fallback-stylesheet "$FALLBACK_STYLESHEET"
        --fallback-name "$FALLBACK_NAME"
        --run-id "$RUN_ID"
        --run-dir "$RUN_DIR"
        --debug-log "$DEBUG_LOG"
        --php-log "$PHP_LOG"
        --nginx-log "$NGINX_LOG"
        --no-tmux
    )
    local command_text

    printf -v command_text '%q ' "${command[@]}"
    command_text="${command_text% }"

    "$AIDDTK_TMUX" start --session "$session_name" --cwd "$PROJECT_ROOT" >/dev/null
    "$AIDDTK_TMUX" send --session "$session_name" --command "$command_text" >/dev/null

    echo "Launched theme crash loop in tmux session: $session_name"
    echo "Project temp output: $RUN_DIR"
    echo "Capture with: $AIDDTK_TMUX capture --session $session_name --tail 200"
}

log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$SUMMARY"
}

wp_safe() {
    "$LOCAL_WP" "$SITE_NAME" --path="$WP_PATH" --skip-themes --skip-plugins "$@"
}

wp_value() {
    wp_safe "$@" | tail -n 1
}

line_count() {
    if [ -f "$1" ]; then
        wc -l < "$1" | tr -d ' '
    else
        echo 0
    fi
}

capture_delta() {
    local label="$1"
    local file_path="$2"
    local start_line="$3"
    local destination="$RUN_DIR/${label}.delta.log"

    if [ ! -f "$file_path" ]; then
        : > "$destination"
        return
    fi

    sed -n "$((start_line + 1)),\$p" "$file_path" > "$destination"
}

switch_theme() {
    local template="$1"
    local stylesheet="$2"
    local current_name="$3"

    log "Switching theme: template=$template stylesheet=$stylesheet current_theme=$current_name"
    wp_safe option update template "$template" >/dev/null
    wp_safe option update stylesheet "$stylesheet" >/dev/null
    wp_safe option update current_theme "$current_name" >/dev/null
}

report_theme_state() {
    log "Theme state: template=$(wp_value option get template) stylesheet=$(wp_value option get stylesheet) current_theme=$(wp_value option get current_theme)"
}

probe_url() {
    local url="$1"
    local slug
    local metrics

    slug="$(printf '%s' "$url" | sed 's#https\?://##; s#[^A-Za-z0-9._-]#_#g')"
    metrics="$(curl -k -L -sS --max-time 20 -D "$RUN_DIR/${slug}.headers.txt" -o "$RUN_DIR/${slug}.body.html" -w 'http_code=%{http_code} time_total=%{time_total} size_download=%{size_download}' "$url" || true)"
    log "Probe $url :: $metrics"
}

log_excerpt() {
    local label="$1"
    local file_path="$RUN_DIR/${label}.delta.log"

    log "Recent $label delta stored at $file_path"
    if [ -s "$file_path" ]; then
        tail -n 20 "$file_path" | sed "s/^/[${label}] /" | tee -a "$SUMMARY"
    else
        printf '[%s] %s\n' "$label" 'No new lines captured.' | tee -a "$SUMMARY"
    fi
}

ensure_theme_installed() {
    local slug="$1"
    [ -n "$slug" ] || return 0
    wp_safe theme is-installed "$slug" >/dev/null
}

cleanup() {
    local exit_code=$?

    if [ "$REVERTED" -eq 0 ]; then
        log "Cleanup triggered; reverting to fallback theme."
        switch_theme "$FALLBACK_TEMPLATE" "$FALLBACK_STYLESHEET" "$FALLBACK_NAME" || true
        report_theme_state || true
    fi

    log "Run complete with exit code $exit_code"
}

if [ "$USE_TMUX" -eq 1 ]; then
    launch_in_tmux
    exit 0
fi

mkdir -p "$RUN_DIR"

if [ "$DRY_RUN" -eq 1 ]; then
    {
        echo "SITE_NAME=$SITE_NAME"
        echo "PROJECT_ROOT=$PROJECT_ROOT"
        echo "WP_PATH=$WP_PATH"
        echo "SITE_URL=$SITE_URL"
        echo "RUN_DIR=$RUN_DIR"
        echo "LOCAL_WP=$LOCAL_WP"
        echo "TARGET_TEMPLATE=$TARGET_TEMPLATE"
        echo "TARGET_STYLESHEET=$TARGET_STYLESHEET"
        echo "FALLBACK_TEMPLATE=$FALLBACK_TEMPLATE"
        echo "FALLBACK_STYLESHEET=$FALLBACK_STYLESHEET"
    } | tee "$SUMMARY"
    exit 0
fi

trap cleanup EXIT

log "Run directory: $RUN_DIR"
log "Using LOCAL_WP=$LOCAL_WP"
log "Using SITE_NAME=$SITE_NAME WP_PATH=$WP_PATH SITE_URL=$SITE_URL"

ensure_theme_installed "$FALLBACK_TEMPLATE"
ensure_theme_installed "$FALLBACK_STYLESHEET"
ensure_theme_installed "$TARGET_TEMPLATE"
ensure_theme_installed "$TARGET_STYLESHEET"

DEBUG_START="$(line_count "$DEBUG_LOG")"
PHP_START="$(line_count "$PHP_LOG")"
NGINX_START="$(line_count "$NGINX_LOG")"

log "Initial log markers: debug=$DEBUG_START php=$PHP_START nginx=$NGINX_START"
report_theme_state

switch_theme "$FALLBACK_TEMPLATE" "$FALLBACK_STYLESHEET" "$FALLBACK_NAME"
report_theme_state
probe_url "$SITE_URL/?crash-loop=fallback"

switch_theme "$TARGET_TEMPLATE" "$TARGET_STYLESHEET" "$TARGET_NAME"
report_theme_state
probe_url "$SITE_URL/?crash-loop=target-home"
probe_url "$SITE_URL/wp-admin/?crash-loop=target-admin"
probe_url "$SITE_URL/wp-cron.php?doing_wp_cron=1&crash-loop=target-cron"

log "Reverting to fallback theme after target probes."
switch_theme "$FALLBACK_TEMPLATE" "$FALLBACK_STYLESHEET" "$FALLBACK_NAME"
REVERTED=1
report_theme_state
probe_url "$SITE_URL/?crash-loop=recovery"

capture_delta debug "$DEBUG_LOG" "$DEBUG_START"
capture_delta php "$PHP_LOG" "$PHP_START"
capture_delta nginx "$NGINX_LOG" "$NGINX_START"

log_excerpt debug
log_excerpt php
log_excerpt nginx