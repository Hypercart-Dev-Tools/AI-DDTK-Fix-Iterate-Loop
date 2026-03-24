#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_WP="${LOCAL_WP:-$TOOLKIT_ROOT/bin/local-wp}"
AIDDTK_TMUX="${AIDDTK_TMUX:-$TOOLKIT_ROOT/bin/aiddtk-tmux}"
CURL_BIN="${CURL_BIN:-curl}"

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
PROBE_TIMEOUT=20
PROBE_TOTAL=0
PROBE_ERROR_COUNT=0
PROBE_WARNING_COUNT=0
LOG_ALERT_COUNT=0
RUN_STATUS="ok"
PROBE_RESULTS_JSONL=""
PROBE_RESULTS_TSV=""
RUN_REPORT_JSON=""
CUSTOM_PROBE_COUNT=0
CUSTOM_PROBE_PREFIX="custom"
CUSTOM_PROBE_URLS=()

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
  --probe-url <url-or-path>     Extra URL or path to probe after target activation (repeatable)
  --probe-timeout <seconds>     curl timeout per probe (default: 20)
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
        --probe-url) CUSTOM_PROBE_URLS+=("$2"); shift 2 ;;
        --probe-timeout) PROBE_TIMEOUT="$2"; shift 2 ;;
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
case "$PROBE_TIMEOUT" in
    ''|*[!0-9]*) fail "--probe-timeout must be an integer number of seconds" ;;
esac

LOCAL_WP="$(resolve_tool "$LOCAL_WP" local-wp)" || fail "local-wp not found; expected $TOOLKIT_ROOT/bin/local-wp or PATH"
CURL_BIN="$(resolve_tool "$CURL_BIN" curl)" || fail "curl not found; install curl or set CURL_BIN"
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
        SITE_URL="$(timeout 10 $LOCAL_WP "$SITE_NAME" --path="$WP_PATH" --skip-themes --skip-plugins option get home 2>/dev/null | tail -n 1 || echo "https://$SITE_NAME.local")"
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
PROBE_RESULTS_JSONL="$RUN_DIR/probes.jsonl"
PROBE_RESULTS_TSV="$RUN_DIR/probes.tsv"
RUN_REPORT_JSON="$RUN_DIR/run.json"

json_escape() {
    printf '%s' "$1" | sed \
        -e 's/\\/\\\\/g' \
        -e 's/"/\\"/g' \
        -e 's/\r/\\r/g' \
        -e 's/\t/\\t/g' \
        -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g'
}

slugify_value() {
    printf '%s' "$1" | sed 's#https\?://##; s#[^A-Za-z0-9._-]#_#g'
}

normalize_probe_url() {
    local input="$1"

    case "$input" in
        http://*|https://*) printf '%s\n' "$input" ;;
        /*) printf '%s%s\n' "$SITE_URL" "$input" ;;
        *) printf '%s/%s\n' "$SITE_URL" "${input#./}" ;;
    esac
}

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
        --probe-timeout "$PROBE_TIMEOUT"
        --no-tmux
    )
    local command_text
    local probe_url=""

    for probe_url in "${CUSTOM_PROBE_URLS[@]}"; do
        command+=(--probe-url "$probe_url")
    done

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

initialize_artifacts() {
    printf 'label\tclassification\thttp_code\ttime_total\tsize_download\tnum_redirects\tcurl_exit_code\turl\teffective_url\tsignals\n' > "$PROBE_RESULTS_TSV"
    : > "$PROBE_RESULTS_JSONL"
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
    local label="${1:-state}"
    local template
    local stylesheet
    local current_theme
    local state_line
    local state_file="$RUN_DIR/theme-state-${label}.txt"

    template="$(wp_value option get template)"
    stylesheet="$(wp_value option get stylesheet)"
    current_theme="$(wp_value option get current_theme)"
    state_line="template=$template stylesheet=$stylesheet current_theme=$current_theme"

    log "Theme state ($label): $state_line"
    printf '%s\n' "$state_line" > "$state_file"
}

parse_metric() {
    local key="$1"
    local metrics_file="$2"

    sed -n "s/^${key}=//p" "$metrics_file" | tail -n 1
}

record_probe_result() {
    local label="$1"
    local url="$2"
    local effective_url="$3"
    local http_code="$4"
    local time_total="$5"
    local size_download="$6"
    local num_redirects="$7"
    local content_type="$8"
    local classification="$9"
    local curl_exit_code="${10}"
    local signals_csv="${11}"
    local signal_json="${12}"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$label" \
        "$classification" \
        "$http_code" \
        "$time_total" \
        "$size_download" \
        "$num_redirects" \
        "$curl_exit_code" \
        "$url" \
        "$effective_url" \
        "$signals_csv" >> "$PROBE_RESULTS_TSV"

    printf '{\n  "label": "%s",\n  "url": "%s",\n  "effectiveUrl": "%s",\n  "httpCode": "%s",\n  "timeTotal": "%s",\n  "sizeDownload": "%s",\n  "numRedirects": "%s",\n  "contentType": "%s",\n  "classification": "%s",\n  "curlExitCode": %s,\n  "signals": %s\n}\n' \
        "$(json_escape "$label")" \
        "$(json_escape "$url")" \
        "$(json_escape "$effective_url")" \
        "$(json_escape "$http_code")" \
        "$(json_escape "$time_total")" \
        "$(json_escape "$size_download")" \
        "$(json_escape "$num_redirects")" \
        "$(json_escape "$content_type")" \
        "$(json_escape "$classification")" \
        "$curl_exit_code" \
        "$signal_json" >> "$PROBE_RESULTS_JSONL"
}

probe_url() {
    local label="$1"
    local url="$2"
    local slug
    local headers_file
    local body_file
    local metrics_file
    local meta_file
    local curl_exit_code=0
    
    # Future: Optional QM profiling integration.
    # When --with-qm-profile is added, capture Query Monitor data for this probe via the MCP
    # qm_profile_page tool (tools/mcp-server/src/handlers/qm-bridge.ts). Store profiles under
    # temp/qm-profiles/ and correlate with HTTP metrics + log signals to detect resource-exhaustion
    # crashes vs. pure logic errors. See Phase 7 in P1-MCP-SERVER.md and the QM bridge mu-plugin.
    local http_code=""
    local time_total=""
    local size_download=""
    local num_redirects=""
    local effective_url=""
    local content_type=""
    local classification="ok"
    local severity="ok"
    local signals_csv=""
    local signal_json=""
    local signal_sep=""
    local -a signals=()
    local signal=""

    slug="$(slugify_value "$label-$url")"
    headers_file="$RUN_DIR/${slug}.headers.txt"
    body_file="$RUN_DIR/${slug}.body.html"
    metrics_file="$RUN_DIR/${slug}.metrics.txt"
    meta_file="$RUN_DIR/${slug}.meta.txt"

    if ! "$CURL_BIN" -k -L -sS --max-time "$PROBE_TIMEOUT" \
        -D "$headers_file" \
        -o "$body_file" \
        -w $'http_code=%{http_code}\ntime_total=%{time_total}\nsize_download=%{size_download}\nnum_redirects=%{num_redirects}\nurl_effective=%{url_effective}\ncontent_type=%{content_type}\n' \
        "$url" > "$metrics_file"; then
        curl_exit_code=$?
    fi

    # Guard against missing files when curl times out before writing output
    if [ ! -f "$metrics_file" ]; then
        curl_exit_code="${curl_exit_code:-28}"
        http_code="" ; time_total="" ; size_download="" ; num_redirects="" ; effective_url="" ; content_type=""
    else
        http_code="$(parse_metric http_code "$metrics_file")"
        time_total="$(parse_metric time_total "$metrics_file")"
        size_download="$(parse_metric size_download "$metrics_file")"
        num_redirects="$(parse_metric num_redirects "$metrics_file")"
        effective_url="$(parse_metric url_effective "$metrics_file")"
        content_type="$(parse_metric content_type "$metrics_file")"
    fi

    if [ -n "$num_redirects" ] && [ "$num_redirects" != "0" ]; then
        signals+=("redirected")
    fi
    if [ "$curl_exit_code" -ne 0 ]; then
        signals+=("curl_error")
        classification="curl_error"
        severity="error"
    fi
    if [ "${http_code:-0}" -ge 500 ] 2>/dev/null; then
        signals+=("http_${http_code}")
        classification="server_error"
        severity="error"
    elif [ "${http_code:-0}" -ge 400 ] 2>/dev/null; then
        signals+=("http_${http_code}")
        if [ "$severity" = "ok" ]; then
            classification="client_error"
            severity="warning"
        fi
    fi
    if [ -f "$body_file" ] && grep -Eiq 'wp-login\.php|<body[^>]*class="[^"]*login|id="loginform"|name="log"' "$body_file"; then
        signals+=("login_gate")
        if [ "$severity" = "ok" ]; then
            classification="login_gate"
            severity="warning"
        fi
    fi
    if printf '%s' "$effective_url" | grep -Eq '/wp-login\.php'; then
        signals+=("effective_url_login")
        if [ "$severity" = "ok" ]; then
            classification="login_gate"
            severity="warning"
        fi
    fi
    if [ -f "$body_file" ] && grep -Eiq 'There has been a critical error on this website|Fatal error:|Parse error:|Uncaught [A-Za-z_\\]+|Allowed memory size of .* exhausted' "$body_file"; then
        signals+=("fatal_error_page")
        classification="fatal_error"
        severity="error"
    fi
    if [ -f "$body_file" ] && grep -Eiq 'Error establishing a database connection' "$body_file"; then
        signals+=("db_error_page")
        classification="db_error"
        severity="error"
    fi
    if [ -f "$body_file" ] && grep -Eiq '<title>WordPress (›|&rsaquo;) Error|wp-die-message|class="wp-die-message"' "$body_file"; then
        signals+=("wp_die_page")
        if [ "$severity" != "error" ]; then
            classification="wp_die_error"
            severity="error"
        fi
    fi
    if [ "${#signals[@]}" -eq 0 ]; then
        signals+=("none")
    fi

    for signal in "${signals[@]}"; do
        if [ -n "$signals_csv" ]; then
            signals_csv="${signals_csv},"
        fi
        signals_csv="${signals_csv}${signal}"
        signal_json="${signal_json}${signal_sep}\"$(json_escape "$signal")\""
        signal_sep=", "
    done
    signal_json="[${signal_json}]"

    # Future: Include QM profile correlation signals (e.g., "high_query_count", "memory_spike",
    # "slow_callback") if --with-qm-profile is enabled. These signals would be appended to the
    # signals array and used to classify crashes with richer context than HTTP status alone.

    PROBE_TOTAL=$((PROBE_TOTAL + 1))
    if [ "$severity" = "error" ]; then
        PROBE_ERROR_COUNT=$((PROBE_ERROR_COUNT + 1))
    elif [ "$severity" = "warning" ]; then
        PROBE_WARNING_COUNT=$((PROBE_WARNING_COUNT + 1))
    fi

    {
        echo "label=$label"
        echo "url=$url"
        echo "effective_url=$effective_url"
        echo "http_code=$http_code"
        echo "time_total=$time_total"
        echo "size_download=$size_download"
        echo "num_redirects=$num_redirects"
        echo "content_type=$content_type"
        echo "curl_exit_code=$curl_exit_code"
        echo "classification=$classification"
        echo "signals=$signals_csv"
    } > "$meta_file"

    record_probe_result \
        "$label" \
        "$url" \
        "$effective_url" \
        "$http_code" \
        "$time_total" \
        "$size_download" \
        "$num_redirects" \
        "$content_type" \
        "$classification" \
        "$curl_exit_code" \
        "$signals_csv" \
        "$signal_json"

    log "Probe $label :: classification=$classification http_code=${http_code:-n/a} time_total=${time_total:-n/a} signals=$signals_csv"
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

scan_log_delta() {
    local label="$1"
    local file_path="$RUN_DIR/${label}.delta.log"
    local alerts_file="$RUN_DIR/${label}.alerts.log"
    local count="0"

    if [ ! -s "$file_path" ]; then
        : > "$alerts_file"
        return 0
    fi

    grep -Ein 'fatal error|parse error|uncaught .*error|allowed memory size|critical error|error establishing a database connection|segmentation fault|segfault|core dumped' "$file_path" > "$alerts_file" || true
    if [ -s "$alerts_file" ]; then
        count="$(wc -l < "$alerts_file" | tr -d ' ')"
        LOG_ALERT_COUNT=$((LOG_ALERT_COUNT + count))
    fi

    log "Log scan $label :: alert_lines=$count"
}

write_run_report() {
    local custom_probe_json=""
    local custom_probe_sep=""
    local probe_url=""
    
    # Future: If --with-qm-profile was used, include an "qmProfiles" array in the JSON output
    # referencing the stored profiles from temp/qm-profiles/. Also add an "enrichedSignals" summary
    # (e.g., query_count_avg, memory_delta_mb, slowest_callback_ms) to help maintainers decide
    # whether a crash was triggered by resource limits or faulty theme code.

    if [ "$PROBE_ERROR_COUNT" -gt 0 ] || [ "$LOG_ALERT_COUNT" -gt 0 ]; then
        RUN_STATUS="failed"
    elif [ "$PROBE_WARNING_COUNT" -gt 0 ]; then
        RUN_STATUS="warning"
    else
        RUN_STATUS="ok"
    fi

    for probe_url in "${CUSTOM_PROBE_URLS[@]}"; do
        custom_probe_json="${custom_probe_json}${custom_probe_sep}\"$(json_escape "$(normalize_probe_url "$probe_url")")\""
        custom_probe_sep=", "
    done

    printf '{\n  "runId": "%s",\n  "status": "%s",\n  "siteName": "%s",\n  "siteUrl": "%s",\n  "projectRoot": "%s",\n  "wpPath": "%s",\n  "runDir": "%s",\n  "fallbackTheme": {\n    "template": "%s",\n    "stylesheet": "%s",\n    "name": "%s"\n  },\n  "targetTheme": {\n    "template": "%s",\n    "stylesheet": "%s",\n    "name": "%s"\n  },\n  "probeTimeoutSeconds": %s,\n  "probeTotals": {\n    "total": %s,\n    "errors": %s,\n    "warnings": %s\n  },\n  "logAlertCount": %s,\n  "customProbeUrls": [%s],\n  "artifacts": {\n    "summary": "%s",\n    "probesJsonl": "%s",\n    "probesTsv": "%s"\n  }\n}\n' \
        "$(json_escape "$RUN_ID")" \
        "$(json_escape "$RUN_STATUS")" \
        "$(json_escape "$SITE_NAME")" \
        "$(json_escape "$SITE_URL")" \
        "$(json_escape "$PROJECT_ROOT")" \
        "$(json_escape "$WP_PATH")" \
        "$(json_escape "$RUN_DIR")" \
        "$(json_escape "$FALLBACK_TEMPLATE")" \
        "$(json_escape "$FALLBACK_STYLESHEET")" \
        "$(json_escape "$FALLBACK_NAME")" \
        "$(json_escape "$TARGET_TEMPLATE")" \
        "$(json_escape "$TARGET_STYLESHEET")" \
        "$(json_escape "$TARGET_NAME")" \
        "$PROBE_TIMEOUT" \
        "$PROBE_TOTAL" \
        "$PROBE_ERROR_COUNT" \
        "$PROBE_WARNING_COUNT" \
        "$LOG_ALERT_COUNT" \
        "$custom_probe_json" \
        "$(json_escape "$SUMMARY")" \
        "$(json_escape "$PROBE_RESULTS_JSONL")" \
        "$(json_escape "$PROBE_RESULTS_TSV")" > "$RUN_REPORT_JSON"

    log "Run status: $RUN_STATUS (probe_errors=$PROBE_ERROR_COUNT probe_warnings=$PROBE_WARNING_COUNT log_alerts=$LOG_ALERT_COUNT)"
    log "Machine-readable report: $RUN_REPORT_JSON"
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
        echo "CURL_BIN=$CURL_BIN"
        echo "PROBE_TIMEOUT=$PROBE_TIMEOUT"
        echo "TARGET_TEMPLATE=$TARGET_TEMPLATE"
        echo "TARGET_STYLESHEET=$TARGET_STYLESHEET"
        echo "FALLBACK_TEMPLATE=$FALLBACK_TEMPLATE"
        echo "FALLBACK_STYLESHEET=$FALLBACK_STYLESHEET"
        echo "CUSTOM_PROBE_URLS=${CUSTOM_PROBE_URLS[*]:-}"
    } | tee "$SUMMARY"
    exit 0
fi

trap cleanup EXIT
initialize_artifacts

log "Run directory: $RUN_DIR"
log "Using LOCAL_WP=$LOCAL_WP"
log "Using CURL_BIN=$CURL_BIN PROBE_TIMEOUT=${PROBE_TIMEOUT}s"
log "Using SITE_NAME=$SITE_NAME WP_PATH=$WP_PATH SITE_URL=$SITE_URL"

ensure_theme_installed "$FALLBACK_TEMPLATE"
ensure_theme_installed "$FALLBACK_STYLESHEET"
ensure_theme_installed "$TARGET_TEMPLATE"
ensure_theme_installed "$TARGET_STYLESHEET"

DEBUG_START="$(line_count "$DEBUG_LOG")"
PHP_START="$(line_count "$PHP_LOG")"
NGINX_START="$(line_count "$NGINX_LOG")"

log "Initial log markers: debug=$DEBUG_START php=$PHP_START nginx=$NGINX_START"
report_theme_state initial

switch_theme "$FALLBACK_TEMPLATE" "$FALLBACK_STYLESHEET" "$FALLBACK_NAME"
report_theme_state fallback
probe_url "fallback-home" "$SITE_URL/?crash-loop=fallback"

switch_theme "$TARGET_TEMPLATE" "$TARGET_STYLESHEET" "$TARGET_NAME"
report_theme_state target
probe_url "target-home" "$SITE_URL/?crash-loop=target-home"
probe_url "target-admin" "$SITE_URL/wp-admin/?crash-loop=target-admin"
probe_url "target-cron" "$SITE_URL/wp-cron.php?doing_wp_cron=1&crash-loop=target-cron"

for probe_url in "${CUSTOM_PROBE_URLS[@]}"; do
    CUSTOM_PROBE_COUNT=$((CUSTOM_PROBE_COUNT + 1))
    probe_url "${CUSTOM_PROBE_PREFIX}-${CUSTOM_PROBE_COUNT}" "$(normalize_probe_url "$probe_url")"
done

log "Reverting to fallback theme after target probes."
switch_theme "$FALLBACK_TEMPLATE" "$FALLBACK_STYLESHEET" "$FALLBACK_NAME"
REVERTED=1
report_theme_state recovery
probe_url "recovery-home" "$SITE_URL/?crash-loop=recovery"

capture_delta debug "$DEBUG_LOG" "$DEBUG_START"
capture_delta php "$PHP_LOG" "$PHP_START"
capture_delta nginx "$NGINX_LOG" "$NGINX_START"
scan_log_delta debug
scan_log_delta php
scan_log_delta nginx

log_excerpt debug
log_excerpt php
log_excerpt nginx
write_run_report
