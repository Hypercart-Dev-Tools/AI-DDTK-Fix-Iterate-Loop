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

show_help() {
    cat <<'EOF'
AI-DDTK Experimental Development Server Audit

Captures a local machine baseline for hostname and port troubleshooting, then writes
a populated Markdown report based on experimental/servers.md.

Usage:
  experimental/servers-audit.sh --output <path> [options]

Required:
  --output <path>                Destination Markdown file

Options:
  --previous-snapshot <path>     Previous known-good snapshot path for reference
  --focus <full|hostname|port>   Prioritize specific conflict class in "Priority Fixes"
  --run-id <id>                  Override run id (default: timestamp)
  --run-dir <path>               Override artifact directory (default: temp/servers-audit/<run-id>)
  --dry-run                      Resolve configuration only; do not collect
  --help                         Show this help

Examples:
  experimental/servers-audit.sh --output ~/bin/servers-audit.md
  experimental/servers-audit.sh --output /tmp/servers-now.md --previous-snapshot ~/bin/servers-audit.md --focus hostname
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

while [ $# -gt 0 ]; do
    case "$1" in
        --output) OUTPUT_PATH="$2"; shift 2 ;;
        --previous-snapshot) PREVIOUS_SNAPSHOT="$2"; shift 2 ;;
        --focus) FOCUS_MODE="$2"; shift 2 ;;
        --run-id) RUN_ID="$2"; shift 2 ;;
        --run-dir) RUN_DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done

[ -n "$OUTPUT_PATH" ] || fail "--output is required"

case "$FOCUS_MODE" in
    full|hostname|port) ;;
    *) fail "--focus must be one of: full, hostname, port" ;;
esac

LSOF_BIN="$(resolve_tool "$LSOF_BIN" lsof)"
BREW_BIN="$(resolve_tool "$BREW_BIN" brew)"
LOCAL_WP_BIN="$(resolve_tool "$LOCAL_WP_BIN" local-wp)"
PYTHON_BIN="$(resolve_tool "$PYTHON_BIN" python3)"

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
LSOF_BIN=${LSOF_BIN:-missing}
BREW_BIN=${BREW_BIN:-missing}
LOCAL_WP_BIN=${LOCAL_WP_BIN:-missing}
PYTHON_BIN=${PYTHON_BIN:-missing}
LOCAL_SITES_JSON=$LOCAL_SITES_JSON
TEMPLATE=$DEFAULT_TEMPLATE
EOF
    exit 0
fi

MACHINE_TYPE="$(uname -m 2>/dev/null || echo unknown)"
MACHINE_NAME="$(scutil --get ComputerName 2>/dev/null || hostname 2>/dev/null || echo unknown)"
PRIMARY_USER="$(id -un 2>/dev/null || echo unknown)"
if [ "$(uname -s)" = "Darwin" ] && command -v sw_vers >/dev/null 2>&1; then
    OS_VERSION="$(sw_vers -productName 2>/dev/null || true) $(sw_vers -productVersion 2>/dev/null || true)"
else
    OS_VERSION="$(uname -sr 2>/dev/null || echo unknown)"
fi
SNAPSHOT_DATE="$(date '+%Y-%m-%d %H:%M:%S %Z')"

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

if [ -f /etc/hosts ]; then
    awk '
        /^[[:space:]]*#/ { next }
        NF < 2 { next }
        {
            ip=$1
            for (i=2; i<=NF; i++) {
                host=$i
                sub(/#.*/, "", host)
                if (host ~ /\.(local|test)$/) {
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

if [ "$(uname -s)" = "Darwin" ] && command -v scutil >/dev/null 2>&1; then
    scutil --dns > "$DNS_RESOLVER_RAW" 2>&1 || true
else
    if [ -f /etc/resolv.conf ]; then
        cat /etc/resolv.conf > "$DNS_RESOLVER_RAW"
    else
        echo "No resolver details available on this host." > "$DNS_RESOLVER_RAW"
    fi
fi

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

if [ "$(uname -s)" = "Darwin" ]; then
    launchctl list 2>/dev/null | grep -Ei 'nginx|httpd|apache|mysql|mariadb|dnsmasq|postgres|php|caddy|local' > "$SERVICE_MANAGER_RAW" || true
else
    if command -v systemctl >/dev/null 2>&1; then
        systemctl list-units --type=service --all 2>/dev/null | grep -Ei 'nginx|httpd|apache|mysql|mariadb|dnsmasq|postgres|php|caddy|avahi' > "$SERVICE_MANAGER_RAW" || true
    else
        echo "No launchd/systemd service manager data available." > "$SERVICE_MANAGER_RAW"
    fi
fi

# Conflict detection: port ownership collisions (different service signatures on same port).
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

# Conflict detection: key infrastructure ports with non-Local ownership.
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

# Conflict detection: duplicate hosts entries for same hostname with different IPs.
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

# Conflict detection: stale .local hosts entries not present in Local WP sites.json domains.
if [ -s "$HOSTS_DOMAINS" ] && [ -s "$LOCAL_DOMAINS" ]; then
    awk '/\.local$/ { print }' "$HOSTS_DOMAINS" | sort -u > "$RUN_DIR/hosts-local-only.txt"
    sort -u "$LOCAL_DOMAINS" > "$RUN_DIR/local-domains-sorted.txt"
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
    ' "$RUN_DIR/local-domains-sorted.txt" "$RUN_DIR/hosts-local-only.txt" > "$RUN_DIR/stale-local-hosts.txt"
    stale_count="$(wc -l < "$RUN_DIR/stale-local-hosts.txt" | tr -d ' ')"
    if [ "${stale_count:-0}" -gt 0 ]; then
        stale_preview="$(head -n 20 "$RUN_DIR/stale-local-hosts.txt" | sed 's/^/- /')"
        add_conflict \
            "hostname" \
            "medium" \
            "Potential stale Local hostnames in /etc/hosts" \
            "These \`.local\` entries do not match current Local WP domains:\n$stale_preview" \
            "Old host entries from deleted/renamed Local sites can hijack name resolution and trigger hostname conflicts." \
            "cat \"$RUN_DIR/stale-local-hosts.txt\"\n# remove stale lines from /etc/hosts after confirming site retirement." \
            "grep -Ff \"$RUN_DIR/stale-local-hosts.txt\" /etc/hosts || true" \
            "cat \"$RUN_DIR/stale-local-hosts.txt\""
    fi
fi

# Conflict detection: unresolved Local domains (likely "lost hostname" symptom).
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

# Conflict detection: .local entries with macOS mDNS precedence caveat.
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
- **Automated snapshot**: Generated by \`experimental/servers-audit.sh\` with focus mode \`$FOCUS_MODE\`.

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

---

## AI Agent Instructions

When asked to perform a server/port audit using this template:

1. Run \`experimental/servers-audit.sh\` with appropriate flags, or execute the equivalent commands manually if the script is not available.
2. Review the output for conflicts - especially ports 80, 443, 3306, 8080, and any Local WP dynamic ports.
3. Cross-reference \`/etc/hosts\` entries against currently running Local WP sites - orphaned entries from deleted sites are a common source of hostname conflicts.
4. Check whether Homebrew services (mysql, nginx, httpd, dnsmasq) overlap with Local WP's managed services.
5. For each detected conflict, propose concrete command(s) to fix it (not just generic guidance), and include a risk note if the fix is disruptive.
6. Offer to execute fix commands for the user; request explicit permission before privileged or destructive actions (for example editing \`/etc/hosts\`, stopping services, or using \`sudo\`).
7. After each accepted fix, re-run the audit to verify whether the conflict is resolved (fix-iterate loop).
8. Diff the new snapshot against the previous snapshot and report only the delta tied to the fix.
9. If the user reports a specific error (e.g., "hostname conflict in Local WP"), focus investigation and fixes on that symptom first before full-environment cleanup.
10. Stop after 5 failed fix iterations (or 10 total loops) and clearly report the blocker.

---

## Resources

- **macOS DNS & mDNS:** https://developer.apple.com/library/archive/qa/qa1357/_index.html
- **RFC 6762 (mDNS):** https://tools.ietf.org/html/rfc6762
- **Local WP Documentation:** https://localwp.com/help-docs/
- **Laravel Valet:** https://laravel.com/docs/valet
- **Port audit command:** \`lsof -i -P -n | grep LISTEN\`

EOF

cat > "$REPORT_JSON" <<EOF
{
  "runId": "$(json_escape "$RUN_ID")",
  "outputPath": "$(json_escape "$OUTPUT_PATH")",
  "runDir": "$(json_escape "$RUN_DIR")",
  "focusMode": "$(json_escape "$FOCUS_MODE")",
  "snapshotDate": "$(json_escape "$SNAPSHOT_DATE")",
  "machine": {
    "type": "$(json_escape "$MACHINE_TYPE")",
    "name": "$(json_escape "$MACHINE_NAME")",
    "user": "$(json_escape "$PRIMARY_USER")",
    "osVersion": "$(json_escape "$OS_VERSION")"
  },
  "counts": {
    "localSiteDomains": $LOCAL_SITE_COUNT,
    "detectedConflicts": $CONFLICT_COUNT
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

echo "Wrote Markdown audit to: $OUTPUT_PATH"
echo "Wrote machine-readable report to: $REPORT_JSON"
