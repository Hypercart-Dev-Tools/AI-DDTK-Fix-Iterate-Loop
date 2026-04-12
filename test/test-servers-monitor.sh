#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/tools/servers-monitor.sh"

make_mock_bin() {
    local dir="$1"

    cat > "$dir/pgrep" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *dnsmasq*) exit 0 ;;
    *) exit 1 ;;
esac
EOF

    cat > "$dir/shasum" <<'EOF'
#!/usr/bin/env bash
python3 - "$1" "$2" <<'PY'
import hashlib
import sys

algorithm = 'sha256'
path = sys.argv[2]
with open(path, 'rb') as handle:
    digest = hashlib.new(algorithm, handle.read()).hexdigest()
print(f"{digest}  {path}")
PY
EOF

    chmod +x "$dir/pgrep" "$dir/shasum"
}

test_overlap_lock_returns_clean_json() {
    local tmpdir mockbin output
    tmpdir="$(mktemp -d)"
    mockbin="$tmpdir/mockbin"
    mkdir -p "$mockbin" "$tmpdir/lock"
    make_mock_bin "$mockbin"

    cat > "$mockbin/lsof" <<'EOF'
#!/usr/bin/env bash
printf 'COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME\n'
printf 'mysql 100 user 1u IPv4 0 0 TCP 127.0.0.1:3306\n'
EOF
    chmod +x "$mockbin/lsof"

    cat > "$tmpdir/servers-monitor.conf" <<'EOF'
DEVICE_NAME="test-machine"
EOF

    printf '%s\n' "$$" > "$tmpdir/lock/pid"
    printf '%s\n' "$(date +%s)" > "$tmpdir/lock/started_at"

    output="$({
        PATH="$mockbin:/usr/bin:/bin" \
        SERVERS_MONITOR_CONF="$tmpdir/servers-monitor.conf" \
        SERVERS_MONITOR_LOCK_DIR="$tmpdir/lock" \
        bash "$SCRIPT" --json
    } 2>&1)"

    rm -rf "$tmpdir"

    [[ "$output" == *'"status":"error"'* ]] && [[ "$output" == *'already running'* ]]
}

test_stale_lock_is_recovered() {
    local tmpdir mockbin output
    tmpdir="$(mktemp -d)"
    mockbin="$tmpdir/mockbin"
    mkdir -p "$mockbin" "$tmpdir/lock"
    make_mock_bin "$mockbin"

    cat > "$mockbin/lsof" <<'EOF'
#!/usr/bin/env bash
printf 'COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME\n'
printf 'mysql 100 user 1u IPv4 0 0 TCP 127.0.0.1:3306\n'
EOF
    chmod +x "$mockbin/lsof"

    cat > "$tmpdir/servers-monitor.conf" <<'EOF'
DEVICE_NAME="test-machine"
EOF

    printf '%s\n' "999999" > "$tmpdir/lock/pid"
    printf '%s\n' "$(( $(date +%s) - 3600 ))" > "$tmpdir/lock/started_at"

    output="$({
        PATH="$mockbin:/usr/bin:/bin" \
        SERVERS_MONITOR_CONF="$tmpdir/servers-monitor.conf" \
        SERVERS_MONITOR_LOCK_DIR="$tmpdir/lock" \
        SERVERS_MONITOR_LOCK_STALE_SECONDS="5" \
        bash "$SCRIPT" --json
    } 2>&1)"

    rm -rf "$tmpdir"

    [[ "$output" == *'"status": "ok"'* || "$output" == *'"status":"ok"'* ]]
}

test_probe_timeout_becomes_issue() {
    local tmpdir mockbin output
    tmpdir="$(mktemp -d)"
    mockbin="$tmpdir/mockbin"
    mkdir -p "$mockbin"
    make_mock_bin "$mockbin"

    cat > "$mockbin/lsof" <<'EOF'
#!/usr/bin/env bash
sleep 1
printf 'COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME\n'
EOF
    chmod +x "$mockbin/lsof"

    cat > "$tmpdir/servers-monitor.conf" <<'EOF'
DEVICE_NAME="test-machine"
EOF

    output="$({
        PATH="$mockbin:/usr/bin:/bin" \
        SERVERS_MONITOR_CONF="$tmpdir/servers-monitor.conf" \
        SERVERS_MONITOR_LOCK_DIR="$tmpdir/lock" \
        SERVERS_MONITOR_COMMAND_TIMEOUT_SECONDS="0.1" \
        bash "$SCRIPT" --json
    } 2>&1)"

    rm -rf "$tmpdir"

    [[ "$output" == *'probe-lsof-timeout'* ]]
}

test_overlap_lock_returns_clean_json
test_stale_lock_is_recovered
test_probe_timeout_becomes_issue