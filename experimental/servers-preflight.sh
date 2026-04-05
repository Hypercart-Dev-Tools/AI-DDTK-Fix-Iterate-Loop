#!/usr/bin/env bash

set -euo pipefail

# ─── servers-preflight.sh ────────────────────────────────────────────────────
#
# Agent-agnostic preflight router for local server configuration changes.
#
# Any AI agent (Claude Code, Copilot, Cursor, Windsurf, custom) or human
# operator runs this BEFORE making server config changes. The script reads
# servers.md as the source of truth, evaluates the proposed intent, and
# returns a structured verdict: ALLOW, WARN, or BLOCK.
#
# Three use cases:
#   1. Adding a new server/service/site
#   2. Updating an existing server's config
#   3. Debugging a conflict that slipped past initial setup
#
# Integration examples (agent-agnostic):
#
#   # Claude Code hook (settings.json pre_tool_call)
#   servers-preflight.sh --intent add --service nginx --port 8080
#
#   # Copilot / Cursor / any agent — call before executing
#   result=$(servers-preflight.sh --intent add --domain mysite.local --port 443 --json)
#
#   # Human operator
#   servers-preflight.sh --intent debug --port 3306
#
#   # Pipe-friendly: accept intent as JSON on stdin
#   echo '{"intent":"add","service":"postgres","port":5433}' | servers-preflight.sh --stdin
#
# Exit codes:
#   0 = ALLOW  (no conflicts, safe to proceed)
#   1 = BLOCK  (hard conflict, must resolve first)
#   2 = WARN   (soft conflicts, proceed with caution)
#   3 = ERROR  (bad input or missing snapshot)
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNAPSHOT_PATH="${SERVERS_SNAPSHOT:-$SCRIPT_DIR/servers.md}"

INTENT=""          # add | update | debug
SERVICE=""         # nginx, mysql, postgres, httpd, node, python, etc.
DOMAIN=""          # e.g. mysite.local
PORT=""            # e.g. 8080
MANAGER=""         # homebrew, local-wp, docker, manual, etc.
HOST_ENTRY=""      # IP to bind or add to /etc/hosts (e.g. 127.0.0.1)
DESCRIPTION=""     # free-text description of what the agent is about to do
JSON_OUTPUT=0      # --json flag for structured output
STDIN_MODE=0       # --stdin flag to read JSON intent from stdin
QUIET=0            # --quiet flag for minimal output
LIVE_CHECK=0       # --live flag to also check live port state via lsof

# Colors (disabled when --json or piped)
if [ -t 1 ] && [ "$JSON_OUTPUT" -eq 0 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN='' RED='' YELLOW='' CYAN='' BOLD='' NC=''
fi

# ─── Helpers ─────────────────────────────────────────────────────────────────

fail() {
    if [ "$JSON_OUTPUT" -eq 1 ]; then
        printf '{"verdict":"ERROR","message":"%s","findings":[]}\n' "$(json_esc "$*")"
    else
        echo "Error: $*" >&2
    fi
    exit 3
}

json_esc() {
    local val="$1"
    val="${val//\\/\\\\}"
    val="${val//\"/\\\"}"
    val="${val//$'\t'/\\t}"
    val="${val//$'\n'/\\n}"
    val="${val//$'\r'/\\r}"
    printf '%s' "$val"
}

to_lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

show_help() {
    cat <<'EOF'
servers-preflight.sh — Pre-flight check for local server config changes

Usage:
  servers-preflight.sh --intent <add|update|debug> [options]
  echo '{"intent":"add",...}' | servers-preflight.sh --stdin

Intents:
  add       Adding a new server, service, site, or host entry
  update    Changing config on an existing service (port, domain, etc.)
  debug     Investigating a conflict or connectivity issue

Options:
  --service <name>        Service name (nginx, mysql, postgres, node, python, etc.)
  --domain <domain>       Domain name (e.g. mysite.local, app.test)
  --port <number>         Port number to check
  --manager <name>        Service manager (homebrew, local-wp, docker, manual)
  --host-entry <ip>       IP address for /etc/hosts binding
  --description <text>    Free-text description of the planned change
  --snapshot <path>       Path to servers.md (default: $SCRIPT_DIR/servers.md
                          or $SERVERS_SNAPSHOT env var)
  --live                  Also check live port state via lsof (slower but current)
  --json                  Output structured JSON (for agent consumption)
  --quiet                 Minimal output (just verdict + exit code)
  --stdin                 Read intent as JSON from stdin
  --help                  Show this help

Exit Codes:
  0 = ALLOW    No conflicts found, safe to proceed
  1 = BLOCK    Hard conflict — must resolve before proceeding
  2 = WARN     Soft conflict — can proceed with caution
  3 = ERROR    Bad input, missing snapshot, or usage error

Examples:
  # Adding a new Local WP site
  servers-preflight.sh --intent add --domain newsite.local --port 10060 --manager local-wp

  # Starting a dev server on port 8080
  servers-preflight.sh --intent add --service node --port 8080 --description "Next.js dev server"

  # Changing postgres port
  servers-preflight.sh --intent update --service postgres --port 5433

  # Debugging why port 3306 is conflicting
  servers-preflight.sh --intent debug --port 3306 --live

  # Agent integration (JSON in, JSON out)
  echo '{"intent":"add","service":"nginx","port":80}' | servers-preflight.sh --stdin --json

  # Pipe into any agent's decision loop
  verdict=$(servers-preflight.sh --intent add --port 9248 --json | jq -r .verdict)
  if [ "$verdict" = "ALLOW" ]; then echo "Safe to start"; fi
EOF
}

# ─── Parse Arguments ─────────────────────────────────────────────────────────

while [ $# -gt 0 ]; do
    case "$1" in
        --intent) INTENT="$2"; shift 2 ;;
        --service) SERVICE="$2"; shift 2 ;;
        --domain) DOMAIN="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --manager) MANAGER="$2"; shift 2 ;;
        --host-entry) HOST_ENTRY="$2"; shift 2 ;;
        --description) DESCRIPTION="$2"; shift 2 ;;
        --snapshot) SNAPSHOT_PATH="$2"; shift 2 ;;
        --live) LIVE_CHECK=1; shift ;;
        --json) JSON_OUTPUT=1; shift ;;
        --quiet) QUIET=1; shift ;;
        --stdin) STDIN_MODE=1; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done

# Reset colors after parsing (--json may have been set)
if [ "$JSON_OUTPUT" -eq 1 ] || ! [ -t 1 ]; then
    GREEN='' RED='' YELLOW='' CYAN='' BOLD='' NC=''
fi

# ─── Stdin JSON Mode ─────────────────────────────────────────────────────────

if [ "$STDIN_MODE" -eq 1 ]; then
    if ! command -v python3 >/dev/null 2>&1; then
        fail "--stdin requires python3 for JSON parsing"
    fi
    stdin_json="$(cat)"
    eval "$(python3 -c "
import json, sys, shlex
d = json.loads(sys.stdin.read())
for k in ('intent','service','domain','port','manager','host_entry','description'):
    v = str(d.get(k, d.get(k.replace('_','-'), ''))).strip()
    if v and v != 'None':
        print(f'{k.upper().replace(\"-\",\"_\")}={shlex.quote(v)}')
" <<< "$stdin_json")"
    # Map host_entry
    HOST_ENTRY="${HOST_ENTRY:-}"
fi

# ─── Validate Input ──────────────────────────────────────────────────────────

[ -n "$INTENT" ] || fail "Missing --intent (add, update, or debug)"

case "$INTENT" in
    add|update|debug) ;;
    *) fail "--intent must be one of: add, update, debug" ;;
esac

if [ "$INTENT" != "debug" ] && [ -z "$PORT" ] && [ -z "$DOMAIN" ] && [ -z "$SERVICE" ]; then
    fail "At least one of --port, --domain, or --service is required for intent '$INTENT'"
fi

[ -f "$SNAPSHOT_PATH" ] || fail "Snapshot not found: $SNAPSHOT_PATH (run servers-audit.sh first, or set --snapshot / \$SERVERS_SNAPSHOT)"

# ─── Read Snapshot ────────────────────────────────────────────────────────────

SNAPSHOT_CONTENT="$(cat "$SNAPSHOT_PATH")"

# Extract sections we need for checks
extract_section() {
    local header="$1"
    # Pull content between this header and the next ## header or end of file
    printf '%s\n' "$SNAPSHOT_CONTENT" | awk -v h="$header" '
        $0 ~ "^##+ " h { found=1; next }
        found && /^##+ / { exit }
        found { print }
    '
}

LISTENERS_SECTION="$(extract_section "Listening Services")"
HOSTS_SECTION="$(extract_section "/etc/hosts Entries")"
BREW_SECTION="$(extract_section "Homebrew Services")"
LOCAL_WP_SECTION="$(extract_section "Local WP Sites")"
CONFLICTS_SECTION="$(extract_section "Detected Conflicts")"
DNS_SECTION="$(extract_section "DNS Resolver Config")"

# ─── Findings Engine ─────────────────────────────────────────────────────────

# Findings accumulate as: SEVERITY␞CATEGORY␞MESSAGE (using ASCII RS as delimiter)
# SEVERITY: block, warn, info
FINDINGS=""
FINDING_DELIM=$'\x1e'  # ASCII Record Separator — won't appear in messages
BLOCK_COUNT=0
WARN_COUNT=0
INFO_COUNT=0

add_finding() {
    local severity="$1"
    local category="$2"
    local message="$3"

    FINDINGS="${FINDINGS}${severity}${FINDING_DELIM}${category}${FINDING_DELIM}${message}"$'\n'

    case "$severity" in
        block) BLOCK_COUNT=$((BLOCK_COUNT + 1)) ;;
        warn) WARN_COUNT=$((WARN_COUNT + 1)) ;;
        info) INFO_COUNT=$((INFO_COUNT + 1)) ;;
    esac
}

# ─── Port Checks ─────────────────────────────────────────────────────────────

check_port() {
    local target_port="$1"
    [ -n "$target_port" ] || return 0

    # Check snapshot for existing listeners on this port
    local snapshot_owners
    snapshot_owners="$(printf '%s\n' "$LISTENERS_SECTION" | awk -F'|' -v p="$target_port" '
        NF >= 5 {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4)  # IP:Port column
            if ($4 ~ ":" p "$" || $4 ~ ":" p "[[:space:]]") {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)  # Process
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $5)  # Manager
                if ($2 != "" && $2 !~ /^[-_]+$/) {
                    print $2 " (" $5 ")"
                }
            }
        }
    ' | sort -u)"

    if [ -n "$snapshot_owners" ]; then
        local owner_list
        owner_list="$(echo "$snapshot_owners" | tr '\n' ', ' | sed 's/, $//')"

        # Critical ports are always a block
        case "$target_port" in
            80|443)
                add_finding "block" "port" "Port $target_port is already bound by: $owner_list. Ports 80/443 are critical for Local WP router."
                ;;
            3306|5432)
                add_finding "block" "port" "Port $target_port is already bound by: $owner_list. Database port collision will cause connection failures."
                ;;
            *)
                if [ "$INTENT" = "add" ]; then
                    add_finding "warn" "port" "Port $target_port is already in use by: $owner_list. Choose a different port or stop the existing service first."
                else
                    add_finding "info" "port" "Port $target_port is currently used by: $owner_list."
                fi
                ;;
        esac
    else
        add_finding "info" "port" "Port $target_port is not claimed in the last snapshot."
    fi

    # Check Local WP dynamic port ranges
    if [ "$target_port" -ge 10000 ] && [ "$target_port" -le 19999 ] 2>/dev/null; then
        if [ "$(to_lower "${MANAGER:-}")" != "local-wp" ] && [ "$(to_lower "${MANAGER:-}")" != "local wp" ]; then
            add_finding "warn" "port" "Port $target_port is in the Local WP dynamic range (10000-19999). Non-Local services here risk collision with site startups."
        fi
    fi

    # Live check if requested
    if [ "$LIVE_CHECK" -eq 1 ] && command -v lsof >/dev/null 2>&1; then
        local live_owners
        live_owners="$(lsof -nP -iTCP:"$target_port" -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {printf "%s (pid %s) ", $1, $2}' || true)"
        if [ -n "$live_owners" ]; then
            add_finding "warn" "port-live" "LIVE CHECK: Port $target_port is actively bound right now by: $live_owners"
        else
            add_finding "info" "port-live" "LIVE CHECK: Port $target_port is not currently bound."
        fi
    fi
}

# ─── Domain Checks ───────────────────────────────────────────────────────────

check_domain() {
    local target_domain="$1"
    [ -n "$target_domain" ] || return 0

    local lower_domain
    lower_domain="$(to_lower "$target_domain")"

    # Check if domain already exists in Local WP sites
    local existing_site
    existing_site="$(printf '%s\n' "$LOCAL_WP_SECTION" | grep -i "domain=${lower_domain}" || true)"
    if [ -n "$existing_site" ]; then
        if [ "$INTENT" = "add" ]; then
            add_finding "block" "domain" "Domain '$target_domain' already exists as a Local WP site: $(echo "$existing_site" | sed 's/^- //' | head -1)"
        else
            add_finding "info" "domain" "Domain '$target_domain' is registered as a Local WP site."
        fi
    fi

    # Check if domain is an active Valet site
    if command -v valet >/dev/null 2>&1; then
        local valet_links
        valet_links="$(valet links 2>/dev/null | awk '{print $1}' | grep -i "^${lower_domain}$" || true)"
        if [ -n "$valet_links" ]; then
            if [ "$INTENT" = "add" ]; then
                add_finding "block" "domain" "Domain '$target_domain' already exists as a Valet site. Use 'valet unlink' to remove it first."
            else
                add_finding "info" "domain" "Domain '$target_domain' is registered as a Valet site."
            fi
            return 0
        fi
    fi

    # Check /etc/hosts for existing entries
    local hosts_match
    hosts_match="$(printf '%s\n' "$HOSTS_SECTION" | grep -i "$lower_domain" || true)"
    if [ -n "$hosts_match" ]; then
        local ip_count
        ip_count="$(printf '%s\n' "$hosts_match" | awk '{print $1}' | sort -u | wc -l | tr -d ' ')"

        # Exclude normal dual-stack (127.0.0.1 + ::1)
        local unique_ips
        unique_ips="$(printf '%s\n' "$hosts_match" | awk '{print $1}' | sort -u | grep -v '::1' | grep -v '127.0.0.1' || true)"

        if [ -n "$unique_ips" ]; then
            add_finding "warn" "domain" "Domain '$target_domain' has non-standard IP mappings in /etc/hosts: $(echo "$unique_ips" | tr '\n' ', ' | sed 's/, $//')"
        elif [ "$INTENT" = "add" ]; then
            add_finding "info" "domain" "Domain '$target_domain' already has /etc/hosts entries (127.0.0.1 + ::1). No new entries needed."
        fi
    elif [ "$INTENT" = "add" ]; then
        add_finding "info" "domain" "Domain '$target_domain' has no /etc/hosts entries yet. You'll need to add them or ensure Local WP router handles it."
    fi

    # Check .local mDNS caveat on macOS
    if [ "$(uname -s)" = "Darwin" ] && echo "$lower_domain" | grep -q '\.local$'; then
        add_finding "warn" "domain" "Domain '$target_domain' uses .local TLD on macOS. mDNSResponder may intercept resolution before /etc/hosts. Consider .test if possible."
    fi
}

# ─── Service Checks ──────────────────────────────────────────────────────────

check_service() {
    local target_service="$1"
    [ -n "$target_service" ] || return 0

    local lower_service
    lower_service="$(to_lower "$target_service")"

    # Check Homebrew services for conflicts
    local brew_match
    brew_match="$(printf '%s\n' "$BREW_SECTION" | grep -i "^${lower_service}" || true)"
    if [ -n "$brew_match" ]; then
        if echo "$brew_match" | grep -qi "started"; then
            add_finding "warn" "service" "Homebrew service '$target_service' is currently running. Starting another instance may cause port conflicts."
        else
            add_finding "info" "service" "Homebrew service '$target_service' exists but is not running."
        fi
    fi

    # Check for known service-to-port mappings and warn about defaults
    case "$lower_service" in
        nginx|httpd|apache)
            if [ -z "$PORT" ] || [ "$PORT" = "80" ] || [ "$PORT" = "443" ]; then
                local web_listeners
                web_listeners="$(printf '%s\n' "$LISTENERS_SECTION" | grep -Ei 'nginx|httpd|apache' | head -3 || true)"
                if [ -n "$web_listeners" ]; then
                    add_finding "warn" "service" "Web server processes already in listener table. Verify port won't collide: $web_listeners"
                fi
            fi
            ;;
        mysql|mysqld|mariadb)
            local mysql_listeners
            mysql_listeners="$(printf '%s\n' "$LISTENERS_SECTION" | grep -i 'mysql' | head -3 || true)"
            if [ -n "$mysql_listeners" ]; then
                add_finding "warn" "service" "MySQL/MariaDB processes already running. Check port ownership carefully."
            fi
            ;;
        postgres|postgresql)
            local pg_listeners
            pg_listeners="$(printf '%s\n' "$LISTENERS_SECTION" | grep -i 'postgres' | head -3 || true)"
            if [ -n "$pg_listeners" ]; then
                add_finding "warn" "service" "PostgreSQL processes already running. Default port 5432 may conflict."
            fi
            ;;
        node|python|uvicorn|gunicorn|fastapi)
            add_finding "info" "service" "App server '$target_service' — ensure the port doesn't overlap with existing services."
            ;;
    esac
}

# ─── Manager Checks ──────────────────────────────────────────────────────────

check_manager_conflicts() {
    local target_manager="$1"
    [ -n "$target_manager" ] || return 0

    local lower_manager
    lower_manager="$(to_lower "$target_manager")"

    # Warn about known inter-manager conflicts
    case "$lower_manager" in
        homebrew)
            local local_wp_running
            local_wp_running="$(printf '%s\n' "$LISTENERS_SECTION" | grep -c "Local WP" || true)"
            if [ "$local_wp_running" -gt 0 ]; then
                local lower_svc
                lower_svc="$(to_lower "${SERVICE:-}")"
                case "$lower_svc" in
                    nginx|mysql|mysqld|php)
                        add_finding "warn" "manager" "Homebrew '$SERVICE' can conflict with Local WP's managed $SERVICE instances. Local WP runs its own per-site $SERVICE."
                        ;;
                esac
            fi
            ;;
        local-wp|localwp)
            local brew_running
            brew_running="$(printf '%s\n' "$BREW_SECTION" | grep -ci "started" || true)"
            if [ "$brew_running" -gt 0 ]; then
                add_finding "info" "manager" "Homebrew has $brew_running running services. Check that Local WP's dynamic ports don't overlap."
            fi
            ;;
        docker)
            add_finding "info" "manager" "Docker networking is isolated but published ports can still collide with host services."
            ;;
    esac
}

# ─── Existing Conflicts Check ────────────────────────────────────────────────

check_existing_conflicts() {
    local conflict_count
    conflict_count="$(printf '%s\n' "$CONFLICTS_SECTION" | grep -c "^### Conflict" || true)"

    if [ "$conflict_count" -gt 0 ]; then
        add_finding "warn" "existing" "Snapshot already has $conflict_count unresolved conflict(s). Review 'Detected Conflicts' section in servers.md before adding more services."
    fi
}

# ─── Debug Mode ───────────────────────────────────────────────────────────────

run_debug() {
    # In debug mode, gather as much info as possible about the target
    add_finding "info" "debug" "Running diagnostic preflight for debug intent."

    if [ -n "$PORT" ]; then
        check_port "$PORT"
        # Find all services in snapshot using this port
        local related
        related="$(printf '%s\n' "$LISTENERS_SECTION" | awk -F'|' -v p="$PORT" '
            NF >= 5 {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", $4)
                if ($4 ~ ":" p "$" || $4 ~ ":" p "[[:space:]]") print $0
            }
        ')"
        if [ -n "$related" ]; then
            add_finding "info" "debug" "Snapshot listener entries for port $PORT: $(echo "$related" | tr '\n' '; ')"
        fi
    fi

    if [ -n "$DOMAIN" ]; then
        check_domain "$DOMAIN"
        # Check DNS resolution section
        local resolution
        resolution="$(extract_section "Local Domain Resolution Check" | grep -i "$DOMAIN" || true)"
        if [ -n "$resolution" ]; then
            add_finding "info" "debug" "Resolution state: $resolution"
        fi
    fi

    if [ -n "$SERVICE" ]; then
        check_service "$SERVICE"
    fi

    check_existing_conflicts
}

# ─── Execute Checks ──────────────────────────────────────────────────────────

case "$INTENT" in
    add)
        [ -n "$PORT" ] && check_port "$PORT"
        [ -n "$DOMAIN" ] && check_domain "$DOMAIN"
        [ -n "$SERVICE" ] && check_service "$SERVICE"
        [ -n "$MANAGER" ] && check_manager_conflicts "$MANAGER"
        check_existing_conflicts
        ;;
    update)
        [ -n "$PORT" ] && check_port "$PORT"
        [ -n "$DOMAIN" ] && check_domain "$DOMAIN"
        [ -n "$SERVICE" ] && check_service "$SERVICE"
        [ -n "$MANAGER" ] && check_manager_conflicts "$MANAGER"
        check_existing_conflicts
        ;;
    debug)
        run_debug
        ;;
esac

# ─── Determine Verdict ───────────────────────────────────────────────────────

VERDICT="ALLOW"
EXIT_CODE=0

if [ "$BLOCK_COUNT" -gt 0 ]; then
    VERDICT="BLOCK"
    EXIT_CODE=1
elif [ "$WARN_COUNT" -gt 0 ]; then
    VERDICT="WARN"
    EXIT_CODE=2
fi

# ─── Output ──────────────────────────────────────────────────────────────────

if [ "$JSON_OUTPUT" -eq 1 ]; then
    # Build findings JSON array
    findings_json="["
    first=1
    while IFS="$FINDING_DELIM" read -r sev cat msg; do
        [ -n "$sev" ] || continue
        [ "$first" -eq 1 ] && first=0 || findings_json="${findings_json},"
        findings_json="${findings_json}{\"severity\":\"$sev\",\"category\":\"$(json_esc "$cat")\",\"message\":\"$(json_esc "$msg")\"}"
    done <<< "$FINDINGS"
    findings_json="${findings_json}]"

    cat <<EOF
{
  "verdict": "$VERDICT",
  "intent": "$INTENT",
  "target": {
    "service": "$(json_esc "$SERVICE")",
    "domain": "$(json_esc "$DOMAIN")",
    "port": "$(json_esc "$PORT")",
    "manager": "$(json_esc "$MANAGER")",
    "description": "$(json_esc "$DESCRIPTION")"
  },
  "counts": {
    "block": $BLOCK_COUNT,
    "warn": $WARN_COUNT,
    "info": $INFO_COUNT
  },
  "snapshot": "$(json_esc "$SNAPSHOT_PATH")",
  "findings": $findings_json
}
EOF

elif [ "$QUIET" -eq 1 ]; then
    echo "$VERDICT"

else
    # Human-readable output
    echo ""
    case "$VERDICT" in
        ALLOW)
            echo -e "${GREEN}${BOLD}╔══════════════════════════════════════╗${NC}"
            echo -e "${GREEN}${BOLD}║         PREFLIGHT: ALLOW             ║${NC}"
            echo -e "${GREEN}${BOLD}╚══════════════════════════════════════╝${NC}"
            ;;
        WARN)
            echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════╗${NC}"
            echo -e "${YELLOW}${BOLD}║         PREFLIGHT: WARN              ║${NC}"
            echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════╝${NC}"
            ;;
        BLOCK)
            echo -e "${RED}${BOLD}╔══════════════════════════════════════╗${NC}"
            echo -e "${RED}${BOLD}║         PREFLIGHT: BLOCK             ║${NC}"
            echo -e "${RED}${BOLD}╚══════════════════════════════════════╝${NC}"
            ;;
    esac
    echo ""
    echo -e "${CYAN}Intent:${NC}  $INTENT"
    [ -n "$SERVICE" ] && echo -e "${CYAN}Service:${NC} $SERVICE"
    [ -n "$DOMAIN" ] && echo -e "${CYAN}Domain:${NC}  $DOMAIN"
    [ -n "$PORT" ] && echo -e "${CYAN}Port:${NC}    $PORT"
    [ -n "$MANAGER" ] && echo -e "${CYAN}Manager:${NC} $MANAGER"
    [ -n "$DESCRIPTION" ] && echo -e "${CYAN}Action:${NC}  $DESCRIPTION"
    echo ""

    if [ -n "$FINDINGS" ]; then
        echo -e "${BOLD}Findings:${NC}"
        echo ""
        while IFS="$FINDING_DELIM" read -r sev cat msg; do
            [ -n "$sev" ] || continue
            case "$sev" in
                block) echo -e "  ${RED}■ BLOCK${NC} [$cat] $msg" ;;
                warn)  echo -e "  ${YELLOW}▲ WARN${NC}  [$cat] $msg" ;;
                info)  echo -e "  ${GREEN}● INFO${NC}  [$cat] $msg" ;;
            esac
        done <<< "$FINDINGS"
        echo ""
    fi

    echo -e "${CYAN}Snapshot:${NC} $SNAPSHOT_PATH"

    if [ "$VERDICT" = "BLOCK" ]; then
        echo ""
        echo -e "${RED}${BOLD}Action required:${NC} Resolve the conflicts above before proceeding."
        echo -e "Run ${BOLD}servers-audit.sh${NC} to refresh the snapshot after fixing."
    elif [ "$VERDICT" = "WARN" ]; then
        echo ""
        echo -e "${YELLOW}Proceed with caution.${NC} Review warnings above."
        echo -e "Run ${BOLD}servers-audit.sh${NC} after changes to update the snapshot."
    else
        echo ""
        echo -e "${GREEN}Safe to proceed.${NC} Run ${BOLD}servers-audit.sh${NC} after changes to update the snapshot."
    fi
    echo ""
fi

exit $EXIT_CODE
