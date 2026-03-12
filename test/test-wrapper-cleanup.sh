#!/usr/bin/env bash
# ============================================================
# AI-DDTK Wrapper Cleanup Regression Tests
# ============================================================
#
# PURPOSE:
#   Validates request-host checks, exact-match lookup behavior,
#   and temp-file cleanup for toolkit helpers and shell wrappers.
#
# FOR LLM AGENTS:
#   - Keep this harness self-contained and dependency-light
#   - Prefer stubs and temp directories over real Local/Playwright state
#   - Each test function should return 0 (pass) or 1 (fail)
#
# ============================================================

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASSED=0
FAILED=0
START_SOCKET_SERVER_PID=""

run_test() {
    local test_name="$1"
    local test_func="$2"
    local log_file=""

    echo -e "${BLUE}Testing:${NC} $test_name"

    log_file="$(mktemp "${TMPDIR:-/tmp}/aiddtk-wrapper-log-XXXXXX")" || return 1

    if "$test_func" >"$log_file" 2>&1; then
        echo -e "  ${GREEN}✓ PASSED${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗ FAILED${NC}"
        if [ -s "$log_file" ]; then
            cat "$log_file"
        fi
        FAILED=$((FAILED + 1))
    fi

    rm -f "$log_file"
}

make_temp_dir() {
    # Prefer /tmp to keep UNIX socket paths short enough for macOS.
    local temp_root="/tmp"

    if [ ! -d "$temp_root" ] || [ ! -w "$temp_root" ]; then
        temp_root="${TMPDIR:-/tmp}"
    fi

    mktemp -d "$temp_root/aiddtk-wrapper-test-XXXXXX"
}

start_socket_server() {
    local socket_path="$1"
    local pid=""
    local attempt=""

    START_SOCKET_SERVER_PID=""

    python3 - "$socket_path" <<'PY' >/dev/null 2>&1 &
import socket
import sys
import time

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.bind(sys.argv[1])
sock.listen(1)
time.sleep(30)
PY
    pid=$!

    for attempt in 1 2 3 4 5; do
        if [ -S "$socket_path" ]; then
            START_SOCKET_SERVER_PID="$pid"
            return 0
        fi
        sleep 0.2
    done

    kill "$pid" 2>/dev/null || true
    return 1
}

cleanup_test_root() {
    local test_root="$1"
    shift
    local pid=""

    for pid in "$@"; do
        [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
    done

    rm -rf "$test_root"
}

test_dev_login_request_host_validation() {
    local test_root=""
    local php_test=""
    local status=""

    if ! command -v php >/dev/null 2>&1; then
        echo "Skipping dev-login request-host test: php not available"
        return 0
    fi

    test_root="$(make_temp_dir)" || return 1
    php_test="$test_root/dev-login-host-test.php"

    cat > "$php_test" <<EOF
<?php
define( 'ABSPATH', __DIR__ );


\$GLOBALS['home_url_value'] = 'https://allowed.local/';

function apply_filters( \$tag, \$value ) {
    return \$value;
}

function wp_parse_url( \$url, \$component = -1 ) {
    return parse_url( \$url, \$component );
}

function home_url( \$path = '/' ) {
    return rtrim( \$GLOBALS['home_url_value'], '/' ) . \$path;
}

function wp_unslash( \$value ) {
    return \$value;
}

function add_action( \$tag, \$callback ) {
}

function assert_true( \$condition, \$message ) {
    if ( ! \$condition ) {
        fwrite( STDERR, \$message . PHP_EOL );
        exit( 1 );
    }
}

function assert_same( \$expected, \$actual, \$message ) {
    if ( \$expected !== \$actual ) {
        fwrite( STDERR, \$message . ' expected=' . var_export( \$expected, true ) . ' actual=' . var_export( \$actual, true ) . PHP_EOL );
        exit( 1 );
    }
}

require '$TOOLKIT_DIR/templates/dev-login-cli.php';

assert_true( _dev_login_host_allowed(), 'Expected configured site host to remain allowlisted.' );

\$_SERVER['HTTP_HOST'] = 'Tunnel.Example.com:8443';
assert_same( 'tunnel.example.com', _dev_login_get_request_host(), 'Expected request host normalization to strip port and lowercase.' );
assert_true( ! _dev_login_host_allowed( _dev_login_get_request_host() ), 'Expected non-allowlisted request host to be rejected.' );

\$_SERVER['HTTP_HOST'] = 'LOCALHOST:8080';
assert_same( 'localhost', _dev_login_get_request_host(), 'Expected localhost request host normalization.' );
assert_true( _dev_login_host_allowed( _dev_login_get_request_host() ), 'Expected localhost request host to be allowlisted.' );

\$_SERVER['HTTP_HOST'] = '[::1]:8443';
assert_same( '::1', _dev_login_get_request_host(), 'Expected IPv6 request host normalization.' );
assert_true( _dev_login_host_allowed( _dev_login_get_request_host() ), 'Expected IPv6 localhost request host to be allowlisted.' );

\$_SERVER['HTTP_HOST'] = 'Example.TEST:9443';
assert_same( 'example.test', _dev_login_get_request_host(), 'Expected .test request host normalization.' );
assert_true( _dev_login_host_allowed( _dev_login_get_request_host() ), 'Expected .test request host to be allowlisted.' );
EOF

    php "$php_test"
    status=$?

    cleanup_test_root "$test_root"
    return "$status"
}

test_local_wp_exact_match_lookup_and_cleanup() {
    local test_root=""
    local local_sites_dir=""
    local local_run_dir=""
    local tmp_dir=""
    local site_name="site"
    local wrong_name="site-old"
    local wrong_id="a-match"
    local right_id="z-correct"
    local wrong_socket=""
    local right_socket=""
    local wrong_pid=""
    local right_pid=""
    local wp_cli_phar=""
    local fake_php=""
    local fake_php_marker=""
    local fake_php_ini_marker=""
    local ini_file=""
    local local_wp_log=""
    local status=""

    test_root="$(make_temp_dir)" || return 1
    local_sites_dir="$test_root/local-sites"
    local_run_dir="$test_root/run"
    tmp_dir="$test_root/tmp"
    wrong_socket="$local_run_dir/$wrong_id/mysql/mysqld.sock"
    right_socket="$local_run_dir/$right_id/mysql/mysqld.sock"
    wp_cli_phar="$test_root/wp-cli.phar"
    fake_php="$test_root/fake-php.sh"
    fake_php_marker="$test_root/fake-php.marker"
    fake_php_ini_marker="$test_root/fake-php.ini"
    local_wp_log="$test_root/local-wp.log"

    mkdir -p "$local_sites_dir/$site_name/app/public" \
             "$tmp_dir" \
             "$local_run_dir/$wrong_id/conf" "$local_run_dir/$wrong_id/mysql" \
             "$local_run_dir/$right_id/conf" "$local_run_dir/$right_id/mysql"
    touch "$local_sites_dir/$site_name/app/public/wp-config.php" "$wp_cli_phar"
    printf '%s\n' "$wrong_name" > "$local_run_dir/$wrong_id/conf/site.conf"
    printf '%s\n' "$site_name" > "$local_run_dir/$right_id/conf/site.conf"

    start_socket_server "$right_socket" || {
        cleanup_test_root "$test_root"
        echo "Failed to create expected socket at $right_socket"
        return 1
    }
    right_pid="$START_SOCKET_SERVER_PID"

    start_socket_server "$wrong_socket" || {
        cleanup_test_root "$test_root" "$right_pid"
        echo "Failed to create control socket at $wrong_socket"
        return 1
    }
    wrong_pid="$START_SOCKET_SERVER_PID"

    cat > "$fake_php" <<EOF
#!/usr/bin/env bash
printf '%s\n' "invoked:\$*" > "$fake_php_marker"
ini_file="\$2"
printf '%s\n' "\$ini_file" > "$fake_php_ini_marker"
[ -f "\$ini_file" ] || exit 90
case "\$ini_file" in
    "$tmp_dir/local-wp-${site_name}."*) ;;
    *) exit 92 ;;
esac
grep -Fq "$right_socket" "\$ini_file" || exit 91
grep -Fq "$wrong_socket" "\$ini_file" && exit 93
exit 42
EOF
    chmod +x "$fake_php"

    TMPDIR="$tmp_dir" LOCAL_SITES_DIR="$local_sites_dir" \
    LOCAL_RUN_DIR="$local_run_dir" \
    WP_CLI_PHAR="$wp_cli_phar" \
    PHP_BIN="$fake_php" \
    bash "$TOOLKIT_DIR/bin/local-wp" "$site_name" option get home >"$local_wp_log" 2>&1
    status=$?

    if [ "$status" -ne 42 ]; then
        echo "Expected fake PHP exit status 42, got $status"
        if [ -f "$fake_php_marker" ]; then
            cat "$fake_php_marker"
        else
            echo "Fake PHP stub was not invoked"
        fi
        if [ -s "$local_wp_log" ]; then
            cat "$local_wp_log"
        fi
        cleanup_test_root "$test_root" "$right_pid" "$wrong_pid"
        return 1
    fi

    if [ ! -f "$fake_php_ini_marker" ]; then
        echo "Fake PHP stub did not record the temporary ini path"
        cleanup_test_root "$test_root" "$right_pid" "$wrong_pid"
        return 1
    fi

    ini_file="$(cat "$fake_php_ini_marker")"

    if [ -e "$ini_file" ]; then
        echo "Expected temporary ini file to be cleaned: $ini_file"
        rm -f "$ini_file"
        cleanup_test_root "$test_root" "$right_pid" "$wrong_pid"
        return 1
    fi

    cleanup_test_root "$test_root" "$right_pid" "$wrong_pid"
    return 0
}

test_local_wp_modern_layout_prefers_active_socket() {
    local test_root=""
    local local_sites_dir=""
    local local_run_dir=""
    local tmp_dir=""
    local site_name="modern-site"
    local stale_id="a-stale"
    local live_id="z-live"
    local live_socket=""
    local live_pid=""
    local wp_cli_phar=""
    local fake_php=""
    local fake_php_ini_marker=""
    local local_wp_log=""
    local status=""

    test_root="$(make_temp_dir)" || return 1
    local_sites_dir="$test_root/local-sites"
    local_run_dir="$test_root/run"
    tmp_dir="$test_root/tmp"
    live_socket="$local_run_dir/$live_id/mysql/mysqld.sock"
    wp_cli_phar="$test_root/wp-cli.phar"
    fake_php="$test_root/fake-php.sh"
    fake_php_ini_marker="$test_root/fake-php.ini"
    local_wp_log="$test_root/local-wp.log"

    mkdir -p "$local_sites_dir/$site_name/app/public" \
             "$tmp_dir" \
             "$local_run_dir/$stale_id/conf/nginx" "$local_run_dir/$stale_id/mysql" \
             "$local_run_dir/$live_id/conf/nginx" "$local_run_dir/$live_id/mysql"
    touch "$local_sites_dir/$site_name/app/public/wp-config.php" "$wp_cli_phar"

    cat > "$local_run_dir/$stale_id/conf/nginx/site.conf" <<EOF
server {
    root "$local_sites_dir/$site_name/app/public";
    server_name $site_name.local *.$site_name.local;
}
EOF

    cat > "$local_run_dir/$live_id/conf/nginx/site.conf" <<EOF
server {
    root "$local_sites_dir/$site_name/app/public";
    server_name $site_name.local *.$site_name.local;
}
EOF

    start_socket_server "$live_socket" || {
        cleanup_test_root "$test_root"
        echo "Failed to create expected socket at $live_socket"
        return 1
    }
    live_pid="$START_SOCKET_SERVER_PID"

    cat > "$fake_php" <<EOF
#!/usr/bin/env bash
ini_file="\$2"
printf '%s\n' "\$ini_file" > "$fake_php_ini_marker"
[ -f "\$ini_file" ] || exit 90
grep -Fq "$live_socket" "\$ini_file" || exit 91
exit 42
EOF
    chmod +x "$fake_php"

    TMPDIR="$tmp_dir" LOCAL_SITES_DIR="$local_sites_dir" \
    LOCAL_RUN_DIR="$local_run_dir" \
    WP_CLI_PHAR="$wp_cli_phar" \
    PHP_BIN="$fake_php" \
    bash "$TOOLKIT_DIR/bin/local-wp" "$site_name" option get home >"$local_wp_log" 2>&1
    status=$?

    if [ "$status" -ne 42 ]; then
        echo "Expected fake PHP exit status 42, got $status"
        if [ -s "$local_wp_log" ]; then
            cat "$local_wp_log"
        fi
        cleanup_test_root "$test_root" "$live_pid"
        return 1
    fi

    if [ ! -f "$fake_php_ini_marker" ]; then
        echo "Fake PHP stub did not record the temporary ini path"
        cleanup_test_root "$test_root" "$live_pid"
        return 1
    fi

    cleanup_test_root "$test_root" "$live_pid"
    return 0
}

test_pw_auth_cleans_temp_files_after_validate_and_login_failures() {
    local test_root=""
    local fake_bin=""
    local tmp_dir=""
    local auth_dir=""
    local auth_file=""
    local fake_wp=""
    local fake_node=""
    local log_file=""
    local status=""

    test_root="$(make_temp_dir)" || return 1
    fake_bin="$test_root/bin"
    tmp_dir="$test_root/tmp"
    auth_dir="$test_root/temp/playwright/.auth"
    auth_file="$auth_dir/admin.json"
    fake_wp="$fake_bin/fake-wp"
    fake_node="$fake_bin/node"
    log_file="$test_root/pw-auth.log"

    mkdir -p "$fake_bin" "$tmp_dir" "$auth_dir"
    printf '{"cookies":[],"origins":[]}\n' > "$auth_file"

    cat > "$fake_wp" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'https://example.local/?dev_login=1&u=1&t=fake-token'
EOF

    cat > "$fake_node" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-e" ]; then
    exit 0
fi
if [ "${1:-}" = "-" ]; then
    printf '%s\n' "${2:-}"
    exit 0
fi
echo 'fake node failure for cleanup test' >&2
exit 127
EOF
    chmod +x "$fake_wp" "$fake_node"

    (
        cd "$test_root" || exit 1
        TMPDIR="$tmp_dir" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
            bash "$TOOLKIT_DIR/bin/pw-auth" login --site-url "https://example.local" --wp-cli fake-wp
    ) > "$log_file" 2>&1
    status=$?

    if [ "$status" -ne 1 ]; then
        echo "Expected pw-auth to return 1 after fake node failure, got $status"
        cleanup_test_root "$test_root"
        return 1
    fi

    if find "$tmp_dir" -maxdepth 1 -type f -print -quit | grep -q .; then
        echo "Expected pw-auth temp directory to be empty after failure"
        find "$tmp_dir" -maxdepth 1 -type f -print | sort
        cleanup_test_root "$test_root"
        return 1
    fi

    if ! grep -Fq 'Cached auth is fresh but no longer valid. Re-authenticating...' "$log_file"; then
        echo "Expected validate failure path to re-authenticate"
        cleanup_test_root "$test_root"
        return 1
    fi

    if ! grep -Fq 'fake node failure for cleanup test' "$log_file"; then
        echo "Expected fake node failure to appear in pw-auth output"
        cleanup_test_root "$test_root"
        return 1
    fi

    cleanup_test_root "$test_root"
    return 0
}

test_pw_auth_doctor_reports_partial_json_with_fake_runtime() {
    local test_root=""
    local fake_bin=""
    local tmp_dir=""
    local fake_wp=""
    local fake_node=""
    local output_file=""
    local status=""

    test_root="$(make_temp_dir)" || return 1
    fake_bin="$test_root/bin"
    tmp_dir="$test_root/tmp"
    fake_wp="$fake_bin/fake-wp"
    fake_node="$fake_bin/node"
    output_file="$test_root/pw-auth-doctor.json"

    mkdir -p "$fake_bin" "$tmp_dir"

    cat > "$fake_wp" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

    cat > "$fake_node" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-e" ]; then
    exit 0
fi

if [ "${1:-}" != "-" ]; then
    echo "unexpected fake node invocation: $*" >&2
    exit 97
fi

script="$(cat)"

case "$script" in
    *"new URL(process.argv[2]).origin"*)
        printf '%s\n' 'http://example.local'
        exit 0
        ;;
    *"const tokens = []"*)
        printf '%s\n' 'fake-wp'
        exit 0
        ;;
    *"executablePath="*)
        printf '%s\n' 'executablePath=/tmp/fake-chromium'
        printf '%s\n' 'binaryExists=true'
        printf '%s\n' 'launchOk=true'
        printf '%s\n' 'launchMessage=Chromium launched successfully.'
        exit 0
        ;;
esac

echo 'unexpected fake node stdin payload' >&2
exit 98
EOF
    chmod +x "$fake_wp" "$fake_node"

    (
        cd "$test_root" || exit 1
        TMPDIR="$tmp_dir" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
            bash "$TOOLKIT_DIR/bin/pw-auth" doctor --site-url "http://example.local" --wp-cli fake-wp --format json
    ) > "$output_file" 2>&1
    status=$?

    if [ "$status" -ne 1 ]; then
        echo "Expected pw-auth doctor to return 1 (partial), got $status"
        cat "$output_file"
        cleanup_test_root "$test_root"
        return 1
    fi

    grep -Fq '"status": "partial"' "$output_file" || {
        echo "Expected partial status in pw-auth doctor JSON output"
        cat "$output_file"
        cleanup_test_root "$test_root"
        return 1
    }

    grep -Fq '"name": "playwright_module", "status": "pass"' "$output_file" || {
        echo "Expected Playwright module check to pass"
        cat "$output_file"
        cleanup_test_root "$test_root"
        return 1
    }

    grep -Fq '"name": "browser_launch", "status": "pass"' "$output_file" || {
        echo "Expected browser launch check to pass"
        cat "$output_file"
        cleanup_test_root "$test_root"
        return 1
    }

    grep -Fq '"name": "auth_file", "status": "warn"' "$output_file" || {
        echo "Expected missing auth file warning in doctor JSON output"
        cat "$output_file"
        cleanup_test_root "$test_root"
        return 1
    }

    grep -Fq '"file_path": "temp/playwright/.auth/admin.json"' "$output_file" || {
        echo "Expected relative auth file path in doctor JSON output"
        cat "$output_file"
        cleanup_test_root "$test_root"
        return 1
    }

    cleanup_test_root "$test_root"
    return 0
}

test_pw_auth_check_dom_writes_json_and_extract_artifacts_with_fake_runtime() {
    local test_root=""
    local fake_bin=""
    local tmp_dir=""
    local fake_node=""
    local output_dir=""
    local auth_dir=""
    local auth_file=""
    local output_file=""
    local status=""

    test_root="$(make_temp_dir)" || return 1
    fake_bin="$test_root/bin"
    tmp_dir="$test_root/tmp"
    output_dir="$test_root/custom-output"
    auth_dir="$test_root/temp/playwright/.auth"
    auth_file="$auth_dir/admin.json"
    fake_node="$fake_bin/node"
    output_file="$test_root/pw-auth-check.json"

    mkdir -p "$fake_bin" "$tmp_dir" "$output_dir" "$auth_dir"
    printf '{"cookies":[{"name":"wordpress_logged_in_fake"}],"origins":[]}\n' > "$auth_file"

    cat > "$fake_node" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-e" ]; then
    exit 0
fi

if [ "${1:-}" = "-" ]; then
    script="$(cat)"
    case "$script" in
        *"new URL(process.argv[2]).origin"*)
            printf '%s\n' 'http://example.local'
            exit 0
            ;;
    esac
    echo 'unexpected fake node stdin payload' >&2
    exit 98
fi

script_path="$1"
script_contents="$(cat "$script_path")"

case "$script_contents" in
    *"pw-auth: Playwright DOM inspection"*)
        check_url="$2"
        selector="$3"
        extract_mode="$4"
        auth_file="$5"
        auth_origin="$6"
        result_json="$7"
        extract_file="$8"
        output_format="${10}"
        mkdir -p "$(dirname "$result_json")"
        printf '%s' '<div class="widget">Widget Area</div>' > "$extract_file"
        cat > "$result_json" <<JSON
{
  "status": "ok",
  "url": "$check_url",
  "selector": "$selector",
  "extract": "$extract_mode",
  "auth_used": true,
  "value": "<div class=\"widget\">Widget Area</div>",
  "artifacts": {
    "output_dir": "custom-output",
    "result_json": "custom-output/result.json",
    "extract_file": "custom-output/extract.html"
  },
  "errors": []
}
JSON
        if [ "$output_format" = "json" ]; then
            cat "$result_json"
        else
            printf '%s\n' '[pw-auth] DOM check status: ok'
        fi
        [ -f "$auth_file" ] || exit 96
        [ "$auth_origin" = 'http://example.local' ] || exit 95
        exit 0
        ;;
esac

echo "unexpected fake node invocation: $*" >&2
exit 97
EOF
    chmod +x "$fake_node"

    (
        cd "$test_root" || exit 1
        TMPDIR="$tmp_dir" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
            bash "$TOOLKIT_DIR/bin/pw-auth" check dom \
                --url "http://example.local/wp-admin/widgets.php" \
                --selector "#widgets-right" \
                --extract html \
                --user admin \
                --format json \
                --output-dir custom-output
    ) > "$output_file" 2>&1
    status=$?

    if [ "$status" -ne 0 ]; then
        echo "Expected pw-auth check dom to return 0, got $status"
        cat "$output_file"
        cleanup_test_root "$test_root"
        return 1
    fi

    grep -Fq '"status": "ok"' "$output_file" || {
        echo "Expected ok status in pw-auth check dom output"
        cat "$output_file"
        cleanup_test_root "$test_root"
        return 1
    }

    grep -Fq '"extract_file": "custom-output/extract.html"' "$test_root/custom-output/result.json" || {
        echo "Expected extract artifact path in result JSON"
        cat "$test_root/custom-output/result.json"
        cleanup_test_root "$test_root"
        return 1
    }

    grep -Fq '<div class="widget">Widget Area</div>' "$test_root/custom-output/extract.html" || {
        echo "Expected HTML extract artifact to be written"
        cleanup_test_root "$test_root"
        return 1
    }

    cleanup_test_root "$test_root"
    return 0
}

test_pw_auth_check_dom_returns_selector_failure_exit_code_with_fake_runtime() {
    local test_root=""
    local fake_bin=""
    local tmp_dir=""
    local fake_node=""
    local output_file=""
    local status=""

    test_root="$(make_temp_dir)" || return 1
    fake_bin="$test_root/bin"
    tmp_dir="$test_root/tmp"
    fake_node="$fake_bin/node"
    output_file="$test_root/pw-auth-check-not-found.json"

    mkdir -p "$fake_bin" "$tmp_dir"

    cat > "$fake_node" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-e" ]; then
    exit 0
fi

if [ "${1:-}" = "-" ]; then
    script="$(cat)"
    case "$script" in
        *"new URL(process.argv[2]).origin"*)
            printf '%s\n' 'http://example.local'
            exit 0
            ;;
    esac
    echo 'unexpected fake node stdin payload' >&2
    exit 98
fi

script_path="$1"
script_contents="$(cat "$script_path")"

case "$script_contents" in
    *"pw-auth: Playwright DOM inspection"*)
        result_json="$7"
        mkdir -p "$(dirname "$result_json")"
        cat > "$result_json" <<JSON
{
  "status": "not_found",
  "url": "$2",
  "selector": "$3",
  "extract": "$4",
  "auth_used": false,
  "value": false,
  "artifacts": {
    "output_dir": "temp/playwright/checks/fake-run",
    "result_json": "temp/playwright/checks/fake-run/result.json",
    "extract_file": null
  },
  "errors": ["Selector not found: $3"]
}
JSON
        cat "$result_json"
        exit 3
        ;;
esac

echo "unexpected fake node invocation: $*" >&2
exit 97
EOF
    chmod +x "$fake_node"

    (
        cd "$test_root" || exit 1
        TMPDIR="$tmp_dir" PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
            bash "$TOOLKIT_DIR/bin/pw-auth" check dom \
                --url "http://example.local/" \
                --selector ".missing-widget" \
                --extract exists \
                --format json
    ) > "$output_file" 2>&1
    status=$?

    if [ "$status" -ne 3 ]; then
        echo "Expected pw-auth check dom to return 3 for selector failure, got $status"
        cat "$output_file"
        cleanup_test_root "$test_root"
        return 1
    fi

    grep -Fq '"status": "not_found"' "$output_file" || {
        echo "Expected not_found status in pw-auth check dom output"
        cat "$output_file"
        cleanup_test_root "$test_root"
        return 1
    }

    grep -Fq 'Selector not found: .missing-widget' "$output_file" || {
        echo "Expected selector-missing error in pw-auth check dom output"
        cat "$output_file"
        cleanup_test_root "$test_root"
        return 1
    }

    cleanup_test_root "$test_root"
    return 0
}

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AI-DDTK Wrapper Cleanup Regression Test Suite      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

run_test "dev-login validates incoming request hosts" test_dev_login_request_host_validation
run_test "local-wp exact-matches site config and cleans unique temp ini" test_local_wp_exact_match_lookup_and_cleanup
run_test "local-wp supports modern Local run layout and prefers the active socket" test_local_wp_modern_layout_prefers_active_socket
run_test "pw-auth cleans temp files after validate/login failure paths" test_pw_auth_cleans_temp_files_after_validate_and_login_failures
run_test "pw-auth doctor reports partial JSON with fake runtime" test_pw_auth_doctor_reports_partial_json_with_fake_runtime
run_test "pw-auth check dom writes JSON + extract artifacts with fake runtime" test_pw_auth_check_dom_writes_json_and_extract_artifacts_with_fake_runtime
run_test "pw-auth check dom returns selector failure exit code with fake runtime" test_pw_auth_check_dom_returns_selector_failure_exit_code_with_fake_runtime

echo ""
echo "============================================================"
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "============================================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

exit 0