#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_TEMPLATE="$SCRIPT_DIR/servers.md"
LOCAL_SITES_JSON="${LOCAL_SITES_JSON:-$HOME/Library/Application Support/Local/sites.json}"

OUTPUT_PATH=""
PREVIOUS_SNAPSHOT=""
FOCUS_MODE="full"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR=""
DRY_RUN=0

# Verify mode
VERIFY_DOMAIN=""

# AI agent hooks
HOOK_SCRIPT=""
JSON_EVENTS=0
JSON_EVENTS_FD=""

LSOF_BIN="${LSOF_BIN:-lsof}"
BREW_BIN="${BREW_BIN:-brew}"
LOCAL_WP_BIN="${LOCAL_WP_BIN:-$TOOLKIT_ROOT/bin/local-wp}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

CONFLICT_COUNT=0
CONFLICTS_FILE=""
PRIORITY_FILE=""

LISTENERS_RAW=""
LISTENERS_TSV=""
LISTENERS_MD_ROWS=""
PORT_COUNTS_TSV=""
HOSTS_FILTERED=""
HOSTS_DOMAINS=""
LOCAL_SITES_SECTION=""
LOCAL_DOMAINS=""
LOCAL_PORTS=""
LOCAL_RESOLUTION=""
UNRESOLVED_DOMAINS=""
BREW_SERVICES_RAW=""
BREW_RUNNING_NAMES=""
DNS_RESOLVER_RAW=""
MDNS_STATUS_RAW=""
SERVICE_MANAGER_RAW=""
REPORT_JSON=""

MACHINE_TYPE="unknown"
MACHINE_NAME="unknown"
PRIMARY_USER="unknown"
OS_VERSION="unknown"
SNAPSHOT_DATE=""
LOCAL_SITE_COUNT=0

# Verify mode counters
VERIFY_PASS=0
VERIFY_FAIL=0
VERIFY_RESULTS=""

# ─── AI Agent Event System ───────────────────────────────────────────────────
#
# Events are emitted at each lifecycle stage so that an external AI agent can
# orchestrate, gate, or react to the audit/verify pipeline.
#
# Two mechanisms (can be combined):
#
#   --hook <script>     Called as:  <script> <event-name> '<json-payload>'
#                       The hook can inspect/log/gate each stage. A non-zero
#                       exit from the hook aborts the pipeline.
#
#   --json-events       Emits one JSON object per line to fd 3 (if open) or
#                       stderr. An agent can pipe fd 3 to parse progress:
#                         3> >(jq --unbuffered .)
#
# Event catalogue:
#   audit:start          Config resolved, collection about to begin
#   collect:listeners    TCP listener scan complete
#   collect:hosts        /etc/hosts parsed
#   collect:dns          DNS resolver info collected
#   collect:services     Service manager data collected
#   collect:local-wp     Local WP sites parsed
#   detect:conflicts     Conflict detection pass complete
#   verify:start         Hostname verification beginning (--verify mode)
#   verify:test          Individual verification test result
#   verify:complete      All verification tests finished
#   report:written       Markdown + JSON report files written
#   audit:complete       Pipeline finished
# ─────────────────────────────────────────────────────────────────────────────

emit_event() {
    local event_name="$1"
    local json_payload="${2:-{}}"

    if [ -n "$HOOK_SCRIPT" ]; then
        if ! "$HOOK_SCRIPT" "$event_name" "$json_payload"; then
            echo "Hook aborted pipeline at event: $event_name" >&2
            exit 2
        fi
    fi

    if [ "$JSON_EVENTS" -eq 1 ]; then
        local line
        line="$(printf '{"event":"%s","ts":"%s","payload":%s}' \
            "$event_name" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$json_payload")"
        if [ -n "$JSON_EVENTS_FD" ]; then
            echo "$line" >&3 2>/dev/null || echo "$line" >&2
        else
            echo "$line" >&2
        fi
    fi
}

show_help() {
    cat <<'EOF'
AI-DDTK Development Server Audit & Hostname Verification

Captures a local machine baseline for hostname and port troubleshooting, then
writes a populated Markdown report. Optionally verifies a specific domain's
hostname configuration end-to-end.

Usage:
  servers-audit.sh --output <path> [options]
  servers-audit.sh --verify <domain> [--output <path>] [options]

Required (audit mode):
  --output <path>                Destination Markdown file

Verify mode:
  --verify <domain>              Run hostname verification tests for <domain>
                                 (e.g. neochrome-timesheets.local)

Options:
  --previous-snapshot <path>     Previous known-good snapshot path for reference
  --focus <full|hostname|port>   Prioritize specific conflict class in "Priority Fixes"
  --run-id <id>                  Override run id (default: timestamp)
  --run-dir <path>               Override artifact directory
  --dry-run                      Resolve configuration only; do not collect
  --help                         Show this help

AI Agent Hooks:
  --hook <script>                Call <script> <event> <json> at each lifecycle
                                 stage. Non-zero exit aborts the pipeline.
  --json-events                  Emit JSON-line events to fd 3 (or stderr).
                                 Pipe fd 3 for structured progress tracking:
                                   servers-audit.sh ... 3> >(jq .)

Examples:
  # Full audit
  servers-audit.sh --output ~/servers-audit.md

  # Audit with AI agent hooks
  servers-audit.sh --output ~/audit.md --hook ./my-agent-hook.sh --json-events

  # Verify a single domain
  servers-audit.sh --verify neochrome-timesheets.local

  # Full audit + domain verification
  servers-audit.sh --output ~/audit.md --verify mysite.local

  # Diff against previous snapshot
  servers-audit.sh --output /tmp/now.md --previous-snapshot ~/audit.md --focus hostname
EOF
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

resolve_tool() {
    local configured_path="$1"
    local fallback_command="$2"
    local required="${3:-0}"

    if [ -n "$configured_path" ] && [ -x "$configured_path" ]; then
        printf '%s\n' "$configured_path"
        return 0
    fi

    if command -v "$fallback_command" >/dev/null 2>&1; then
        command -v "$fallback_command"
        return 0
    fi

    if [ "$required" -eq 1 ]; then
        fail "$fallback_command is required but not found"
    fi

    printf '%s\n' ""
    return 0
}

to_lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

escape_md_cell() {
    printf '%s' "$1" | tr '\n' ' ' | sed -e 's/|/\\|/g'
}

json_escape() {
    printf '%s' "$1" | sed \
        -e 's/\\/\\\\/g' \
        -e 's/"/\\"/g' \
        -e 's/\r/\\r/g' \
        -e 's/\t/\\t/g' \
        -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g'
}

severity_score() {
    case "$1" in
        critical) echo 40 ;;
        high) echo 30 ;;
        medium) echo 20 ;;
        low) echo 10 ;;
        *) echo 0 ;;
    esac
}

focus_bonus() {
    local category="$1"
    case "$FOCUS_MODE" in
        full) echo 0 ;;
        hostname)
            if [ "$category" = "hostname" ]; then echo 8; else echo 0; fi
            ;;
        port)
            if [ "$category" = "port" ]; then echo 8; else echo 0; fi
            ;;
        *) echo 0 ;;
    esac
}

capitalize_first() {
    printf '%s' "$1" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}'
}

add_conflict() {
    local category="$1"
    local severity="$2"
    local title="$3"
    local happening="$4"
    local why="$5"
    local fix="$6"
    local verify="$7"
    local one_liner_fix="$8"
    local score
    local happening_rendered=""
    local why_rendered=""
    local fix_rendered=""
    local verify_rendered=""

    CONFLICT_COUNT=$((CONFLICT_COUNT + 1))
    score=$(( $(severity_score "$severity") + $(focus_bonus "$category") ))
    happening_rendered="$(printf '%b' "$happening")"
    why_rendered="$(printf '%b' "$why")"
    fix_rendered="$(printf '%b' "$fix")"
    verify_rendered="$(printf '%b' "$verify")"

    cat >> "$CONFLICTS_FILE" <<EOF
### Conflict #$CONFLICT_COUNT: $title

**Severity:** $(capitalize_first "$severity")

**What's happening:**
$happening_rendered

**Why it exists:**
$why_rendered

**Fix:**
\`\`\`bash
$fix_rendered
\`\`\`

**Verification:**
\`\`\`bash
$verify_rendered
\`\`\`

---

EOF

    printf '%s\t%s\t%s\t%s\n' "$score" "$severity" "$title" "$one_liner_fix" >> "$PRIORITY_FILE"
}

extract_port_from_endpoint() {
    local endpoint="$1"
    printf '%s\n' "$endpoint" | sed -nE 's/.*:([0-9]+)$/\1/p'
}

listener_notes() {
    local endpoint="$1"
    if printf '%s' "$endpoint" | grep -Eq '^(\*|\[::\]):'; then
        printf 'all interfaces'
        return
    fi
    if printf '%s' "$endpoint" | grep -Eq '^(127\.0\.0\.1|localhost|\[::1\]):'; then
        printf 'loopback only'
        return
    fi
    printf 'bound interface'
}

classify_manager() {
    local process_name="$1"
    local pid="$2"
    local endpoint="${3:-}"
    local process_command=""
    local lower_name
    local lower_cmd
    local endpoint_port=""

    process_command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    lower_name="$(to_lower "$process_name")"
    lower_cmd="$(to_lower "$process_command")"
    endpoint_port="$(extract_port_from_endpoint "$endpoint")"

    if [ -n "$lower_cmd" ] && printf '%s' "$lower_cmd" | grep -Eq 'library/application support/local|/local/run/|local/lightning-services'; then
        printf 'Local WP'
        return
    fi

    if [ -n "$endpoint_port" ] && [ "$endpoint_port" -ge 10000 ] && [ "$endpoint_port" -le 19999 ] 2>/dev/null; then
        if printf '%s' "$lower_name" | grep -Eq 'nginx|mysqld|mailpit'; then
            printf 'Local WP'
            return
        fi
    fi

    if [ -n "$BREW_RUNNING_NAMES" ] && printf '%s\n' "$BREW_RUNNING_NAMES" | grep -Eq "^${lower_name}$"; then
        printf 'Homebrew'
        return
    fi

    if [ -n "$lower_cmd" ] && printf '%s' "$lower_cmd" | grep -Eq '/opt/homebrew/|/usr/local/cellar/|/home/linuxbrew/.linuxbrew/'; then
        printf 'Homebrew'
        return
    fi

    if printf '%s' "$lower_name" | grep -Eq 'mdnsresponder|launchd|configd|systemd-resolve|systemd'; then
        printf 'System'
        return
    fi

    if [ -n "$lower_cmd" ] && printf '%s' "$lower_cmd" | grep -Eq 'docker|com\.docker'; then
        printf 'Docker'
        return
    fi

    if [ -n "$lower_cmd" ] && printf '%s' "$lower_cmd" | grep -Eq 'valet|dnsmasq'; then
        printf 'Valet'
        return
    fi

    printf 'Unknown'
}

resolve_hostname_ip() {
    local host="$1"

    if [ "$(uname -s)" = "Darwin" ] && command -v dscacheutil >/dev/null 2>&1; then
        dscacheutil -q host -a name "$host" 2>/dev/null | awk '/ip_address:/ {print $2; exit}'
        return
    fi

    if command -v getent >/dev/null 2>&1; then
        getent hosts "$host" 2>/dev/null | awk '{print $1; exit}'
        return
    fi

    if command -v host >/dev/null 2>&1; then
        host "$host" 2>/dev/null | awk '/ has address / {print $4; exit}'
        return
    fi
}

# ─── Verify Mode Functions ───────────────────────────────────────────────────

verify_record() {
    local test_name="$1"
    local status="$2"  # pass, fail, info, warn
    local detail="$3"

    local json
    json="$(printf '{"test":"%s","status":"%s","detail":"%s"}' \
        "$(json_escape "$test_name")" "$status" "$(json_escape "$detail")")"

    VERIFY_RESULTS="${VERIFY_RESULTS}${json}"$'\n'

    emit_event "verify:test" "$json"

    case "$status" in
        pass) VERIFY_PASS=$((VERIFY_PASS + 1)) ;;
        fail) VERIFY_FAIL=$((VERIFY_FAIL + 1)) ;;
    esac
}

run_verify() {
    local domain="$1"

    local GREEN='\033[0;32m'
    local RED='\033[0;31m'
    local YELLOW='\033[1;33m'
    local NC='\033[0m'

    echo "========================================"
    echo "Hostname Verification: $domain"
    echo "========================================"
    echo ""

    emit_event "verify:start" "$(printf '{"domain":"%s"}' "$(json_escape "$domain")")"

    # Test 1: Router LaunchAgent (informational)
    echo "Test 1: Router LaunchAgent Plist (Optional)"
    echo "-----------------------------------"
    if [ -f ~/Library/LaunchAgents/com.getflywheel.local.router.plist ]; then
        echo -e "${GREEN}✓ INFO${NC} - Router plist exists (LaunchAgent mode)"
        verify_record "router_launchagent" "info" "Router plist exists (LaunchAgent mode)"
    else
        echo -e "${YELLOW}ℹ INFO${NC} - Router plist not found (Direct process mode)"
        echo "  This is fine - Local may manage router directly"
        verify_record "router_launchagent" "info" "Router plist not found (Direct process mode)"
    fi
    echo ""

    # Test 2: Port 80
    echo "Test 2: Router Listening on Port 80"
    echo "-----------------------------------"
    if lsof -i :80 -P -n 2>/dev/null | grep -q LISTEN; then
        echo -e "${GREEN}✓ PASS${NC} - Router listening on port 80"
        lsof -i :80 -P -n 2>/dev/null | grep LISTEN | head -1
        verify_record "port_80" "pass" "Router listening on port 80"
    else
        echo -e "${RED}✗ FAIL${NC} - No process listening on port 80"
        echo "  Router mode may not be enabled"
        verify_record "port_80" "fail" "No process listening on port 80"
    fi
    echo ""

    # Test 3: Port 443
    echo "Test 3: Router Listening on Port 443"
    echo "-----------------------------------"
    if lsof -i :443 -P -n 2>/dev/null | grep -q LISTEN; then
        echo -e "${GREEN}✓ PASS${NC} - Router listening on port 443"
        lsof -i :443 -P -n 2>/dev/null | grep LISTEN | head -1
        verify_record "port_443" "pass" "Router listening on port 443"
    else
        echo -e "${RED}✗ FAIL${NC} - No process listening on port 443"
        echo "  Router mode may not be enabled"
        verify_record "port_443" "fail" "No process listening on port 443"
    fi
    echo ""

    # Test 4: DNS resolution
    echo "Test 4: DNS Resolution"
    echo "-----------------------------------"
    if ping -c 1 "$domain" > /dev/null 2>&1; then
        local resolved_ip
        resolved_ip="$(ping -c 1 "$domain" 2>/dev/null | grep 'bytes from' | awk '{print $4}' | tr -d ':')"
        echo -e "${GREEN}✓ PASS${NC} - DNS resolution works"
        echo "  $domain resolves to: $resolved_ip"
        verify_record "dns_resolution" "pass" "$domain resolves to $resolved_ip"
    else
        echo -e "${RED}✗ FAIL${NC} - DNS resolution failed"
        echo "  Check /etc/hosts or Local's DNS proxy"
        verify_record "dns_resolution" "fail" "DNS resolution failed for $domain"
    fi
    echo ""

    # Test 5: WordPress database URLs
    echo "Test 5: WordPress Database URLs"
    echo "-----------------------------------"
    local site_slug
    site_slug="$(echo "$domain" | sed 's/\.local$//' | sed 's/\.test$//')"
    local wp_bin="${LOCAL_WP_BIN:-}"

    if [ -n "$wp_bin" ] && [ -x "$wp_bin" ]; then
        local siteurl home
        siteurl="$("$wp_bin" "$site_slug" option get siteurl 2>/dev/null || true)"
        home="$("$wp_bin" "$site_slug" option get home 2>/dev/null || true)"

        if [ -n "$siteurl" ] || [ -n "$home" ]; then
            local expected="https://$domain"
            if [ "$siteurl" = "$expected" ] && [ "$home" = "$expected" ]; then
                echo -e "${GREEN}✓ PASS${NC} - Database URLs are correct"
                echo "  siteurl: $siteurl"
                echo "  home: $home"
                verify_record "wp_urls" "pass" "siteurl=$siteurl home=$home"
            else
                echo -e "${RED}✗ FAIL${NC} - Database URLs are incorrect"
                echo "  siteurl: $siteurl"
                echo "  home: $home"
                echo "  Expected: $expected"
                verify_record "wp_urls" "fail" "siteurl=$siteurl home=$home expected=$expected"
            fi
        else
            echo -e "${YELLOW}⚠ WARN${NC} - Could not read WP options (site may not be running)"
            verify_record "wp_urls" "warn" "Could not read WP options for $site_slug"
        fi
    else
        echo -e "${YELLOW}⚠ WARN${NC} - local-wp binary not available, skipping WP URL check"
        verify_record "wp_urls" "warn" "local-wp binary not available"
    fi
    echo ""

    # Test 6: HTTP accessibility
    echo "Test 6: HTTP Accessibility"
    echo "-----------------------------------"
    local http_code
    http_code="$(curl -L -s -o /dev/null -w '%{http_code}' "http://$domain/" 2>/dev/null || echo "000")"
    if echo "$http_code" | grep -qE '^(200|301|302)$'; then
        echo -e "${GREEN}✓ PASS${NC} - Site accessible via HTTP"
        echo "  HTTP status: $http_code"
        verify_record "http_access" "pass" "HTTP status $http_code"
    else
        echo -e "${RED}✗ FAIL${NC} - Site not accessible via HTTP (status: $http_code)"
        verify_record "http_access" "fail" "HTTP status $http_code"
    fi
    echo ""

    # Test 7: HTTPS accessibility
    echo "Test 7: HTTPS Accessibility"
    echo "-----------------------------------"
    local https_code
    https_code="$(curl -L -k -s -o /dev/null -w '%{http_code}' "https://$domain/" 2>/dev/null || echo "000")"
    if echo "$https_code" | grep -qE '^(200|301|302)$'; then
        echo -e "${GREEN}✓ PASS${NC} - Site accessible via HTTPS"
        echo "  HTTPS status: $https_code"
        verify_record "https_access" "pass" "HTTPS status $https_code"
    else
        echo -e "${YELLOW}⚠ WARN${NC} - Site not accessible via HTTPS (status: $https_code)"
        echo "  This may be a curl/SSL issue - try in browser"
        verify_record "https_access" "warn" "HTTPS status $https_code"
    fi
    echo ""

    # Summary
    local total_tests=$((VERIFY_PASS + VERIFY_FAIL))
    echo "========================================"
    echo "Verification Summary"
    echo "========================================"
    echo "Tests Passed: $VERIFY_PASS"
    echo "Tests Failed: $VERIFY_FAIL"
    echo "Total Tests:  $total_tests"
    echo ""

    local verify_json
    verify_json="$(printf '{"domain":"%s","passed":%d,"failed":%d,"total":%d}' \
        "$(json_escape "$domain")" "$VERIFY_PASS" "$VERIFY_FAIL" "$total_tests")"
    emit_event "verify:complete" "$verify_json"

    if [ "$VERIFY_FAIL" -eq 0 ]; then
        echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
        echo "Site Domains mode is properly configured."
        echo ""
        echo "Access your site at:"
        echo "  https://$domain"
        echo "  https://$domain/wp-admin/"
    else
        echo -e "${RED}✗ SOME TESTS FAILED${NC}"
        echo "Please review the failures above."
    fi
}

# ─── Argument Parsing ────────────────────────────────────────────────────────

while [ $# -gt 0 ]; do
    case "$1" in
        --output) OUTPUT_PATH="$2"; shift 2 ;;
        --previous-snapshot) PREVIOUS_SNAPSHOT="$2"; shift 2 ;;
        --focus) FOCUS_MODE="$2"; shift 2 ;;
        --run-id) RUN_ID="$2"; shift 2 ;;
        --run-dir) RUN_DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --verify) VERIFY_DOMAIN="$2"; shift 2 ;;
        --hook) HOOK_SCRIPT="$2"; shift 2 ;;
        --json-events) JSON_EVENTS=1; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done

# Verify-only mode: no --output required
if [ -n "$VERIFY_DOMAIN" ] && [ -z "$OUTPUT_PATH" ]; then
    # Setup minimal event infrastructure
    if [ "$JSON_EVENTS" -eq 1 ]; then
        if { true >&3; } 2>/dev/null; then
            JSON_EVENTS_FD=3
        fi
    fi
    if [ -n "$HOOK_SCRIPT" ] && [ ! -x "$HOOK_SCRIPT" ]; then
        fail "Hook script is not executable: $HOOK_SCRIPT"
    fi
    LOCAL_WP_BIN="$(resolve_tool "$LOCAL_WP_BIN" local-wp)"
    run_verify "$VERIFY_DOMAIN"
    exit $VERIFY_FAIL
fi

[ -n "$OUTPUT_PATH" ] || fail "--output is required (or use --verify <domain> for verify-only mode)"

case "$FOCUS_MODE" in
    full|hostname|port) ;;
    *) fail "--focus must be one of: full, hostname, port" ;;
esac

LSOF_BIN="$(resolve_tool "$LSOF_BIN" lsof)"
BREW_BIN="$(resolve_tool "$BREW_BIN" brew)"
LOCAL_WP_BIN="$(resolve_tool "$LOCAL_WP_BIN" local-wp)"
PYTHON_BIN="$(resolve_tool "$PYTHON_BIN" python3)"

# Validate hook script
if [ -n "$HOOK_SCRIPT" ] && [ ! -x "$HOOK_SCRIPT" ]; then
    fail "Hook script is not executable: $HOOK_SCRIPT"
fi

# Detect fd 3 availability for json events
if [ "$JSON_EVENTS" -eq 1 ]; then
    if { true >&3; } 2>/dev/null; then
        JSON_EVENTS_FD=3
    fi
fi

RUN_DIR="${RUN_DIR:-$TOOLKIT_ROOT/temp/servers-audit/$RUN_ID}"
mkdir -p "$RUN_DIR"
mkdir -p "$(dirname "$OUTPUT_PATH")"

CONFLICTS_FILE="$RUN_DIR/conflicts.md"
PRIORITY_FILE="$RUN_DIR/priority.tsv"
LISTENERS_RAW="$RUN_DIR/listeners.raw.txt"
LISTENERS_TSV="$RUN_DIR/listeners.tsv"
LISTENERS_MD_ROWS="$RUN_DIR/listeners.md.rows"
PORT_COUNTS_TSV="$RUN_DIR/port-counts.tsv"
HOSTS_FILTERED="$RUN_DIR/hosts-local-test.txt"
HOSTS_DOMAINS="$RUN_DIR/hosts-domains.txt"
LOCAL_SITES_SECTION="$RUN_DIR/local-sites.txt"
LOCAL_DOMAINS="$RUN_DIR/local-domains.txt"
LOCAL_PORTS="$RUN_DIR/local-ports.tsv"
LOCAL_RESOLUTION="$RUN_DIR/local-resolution.txt"
UNRESOLVED_DOMAINS="$RUN_DIR/unresolved-domains.txt"
BREW_SERVICES_RAW="$RUN_DIR/brew-services.txt"
DNS_RESOLVER_RAW="$RUN_DIR/dns-resolver.txt"
MDNS_STATUS_RAW="$RUN_DIR/mdns-status.txt"
SERVICE_MANAGER_RAW="$RUN_DIR/service-manager-services.txt"
REPORT_JSON="$RUN_DIR/report.json"

: > "$CONFLICTS_FILE"
: > "$PRIORITY_FILE"
: > "$LISTENERS_MD_ROWS"
: > "$LISTENERS_TSV"
: > "$HOSTS_FILTERED"
: > "$HOSTS_DOMAINS"
: > "$LOCAL_SITES_SECTION"
: > "$LOCAL_DOMAINS"
: > "$LOCAL_PORTS"
: > "$LOCAL_RESOLUTION"
: > "$UNRESOLVED_DOMAINS"

if [ "$DRY_RUN" -eq 1 ]; then
    cat <<EOF
OUTPUT_PATH=$OUTPUT_PATH
RUN_ID=$RUN_ID
RUN_DIR=$RUN_DIR
FOCUS_MODE=$FOCUS_MODE
VERIFY_DOMAIN=${VERIFY_DOMAIN:-(none)}
HOOK_SCRIPT=${HOOK_SCRIPT:-(none)}
JSON_EVENTS=$JSON_EVENTS
LSOF_BIN=${LSOF_BIN:-missing}
BREW_BIN=${BREW_BIN:-missing}
LOCAL_WP_BIN=${LOCAL_WP_BIN:-missing}
PYTHON_BIN=${PYTHON_BIN:-missing}
LOCAL_SITES_JSON=$LOCAL_SITES_JSON
TEMPLATE=$DEFAULT_TEMPLATE
EOF
    exit 0
fi

# ─── Collection Phase ────────────────────────────────────────────────────────

emit_event "audit:start" "$(printf '{"runId":"%s","output":"%s","focus":"%s","verify":"%s"}' \
    "$(json_escape "$RUN_ID")" "$(json_escape "$OUTPUT_PATH")" \
    "$(json_escape "$FOCUS_MODE")" "$(json_escape "$VERIFY_DOMAIN")")"

MACHINE_TYPE="$(uname -m 2>/dev/null || echo unknown)"
MACHINE_NAME="$(scutil --get ComputerName 2>/dev/null || hostname 2>/dev/null || echo unknown)"
PRIMARY_USER="$(id -un 2>/dev/null || echo unknown)"
if [ "$(uname -s)" = "Darwin" ] && command -v sw_vers >/dev/null 2>&1; then
    OS_VERSION="$(sw_vers -productName 2>/dev/null || true) $(sw_vers -productVersion 2>/dev/null || true)"
else
    OS_VERSION="$(uname -sr 2>/dev/null || echo unknown)"
fi
SNAPSHOT_DATE="$(date '+%Y-%m-%d %H:%M:%S %Z')"

# Listeners
if [ -n "$LSOF_BIN" ]; then
    "$LSOF_BIN" -nP -iTCP -sTCP:LISTEN -Fpcn > "$LISTENERS_RAW" 2>/dev/null || true
else
    echo "lsof not available; install lsof to capture listening sockets." > "$LISTENERS_RAW"
fi

if [ -s "$LISTENERS_RAW" ]; then
    awk '
        /^p/ { pid=substr($0,2); next }
        /^c/ { cmd=substr($0,2); next }
        /^n/ {
            endpoint=substr($0,2)
            gsub(/\(LISTEN\)/, "", endpoint)
            if (cmd != "" && pid != "" && endpoint != "") {
                print cmd "\t" pid "\t" endpoint
            }
        }
    ' \
        "$LISTENERS_RAW" | sort -u > "$RUN_DIR/listeners.flat.tsv"
else
    : > "$RUN_DIR/listeners.flat.tsv"
fi

emit_event "collect:listeners" "$(printf '{"file":"%s"}' "$(json_escape "$LISTENERS_RAW")")"

# Brew services
if [ -n "$BREW_BIN" ]; then
    "$BREW_BIN" services list > "$BREW_SERVICES_RAW" 2>&1 || true
    BREW_RUNNING_NAMES="$(
        awk 'NR>1 && tolower($2)=="started" { print tolower($1) }' "$BREW_SERVICES_RAW" 2>/dev/null || true
    )"
else
    echo "brew not available." > "$BREW_SERVICES_RAW"
fi

{
    echo -e "process\tpid\tendpoint\tmanager\tnotes\tport"
    while IFS=$'\t' read -r process_name pid endpoint; do
        [ -n "$process_name" ] || continue
        manager="$(classify_manager "$process_name" "$pid" "$endpoint")"
        notes="$(listener_notes "$endpoint")"
        port="$(extract_port_from_endpoint "$endpoint")"
        echo -e "${process_name}\t${pid}\t${endpoint}\t${manager}\t${notes}\t${port}"
    done < "$RUN_DIR/listeners.flat.tsv"
} > "$LISTENERS_TSV"

if [ -s "$LISTENERS_TSV" ]; then
    tail -n +2 "$LISTENERS_TSV" | while IFS=$'\t' read -r process_name pid endpoint manager notes port; do
        process_name="$(escape_md_cell "$process_name")"
        endpoint="$(escape_md_cell "$endpoint")"
        manager="$(escape_md_cell "$manager")"
        notes="$(escape_md_cell "$notes")"
        printf '| %s | %s | %s | %s | %s |\n' "$process_name" "$pid" "$endpoint" "$manager" "$notes" >> "$LISTENERS_MD_ROWS"
    done
fi

tail -n +2 "$LISTENERS_TSV" | awk -F'\t' 'NF>=6 && $6 ~ /^[0-9]+$/ { print $6 }' | sort -n -u > "$PORT_COUNTS_TSV"

# /etc/hosts — capture all dev domains (.local, .test, .dev, .app, Valet, custom)
if [ -f /etc/hosts ]; then
    awk '
        /^[[:space:]]*#/ { next }
        NF < 2 { next }
        {
            ip=$1
            for (i=2; i<=NF; i++) {
                host=$i
                sub(/#.*/, "", host)
                gsub(/[[:space:]]+/, "", host)
                if (host == "") next
                # Capture: .local, .test, .dev, .app, or any non-IP-like domain
                if (host ~ /\.(local|test|dev|app|localhost)$/ ||
                    (host !~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ && host !~ /^localhost$/)) {
                    print ip "\t" host
                }
            }
        }
    ' /etc/hosts > "$RUN_DIR/hosts.tsv"
else
    : > "$RUN_DIR/hosts.tsv"
fi

if [ -s "$RUN_DIR/hosts.tsv" ]; then
    awk -F'\t' '{ printf "%-15s %s\n", $1, $2 }' "$RUN_DIR/hosts.tsv" > "$HOSTS_FILTERED"
    awk -F'\t' '{ print $2 }' "$RUN_DIR/hosts.tsv" | sort -u > "$HOSTS_DOMAINS"
else
    echo "(no *.local or *.test entries found in /etc/hosts)" > "$HOSTS_FILTERED"
fi

emit_event "collect:hosts" "$(printf '{"file":"%s"}' "$(json_escape "$HOSTS_FILTERED")")"

# DNS resolvers
if [ "$(uname -s)" = "Darwin" ] && command -v scutil >/dev/null 2>&1; then
    scutil --dns > "$DNS_RESOLVER_RAW" 2>&1 || true
else
    if [ -f /etc/resolv.conf ]; then
        cat /etc/resolv.conf > "$DNS_RESOLVER_RAW"
    else
        echo "No resolver details available on this host." > "$DNS_RESOLVER_RAW"
    fi
fi

# mDNS status
if [ "$(uname -s)" = "Darwin" ]; then
    {
        echo "Platform: macOS"
        if pgrep -f mDNSResponder >/dev/null 2>&1; then
            echo "mDNSResponder: running (pid $(pgrep -f mDNSResponder | tr '\n' ' ' | sed 's/[[:space:]]*$//'))"
        else
            echo "mDNSResponder: not detected"
        fi
        echo
        echo "Ports 5353 listeners:"
        if [ -n "$LSOF_BIN" ]; then
            "$LSOF_BIN" -nP -iUDP:5353 -iTCP:5353 2>/dev/null || true
        else
            echo "lsof not available"
        fi
    } > "$MDNS_STATUS_RAW"
else
    {
        echo "Platform: $(uname -s)"
        echo "mDNS process check:"
        ps aux 2>/dev/null | grep -E 'avahi|mdns|systemd-resolved' | grep -v grep || true
    } > "$MDNS_STATUS_RAW"
fi

emit_event "collect:dns" "$(printf '{"resolver":"%s","mdns":"%s"}' \
    "$(json_escape "$DNS_RESOLVER_RAW")" "$(json_escape "$MDNS_STATUS_RAW")")"

# Local WP sites
if [ -n "$PYTHON_BIN" ] && [ -f "$LOCAL_SITES_JSON" ]; then
    "$PYTHON_BIN" - "$LOCAL_SITES_JSON" "$LOCAL_SITES_SECTION" "$LOCAL_DOMAINS" "$LOCAL_PORTS" <<'PY'
import json
import sys

path, section_path, domains_path, ports_path = sys.argv[1:]

def write_empty():
    with open(section_path, "w", encoding="utf-8") as f:
        f.write("No Local WP sites found.\n")
    open(domains_path, "w", encoding="utf-8").close()
    open(ports_path, "w", encoding="utf-8").close()

try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    write_empty()
    raise SystemExit(0)

if isinstance(data, dict):
    items = list(data.values())
elif isinstance(data, list):
    items = data
else:
    items = []

sites = []
domains = set()
ports = []

for raw_site in items:
    if not isinstance(raw_site, dict):
        continue
    name = str(raw_site.get("name", "")).strip()
    domain = str(raw_site.get("domain", "")).strip()
    path_value = str(raw_site.get("path", "")).strip()
    web_server = str(raw_site.get("webServer", "")).strip() or "-"
    php_version = str(raw_site.get("phpVersion", "")).strip() or "-"

    mysql_port = "-"
    mysql_value = raw_site.get("mysql")
    if isinstance(mysql_value, dict):
        for key in ("port", "externalPort"):
            value = mysql_value.get(key)
            if isinstance(value, int):
                mysql_port = str(value)
                ports.append((str(value), name or domain or "unknown", "mysql"))
                break
            if isinstance(value, str) and value.isdigit():
                mysql_port = value
                ports.append((value, name or domain or "unknown", "mysql"))
                break

    if domain:
        domains.add(domain)

    sites.append({
        "name": name or "(unnamed)",
        "domain": domain or "-",
        "web": web_server,
        "php": php_version,
        "mysql": mysql_port,
        "path": path_value or "-",
    })

sites.sort(key=lambda row: (row["name"].lower(), row["domain"].lower()))

with open(section_path, "w", encoding="utf-8") as f:
    if not sites:
        f.write("No Local WP sites found.\n")
    else:
        for row in sites:
            line = (
                f"- {row['name']} | domain={row['domain']} | web={row['web']} | "
                f"php={row['php']} | mysql_port={row['mysql']} | path={row['path']}"
            )
            f.write(line + "\n")

with open(domains_path, "w", encoding="utf-8") as f:
    for domain in sorted(domains):
        f.write(domain + "\n")

with open(ports_path, "w", encoding="utf-8") as f:
    for port, site_name, kind in sorted(ports):
        f.write(f"{port}\t{site_name}\t{kind}\n")
PY
else
    if [ -n "$LOCAL_WP_BIN" ]; then
        {
            echo "Local sites.json not found at:"
            echo "$LOCAL_SITES_JSON"
            echo
            echo "Fallback local-wp --help output:"
            "$LOCAL_WP_BIN" --help 2>/dev/null | sed -n '/Available sites:/,$p' || true
        } > "$LOCAL_SITES_SECTION"
    else
        echo "Local WP metadata unavailable (sites.json missing and local-wp not found)." > "$LOCAL_SITES_SECTION"
    fi
fi

if [ -s "$LOCAL_DOMAINS" ]; then
    LOCAL_SITE_COUNT="$(wc -l < "$LOCAL_DOMAINS" | tr -d ' ')"
else
    LOCAL_SITE_COUNT=0
fi

emit_event "collect:local-wp" "$(printf '{"siteCount":%d}' "$LOCAL_SITE_COUNT")"

# Domain resolution
if [ "$LOCAL_SITE_COUNT" -gt 0 ]; then
    while IFS= read -r domain; do
        [ -n "$domain" ] || continue
        ip="$(resolve_hostname_ip "$domain" || true)"
        if [ -n "$ip" ]; then
            printf '%s -> %s\n' "$domain" "$ip" >> "$LOCAL_RESOLUTION"
        else
            printf '%s\n' "$domain" >> "$UNRESOLVED_DOMAINS"
            printf '%s -> (unresolved)\n' "$domain" >> "$LOCAL_RESOLUTION"
        fi
    done < "$LOCAL_DOMAINS"
else
    echo "(no Local WP domains detected)" > "$LOCAL_RESOLUTION"
fi

# Service manager
if [ "$(uname -s)" = "Darwin" ]; then
    launchctl list 2>/dev/null | grep -Ei 'nginx|httpd|apache|mysql|mariadb|dnsmasq|postgres|php|caddy|local' > "$SERVICE_MANAGER_RAW" || true
else
    if command -v systemctl >/dev/null 2>&1; then
        systemctl list-units --type=service --all 2>/dev/null | grep -Ei 'nginx|httpd|apache|mysql|mariadb|dnsmasq|postgres|php|caddy|avahi' > "$SERVICE_MANAGER_RAW" || true
    else
        echo "No launchd/systemd service manager data available." > "$SERVICE_MANAGER_RAW"
    fi
fi

emit_event "collect:services" "$(printf '{"file":"%s"}' "$(json_escape "$SERVICE_MANAGER_RAW")")"

# ─── Conflict Detection ─────────────────────────────────────────────────────

# Port ownership collisions
if [ -s "$PORT_COUNTS_TSV" ]; then
    while IFS= read -r port; do
        [ -n "$port" ] || continue
        signature_count="$(
            awk -F'\t' -v p="$port" '
                NR > 1 && $6 == p {
                    sig=tolower($4 ":" $1)
                    seen[sig]=1
                }
                END {
                    c=0
                    for (k in seen) c++
                    print c+0
                }
            ' "$LISTENERS_TSV"
        )"

        if [ "${signature_count:-0}" -le 1 ]; then
            continue
        fi

        detail="$(
            awk -F'\t' -v p="$port" '
                NR > 1 && $6 == p {
                    row=sprintf("- %s (pid %s, %s, %s)", $1, $2, $3, $4)
                    if (!seen[row]++) print row
                }
            ' "$LISTENERS_TSV"
        )"

        severity="high"
        case "$port" in
            80|443|3306|8080) severity="critical" ;;
        esac

        add_conflict \
            "port" \
            "$severity" \
            "Multiple services are claiming port $port" \
            "Different service signatures are bound to TCP port $port:\n$detail" \
            "Competing stacks are trying to own the same port, which can break Local site startup, db availability, or reverse-proxy routing." \
            "lsof -nP -iTCP:$port -sTCP:LISTEN\n# stop the non-owner service (examples)\nbrew services list\nbrew services stop <service>" \
            "lsof -nP -iTCP:$port -sTCP:LISTEN\n# expect one intended owning service signature" \
            "lsof -nP -iTCP:$port -sTCP:LISTEN"
    done < "$PORT_COUNTS_TSV"
fi

# Key infrastructure ports with non-Local ownership
for key_port in 80 443 3306 8080; do
    signature_count="$(
        awk -F'\t' -v p="$key_port" '
            NR > 1 && $6 == p {
                sig=tolower($4 ":" $1)
                seen[sig]=1
            }
            END {
                c=0
                for (k in seen) c++
                print c+0
            }
        ' "$LISTENERS_TSV"
    )"
    if [ "${signature_count:-0}" -eq 0 ]; then
        continue
    fi

    listeners_for_port="$(
        awk -F'\t' -v p="$key_port" '
            NR > 1 && $6 == p {
                row=sprintf("- %s (pid %s, manager=%s, endpoint=%s)", $1, $2, $4, $3)
                if (!seen[row]++) print row
            }
        ' "$LISTENERS_TSV"
    )"

    if [ "$key_port" = "80" ] || [ "$key_port" = "443" ]; then
        if printf '%s\n' "$listeners_for_port" | grep -Eiq 'manager=Homebrew|httpd|apache|caddy'; then
            add_conflict \
                "port" \
                "medium" \
                "Web tier ownership on port $key_port may block Local routing" \
                "Port $key_port is currently owned by:\n$listeners_for_port" \
                "If non-Local web services auto-start, they can take over 80/443 and prevent Local WP domains from routing correctly." \
                "brew services list\nbrew services stop nginx\nbrew services stop httpd\nbrew services stop caddy" \
                "lsof -nP -iTCP:$key_port -sTCP:LISTEN\n# verify owner matches intended workflow" \
                "brew services stop nginx"
        fi
    fi
done

# Duplicate hosts entries
if [ -s "$RUN_DIR/hosts.tsv" ]; then
    awk -F'\t' '
        {
            host=$2
            ip=$1
            if (!(host SUBSEP ip in seen)) {
                seen[host SUBSEP ip]=1
                if (ips[host] == "") {
                    ips[host]=ip
                    counts[host]=1
                } else {
                    ips[host]=ips[host] "," ip
                    counts[host]++
                }
            }
        }
        END {
            for (h in counts) {
                if (counts[h] > 1) {
                    pair="," ips[h] ","
                    if (counts[h] == 2 && index(pair, ",127.0.0.1,") > 0 && index(pair, ",::1,") > 0) {
                        continue
                    }
                    printf "%s\t%s\n", h, ips[h]
                }
            }
        }
    ' "$RUN_DIR/hosts.tsv" > "$RUN_DIR/hosts-duplicate-ip.tsv"
fi

if [ -s "$RUN_DIR/hosts-duplicate-ip.tsv" ]; then
    while IFS=$'\t' read -r host ips; do
        add_conflict \
            "hostname" \
            "high" \
            "Hostname has multiple IP mappings: $host" \
            "The hostname \`$host\` appears with multiple IPs in /etc/hosts: $ips" \
            "Conflicting host mappings lead to non-deterministic resolution and intermittent \"hostname conflict\" behavior." \
            "grep -n \"[[:space:]]$host\" /etc/hosts\n# keep one canonical mapping and remove stale duplicates." \
            "grep -n \"[[:space:]]$host\" /etc/hosts\n# verify exactly one mapping remains" \
            "grep -n \"[[:space:]]$host\" /etc/hosts"
    done < "$RUN_DIR/hosts-duplicate-ip.tsv"
fi

# Stale dev domain entries (*.local, *.test, *.dev, *.app, Valet, etc.)
if [ -s "$HOSTS_DOMAINS" ] && [ -s "$LOCAL_DOMAINS" ]; then
    # Extract all dev-TLD domains from /etc/hosts (not just .local)
    awk '/\.(local|test|dev|app)$/ { print }' "$HOSTS_DOMAINS" | sort -u > "$RUN_DIR/hosts-dev-domains.txt"
    sort -u "$LOCAL_DOMAINS" > "$RUN_DIR/local-domains-sorted.txt"

    # Also capture Valet/custom domains (anything in /etc/hosts that's not a standard local domain)
    grep -v '/\.(local|test|dev|app)$' "$HOSTS_DOMAINS" 2>/dev/null >> "$RUN_DIR/hosts-dev-domains.txt" || true
    sort -u "$RUN_DIR/hosts-dev-domains.txt" > "$RUN_DIR/hosts-dev-domains-sorted.txt"

    # Find domains in /etc/hosts that don't match any active Local WP site
    awk '
        NR == FNR {
            domains[$1]=1
            next
        }
        {
            host=$1
            base=host
            sub(/^www\./, "", base)
            if (!(host in domains) && !(base in domains)) {
                print host
            }
        }
    ' "$RUN_DIR/local-domains-sorted.txt" "$RUN_DIR/hosts-dev-domains-sorted.txt" > "$RUN_DIR/stale-dev-hosts.txt"

    stale_count="$(wc -l < "$RUN_DIR/stale-dev-hosts.txt" | tr -d ' ')"
    if [ "${stale_count:-0}" -gt 0 ]; then
        stale_preview="$(head -n 20 "$RUN_DIR/stale-dev-hosts.txt" | sed 's/^/- /')"
        add_conflict \
            "hostname" \
            "medium" \
            "Potential stale dev hostnames in /etc/hosts" \
            "These entries do not match current Local WP domains or active services:\n$stale_preview" \
            "Old host entries from deleted/renamed Local sites, Valet, or custom dev stacks can hijack name resolution and trigger hostname conflicts." \
            "cat \"$RUN_DIR/stale-dev-hosts.txt\"\n# remove stale lines from /etc/hosts after confirming site retirement." \
            "grep -Ff \"$RUN_DIR/stale-dev-hosts.txt\" /etc/hosts || true" \
            "cat \"$RUN_DIR/stale-dev-hosts.txt\""
    fi
fi

# Unresolved Local domains
if [ -s "$UNRESOLVED_DOMAINS" ]; then
    unresolved_count="$(wc -l < "$UNRESOLVED_DOMAINS" | tr -d ' ')"
    unresolved_preview="$(head -n 25 "$UNRESOLVED_DOMAINS" | sed 's/^/- /')"
    add_conflict \
        "hostname" \
        "high" \
        "Local site domains are not resolving" \
        "$unresolved_count Local domains could not be resolved:\n$unresolved_preview" \
        "Resolver state, Local router state, or stale DNS cache can cause domains to disappear even when sites exist." \
        "local-wp --help\n# then verify Local app/router is running and flush DNS cache if needed:\nsudo dscacheutil -flushcache || true\nsudo killall -HUP mDNSResponder || true" \
        "while read -r d; do dscacheutil -q host -a name \"\$d\"; done < \"$UNRESOLVED_DOMAINS\"" \
        "while read -r d; do dscacheutil -q host -a name \"\$d\"; done < \"$UNRESOLVED_DOMAINS\""
fi

# .local entries with macOS mDNS precedence caveat
if [ "$(uname -s)" = "Darwin" ] && [ -s "$RUN_DIR/hosts.tsv" ]; then
    local_entry_count="$(awk -F'\t' '$2 ~ /\.local$/ { c++ } END { print c+0 }' "$RUN_DIR/hosts.tsv")"
    if [ "${local_entry_count:-0}" -gt 0 ]; then
        add_conflict \
            "hostname" \
            "low" \
            ".local hostnames may be intercepted by mDNS on macOS" \
            "/etc/hosts contains $local_entry_count \`.local\` mappings while mDNSResponder is active." \
            "macOS can prioritize mDNS for \`.local\` domains, so host-file mappings may not always win during lookup." \
            "scutil --dns | sed -n '1,200p'\n# prefer Local router-managed domains or use .test in stacks that support it." \
            "dscacheutil -q host -a name <your-domain.local>\n# confirm expected resolver behavior" \
            "scutil --dns | sed -n '1,120p'"
    fi
fi

emit_event "detect:conflicts" "$(printf '{"count":%d}' "$CONFLICT_COUNT")"

# ─── Run Verify If Requested (combined mode) ────────────────────────────────

VERIFY_SECTION=""
if [ -n "$VERIFY_DOMAIN" ]; then
    echo ""
    run_verify "$VERIFY_DOMAIN"
    VERIFY_SECTION="$(cat <<VEOF

---

## Hostname Verification: $VERIFY_DOMAIN

| Test | Status | Detail |
|------|--------|--------|
VEOF
)"
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        local_test="$(echo "$line" | sed -n 's/.*"test":"\([^"]*\)".*/\1/p')"
        local_status="$(echo "$line" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p')"
        local_detail="$(echo "$line" | sed -n 's/.*"detail":"\([^"]*\)".*/\1/p')"
        VERIFY_SECTION="${VERIFY_SECTION}
| ${local_test} | ${local_status} | ${local_detail} |"
    done <<< "$VERIFY_RESULTS"
    VERIFY_SECTION="${VERIFY_SECTION}

**Result:** ${VERIFY_PASS} passed, ${VERIFY_FAIL} failed"
fi

# ─── Report Generation ──────────────────────────────────────────────────────

build_priority_section() {
    if [ ! -s "$PRIORITY_FILE" ]; then
        cat <<'EOF'
1. **[No automatic fixes suggested]** — No high-confidence conflicts were auto-detected.

2. **[Manual validation]** — Review resolver and service sections above, then rerun the audit after any change.
EOF
        return
    fi

    sort -t $'\t' -k1,1nr "$PRIORITY_FILE" | awk -F'\t' '
        BEGIN { n=0 }
        {
            if (seen[$3]++) next
            n++
            printf "%d. **[%s]** — %s severity\n", n, $3, toupper(substr($2,1,1)) substr($2,2)
            printf "   ```bash\n   %s\n   ```\n\n", $4
            if (n >= 2) exit
        }
    '
}

if [ "$CONFLICT_COUNT" -eq 0 ]; then
    cat > "$CONFLICTS_FILE" <<'EOF'
No automatic conflicts detected by this run.

Manual checks still recommended:
- Verify the specific failing hostname resolves to the expected local IP.
- Re-run after reproducing the failure to capture transient port owners.
EOF
fi

if [ -s "$LISTENERS_MD_ROWS" ]; then
    LISTENER_ROWS_CONTENT="$(cat "$LISTENERS_MD_ROWS")"
else
    LISTENER_ROWS_CONTENT='| _(no listening TCP services found)_ |  |  |  |  |'
fi

if [ -s "$BREW_SERVICES_RAW" ]; then
    BREW_SERVICES_CONTENT="$(cat "$BREW_SERVICES_RAW")"
else
    BREW_SERVICES_CONTENT="(no data)"
fi

if [ -s "$LOCAL_SITES_SECTION" ]; then
    LOCAL_SITES_CONTENT="$(cat "$LOCAL_SITES_SECTION")"
else
    LOCAL_SITES_CONTENT="(no data)"
fi

if [ -s "$SERVICE_MANAGER_RAW" ]; then
    SERVICE_MANAGER_CONTENT="$(cat "$SERVICE_MANAGER_RAW")"
else
    SERVICE_MANAGER_CONTENT="(no matching services found)"
fi

if [ -s "$HOSTS_FILTERED" ]; then
    HOSTS_CONTENT="$(cat "$HOSTS_FILTERED")"
else
    HOSTS_CONTENT="(no data)"
fi

if [ -s "$DNS_RESOLVER_RAW" ]; then
    DNS_CONTENT="$(cat "$DNS_RESOLVER_RAW")"
else
    DNS_CONTENT="(no data)"
fi

if [ -s "$MDNS_STATUS_RAW" ]; then
    MDNS_CONTENT="$(cat "$MDNS_STATUS_RAW")"
else
    MDNS_CONTENT="(no data)"
fi

if [ -s "$LOCAL_RESOLUTION" ]; then
    RESOLUTION_CONTENT="$(cat "$LOCAL_RESOLUTION")"
else
    RESOLUTION_CONTENT="(no data)"
fi

PRIORITY_SECTION="$(build_priority_section)"

if [ -n "$PREVIOUS_SNAPSHOT" ]; then
    PREVIOUS_SNAPSHOT_VALUE="$PREVIOUS_SNAPSHOT"
else
    PREVIOUS_SNAPSHOT_VALUE="_(none provided)_"
fi

cat > "$OUTPUT_PATH" <<EOF
# Development Server & Port Conflict Audit

**Purpose:** Capture a baseline snapshot of your local development environment - running services, ports, hostnames, and DNS config - so you can diff against it when something breaks unexpectedly.

**Why a snapshot matters:** Services like Local WP, Homebrew daemons, and macOS mDNS can change state without user action - auto-updates, OS patches, background service restarts, or router config reloads. A baseline lets you quickly identify what changed when you get a hostname conflict error or port collision out of nowhere.

---

## Machine Information

| Field | Value |
|-------|-------|
| **Machine Type** | $(escape_md_cell "$MACHINE_TYPE") |
| **Machine Name** | $(escape_md_cell "$MACHINE_NAME") |
| **Primary User** | $(escape_md_cell "$PRIMARY_USER") |
| **OS Version** | $(escape_md_cell "$OS_VERSION") |
| **Snapshot Date** | $(escape_md_cell "$SNAPSHOT_DATE") |
| **Previous Snapshot** | $(escape_md_cell "$PREVIOUS_SNAPSHOT_VALUE") |
| **Focus Mode** | $(escape_md_cell "$FOCUS_MODE") |
| **Template Source** | $(escape_md_cell "$DEFAULT_TEMPLATE") |

---

## Changelog

### $(date '+%Y-%m-%d')
- **Automated snapshot**: Generated by \`servers-audit.sh\` with focus mode \`$FOCUS_MODE\`.

---

## Listening Services

| Process | PID | IP:Port | Manager | Notes |
|---------|-----|---------|---------|-------|
$LISTENER_ROWS_CONTENT

---

## DNS Configuration

### /etc/hosts Entries (*.local, *.test)

\`\`\`
$HOSTS_CONTENT
\`\`\`

### DNS Resolver Config

\`\`\`
$DNS_CONTENT
\`\`\`

### mDNS Status

\`\`\`
$MDNS_CONTENT
\`\`\`

### Local Domain Resolution Check

\`\`\`
$RESOLUTION_CONTENT
\`\`\`

---

## Service Managers

### Homebrew Services
\`\`\`
$BREW_SERVICES_CONTENT
\`\`\`

### Local WP Sites
\`\`\`
$LOCAL_SITES_CONTENT
\`\`\`

### launchd / systemd Services (web/db related)
\`\`\`
$SERVICE_MANAGER_CONTENT
\`\`\`

---

## Registry Locations

Where each tool keeps its config - useful for understanding why things conflict silently.

| Tool | Registry Location | Scope | Notes |
|------|-------------------|-------|-------|
| Local WP | \`~/Library/Application Support/Local/sites.json\` | \`.local\` domains, dynamic ports | Manages its own nginx/mysql per site |
| Homebrew | \`brew services list\` | System-wide daemons | Can auto-start on boot |
| Valet | \`~/.config/valet/\` | \`.test\` domains | Uses dnsmasq |
| /etc/hosts | \`/etc/hosts\` | Manual hostname overrides | Not cleaned up automatically |
| macOS mDNS | System-level | \`.local\` domain (RFC 6762) | Can intercept before /etc/hosts |

---

## Detected Conflicts

$(cat "$CONFLICTS_FILE")

## Priority Fixes

$PRIORITY_SECTION
$VERIFY_SECTION

---

## AI Agent Instructions

When asked to perform a server/port audit using this template:

1. Run \`servers-audit.sh\` with appropriate flags, or execute the equivalent commands manually if the script is not available.
2. Review the output for conflicts - especially ports 80, 443, 3306, 8080, and any Local WP dynamic ports.
3. Cross-reference \`/etc/hosts\` entries against currently running Local WP sites - orphaned entries from deleted sites are a common source of hostname conflicts.
4. Check whether Homebrew services (mysql, nginx, httpd, dnsmasq) overlap with Local WP's managed services.
5. Document findings in the "Detected Conflicts" section with root cause and fix.
6. If the user reports a specific error (e.g., "hostname conflict in Local WP"), focus the investigation on that symptom first before doing a full audit.
7. When diffing against a previous snapshot, highlight only what changed - don't re-document known state.

### Agent Orchestration Hooks

This script supports two mechanisms for AI agent integration:

- **\`--hook <script>\`**: Called as \`<script> <event-name> '<json-payload>'\` at each lifecycle stage. Return non-zero to abort.
- **\`--json-events\`**: Emits JSON-line events to fd 3 (or stderr). Pipe fd 3 to consume:
  \`\`\`bash
  servers-audit.sh --output audit.md --json-events 3> >(jq --unbuffered .)
  \`\`\`

**Event lifecycle:**
\`audit:start\` -> \`collect:listeners\` -> \`collect:hosts\` -> \`collect:dns\` -> \`collect:local-wp\` -> \`collect:services\` -> \`detect:conflicts\` -> [\`verify:start\` -> \`verify:test\`* -> \`verify:complete\`] -> \`report:written\` -> \`audit:complete\`

**Example hook script:**
\`\`\`bash
#!/bin/bash
# my-agent-hook.sh — called as: my-agent-hook.sh <event> <json>
event="\$1"; payload="\$2"
echo "[\$(date -u +%H:%M:%S)] \$event" >> /tmp/audit-events.log
case "\$event" in
  detect:conflicts)
    count=\$(echo "\$payload" | python3 -c "import sys,json; print(json.load(sys.stdin)['count'])")
    if [ "\$count" -gt 5 ]; then
      echo "ALERT: \$count conflicts detected" | mail -s "Audit Alert" admin@example.com
    fi
    ;;
esac
\`\`\`

---

## Resources

- **macOS DNS & mDNS:** https://developer.apple.com/library/archive/qa/qa1357/_index.html
- **RFC 6762 (mDNS):** https://tools.ietf.org/html/rfc6762
- **Local WP Documentation:** https://localwp.com/help-docs/
- **Laravel Valet:** https://laravel.com/docs/valet
- **Port audit command:** \`lsof -i -P -n | grep LISTEN\`

EOF

emit_event "report:written" "$(printf '{"output":"%s","runDir":"%s"}' \
    "$(json_escape "$OUTPUT_PATH")" "$(json_escape "$RUN_DIR")")"

cat > "$REPORT_JSON" <<EOF
{
  "runId": "$(json_escape "$RUN_ID")",
  "outputPath": "$(json_escape "$OUTPUT_PATH")",
  "runDir": "$(json_escape "$RUN_DIR")",
  "focusMode": "$(json_escape "$FOCUS_MODE")",
  "verifyDomain": "$(json_escape "$VERIFY_DOMAIN")",
  "snapshotDate": "$(json_escape "$SNAPSHOT_DATE")",
  "machine": {
    "type": "$(json_escape "$MACHINE_TYPE")",
    "name": "$(json_escape "$MACHINE_NAME")",
    "user": "$(json_escape "$PRIMARY_USER")",
    "osVersion": "$(json_escape "$OS_VERSION")"
  },
  "counts": {
    "localSiteDomains": $LOCAL_SITE_COUNT,
    "detectedConflicts": $CONFLICT_COUNT,
    "verifyPassed": $VERIFY_PASS,
    "verifyFailed": $VERIFY_FAIL
  },
  "artifacts": {
    "listenersTsv": "$(json_escape "$LISTENERS_TSV")",
    "hostsFiltered": "$(json_escape "$HOSTS_FILTERED")",
    "localResolution": "$(json_escape "$LOCAL_RESOLUTION")",
    "conflictsMarkdown": "$(json_escape "$CONFLICTS_FILE")",
    "priorityTsv": "$(json_escape "$PRIORITY_FILE")",
    "reportMarkdown": "$(json_escape "$OUTPUT_PATH")"
  }
}
EOF

emit_event "audit:complete" "$(printf '{"conflicts":%d,"verifyPassed":%d,"verifyFailed":%d}' \
    "$CONFLICT_COUNT" "$VERIFY_PASS" "$VERIFY_FAIL")"

echo "Wrote Markdown audit to: $OUTPUT_PATH"
echo "Wrote machine-readable report to: $REPORT_JSON"
