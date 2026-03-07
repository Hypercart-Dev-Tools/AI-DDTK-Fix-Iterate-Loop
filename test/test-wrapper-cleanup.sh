#!/usr/bin/env bash
# ============================================================
# AI-DDTK Wrapper Cleanup Regression Tests
# ============================================================
#
# PURPOSE:
#   Validates temp-file cleanup and fixed-string lookup behavior
#   for the local-wp and pw-auth shell wrappers.
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

test_local_wp_fixed_string_lookup_and_cleanup() {
    local test_root=""
    local local_sites_dir=""
    local local_run_dir=""
    local site_name="regex.site"
    local wrong_name="regexXsite"
    local wrong_id="a-match"
    local right_id="z-correct"
    local wrong_socket=""
    local right_socket=""
    local wrong_pid=""
    local right_pid=""
    local wp_cli_phar=""
    local fake_php=""
    local fake_php_marker=""
    local ini_file="/tmp/local-wp-${site_name}.ini"
    local local_wp_log=""
    local status=""

    test_root="$(make_temp_dir)" || return 1
    local_sites_dir="$test_root/local-sites"
    local_run_dir="$test_root/run"
    wrong_socket="$local_run_dir/$wrong_id/mysql/mysqld.sock"
    right_socket="$local_run_dir/$right_id/mysql/mysqld.sock"
    wp_cli_phar="$test_root/wp-cli.phar"
    fake_php="$test_root/fake-php.sh"
    fake_php_marker="$test_root/fake-php.marker"
    local_wp_log="$test_root/local-wp.log"

    mkdir -p "$local_sites_dir/$site_name/app/public" \
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
[ -f "\$ini_file" ] || exit 90
grep -Fq "$right_socket" "\$ini_file" || exit 91
exit 42
EOF
    chmod +x "$fake_php"

    rm -f "$ini_file"
    LOCAL_SITES_DIR="$local_sites_dir" \
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

    if [ -e "$ini_file" ]; then
        echo "Expected temporary ini file to be cleaned: $ini_file"
        rm -f "$ini_file"
        cleanup_test_root "$test_root" "$right_pid" "$wrong_pid"
        return 1
    fi

    cleanup_test_root "$test_root" "$right_pid" "$wrong_pid"
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

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   AI-DDTK Wrapper Cleanup Regression Test Suite      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

run_test "local-wp uses fixed-string lookup and cleans temp ini" test_local_wp_fixed_string_lookup_and_cleanup
run_test "pw-auth cleans temp files after validate/login failure paths" test_pw_auth_cleans_temp_files_after_validate_and_login_failures

echo ""
echo "============================================================"
echo -e "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "============================================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

exit 0