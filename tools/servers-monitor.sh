#!/bin/bash
# servers-monitor.sh — Conflict-free local development monitor
# Runs every 30 min via LaunchAgent. Emails alerts via Resend.com only when issues found.
# Config: ~/secrets/servers-monitor.conf (never committed)
# Compatible with macOS bash 3.2 (no associative arrays).
#
# Dedup strategy: hashes the full issue set. If the hash matches the last alert,
# no email is sent — even across days. Only emails when the baseline CHANGES.
#
# Modes:
#   servers-monitor.sh            Normal mode — email on baseline change
#   servers-monitor.sh --json     Emit structured JSON to stdout, skip email,
#                                 skip baseline update (safe for MCP callers)
set -euo pipefail

# --- Parse args ---
JSON_MODE=0
for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE=1 ;;
    -h|--help)
      sed -n '2,14p' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# --- Config ---
CONF_FILE="${SERVERS_MONITOR_CONF:-$HOME/secrets/servers-monitor.conf}"
STATE_FILE="${SERVERS_MONITOR_STATE_FILE:-/tmp/servers-monitor-last-alert.state}"
HASH_FILE="${SERVERS_MONITOR_HASH_FILE:-/tmp/servers-monitor-baseline.hash}"
LOCK_DIR="${SERVERS_MONITOR_LOCK_DIR:-/tmp/servers-monitor.lock}"
LOCK_STALE_SECONDS="${SERVERS_MONITOR_LOCK_STALE_SECONDS:-600}"
COMMAND_TIMEOUT_SECONDS="${SERVERS_MONITOR_COMMAND_TIMEOUT_SECONDS:-15}"
EMAIL_TIMEOUT_SECONDS="${SERVERS_MONITOR_EMAIL_TIMEOUT_SECONDS:-20}"
LOCAL_WP_SITES_JSON="${SERVERS_MONITOR_LOCAL_WP_SITES_JSON:-$HOME/Library/Application Support/Local/sites.json}"

# JSON mode tolerates a missing config — callers (MCP tools) only need the checks.
if [[ ! -f "$CONF_FILE" ]]; then
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '{"status":"not_configured","message":"Config not found at %s","configPath":"%s"}\n' \
      "$CONF_FILE" "$CONF_FILE"
    exit 0
  fi
  echo "ERROR: Config not found at $CONF_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$CONF_FILE"

# In email mode, require all config vars. In JSON mode, skip the check —
# we only need the monitoring logic, not email delivery.
if [[ "$JSON_MODE" -eq 0 ]]; then
  for var in RESEND_API_KEY FROM_EMAIL TO_EMAIL DEVICE_NAME; do
    eval "val=\${$var:-}"
    if [[ -z "$val" ]]; then
      echo "ERROR: $var not set in $CONF_FILE" >&2
      exit 1
    fi
  done
fi
DEVICE_NAME="${DEVICE_NAME:-unknown}"

# --- Port → Project/Service Registry ---
# Maps known ports to human-readable project context.
# Update this when adding new services to the port registry.
port_context() {
  case "$1" in
    80)    echo "Local WP / Valet / Docker Dify" ;;
    443)   echo "Local WP / Valet / Docker Dify" ;;
    3000)  echo "Dify (web frontend)" ;;
    3306)  echo "MySQL — LTVera / binoid_scratchpad" ;;
    5001)  echo "Dify (API)" ;;
    5002)  echo "Dify (plugin daemon)" ;;
    5003)  echo "Dify (plugin debug)" ;;
    5432)  echo "Homebrew Postgres 17 / Dify Postgres (CONFLICT)" ;;
    5433)  echo "Dify Postgres (pgvector)" ;;
    5000)  echo "macOS AirPlay Receiver / ControlCenter" ;;
    6379)  echo "Dify (Redis)" ;;
    7000)  echo "macOS AirPlay Receiver / ControlCenter" ;;
    8080)  echo "Dify (Weaviate)" ;;
    8194)  echo "Dify (sandbox)" ;;
    8741)  echo "Dify (nginx — non-80 mode)" ;;
    8771)  echo "Dify (ssrf_proxy)" ;;
    9001)  echo "LTVera API (reserved)" ;;
    11434) echo "Ollama" ;;
    *)     echo "unknown service" ;;
  esac
}

# Severity sort order (lower = more severe)
severity_rank() {
  case "$1" in
    CRITICAL) echo 1 ;;
    HIGH)     echo 2 ;;
    MEDIUM)   echo 3 ;;
    LOW)      echo 4 ;;
    FYI)      echo 5 ;;
    *)        echo 9 ;;
  esac
}

severity_emoji() {
  case "$1" in
    CRITICAL) echo "🔴" ;;
    HIGH)     echo "🟠" ;;
    MEDIUM)   echo "🟡" ;;
    LOW)      echo "🔵" ;;
    FYI)      echo "⚪" ;;
    *)        echo "⚪" ;;
  esac
}

# --- Helpers ---

NOW=$(date +%s)
LOCK_HELD=0
REPORTED_PROBE_KEYS="|"
LISTENER_SUMMARY_CACHE=""
LISTENER_SUMMARY_LOADED=0

ISSUES_FILE=$(mktemp /tmp/servers-monitor-issues.XXXXXX)

cleanup() {
  rm -f "$ISSUES_FILE"
  if [[ "$LOCK_HELD" -eq 1 ]]; then
    rm -rf "$LOCK_DIR"
  fi
}

trap cleanup EXIT

add_issue() {
  local severity="$1" key="$2" message="$3"
  printf '%s|%s|%s\n' "$severity" "$key" "$message" >> "$ISSUES_FILE"
}

report_probe_issue_once() {
  local key="$1" message="$2"
  case "$REPORTED_PROBE_KEYS" in
    *"|$key|"*) return 0 ;;
  esac
  REPORTED_PROBE_KEYS="${REPORTED_PROBE_KEYS}${key}|"
  add_issue "LOW" "$key" "$message"
}

emit_lock_busy_json() {
  local pid="$1"
  printf '{"status":"error","message":"servers-monitor.sh already running (pid %s)","lockPath":"%s"}\n' "$pid" "$LOCK_DIR"
}

acquire_lock() {
  local now pid started_at age

  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    started_at="$(cat "$LOCK_DIR/started_at" 2>/dev/null || true)"
    now="$(date +%s)"
    age=0
    if [[ -n "$started_at" ]]; then
      age=$((now - started_at))
    fi

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && [[ "$age" -lt "$LOCK_STALE_SECONDS" ]]; then
      if [[ "$JSON_MODE" -eq 1 ]]; then
        emit_lock_busy_json "$pid"
      else
        echo "servers-monitor.sh already running (pid $pid); skipping overlapping run" >&2
      fi
      return 1
    fi

    rm -rf "$LOCK_DIR" 2>/dev/null || {
      if [[ "$JSON_MODE" -eq 1 ]]; then
        emit_lock_busy_json "${pid:-unknown}"
      else
        echo "servers-monitor.sh could not clear stale lock at $LOCK_DIR" >&2
      fi
      return 1
    }
  done

  LOCK_HELD=1
  printf '%s\n' "$$" > "$LOCK_DIR/pid"
  printf '%s\n' "$(date +%s)" > "$LOCK_DIR/started_at"
}

capture_with_timeout() {
  local timeout_seconds="$1"
  shift

  python3 - "$timeout_seconds" "$@" <<'PY'
import subprocess
import sys

timeout_seconds = float(sys.argv[1])
command = sys.argv[2:]

try:
    completed = subprocess.run(command, capture_output=True, text=True, timeout=timeout_seconds)
except subprocess.TimeoutExpired as exc:
    if exc.stdout:
        sys.stdout.write(exc.stdout)
    if exc.stderr:
        sys.stderr.write(exc.stderr)
    sys.exit(124)
except Exception as exc:
    sys.stderr.write(str(exc))
    sys.exit(125)

if completed.stdout:
    sys.stdout.write(completed.stdout)
if completed.stderr:
    sys.stderr.write(completed.stderr)
sys.exit(completed.returncode)
PY
}

write_hash_atomic() {
  local current_hash="$1"
  local target_dir tmp_file
  target_dir="$(dirname "$HASH_FILE")"
  mkdir -p "$target_dir"
  tmp_file="$(mktemp "$target_dir/servers-monitor-baseline.hash.XXXXXX")"
  printf '%s\n' "$current_hash" > "$tmp_file"
  mv "$tmp_file" "$HASH_FILE"
}

listener_summary() {
  local raw status

  if [[ "$LISTENER_SUMMARY_LOADED" -eq 0 ]]; then
    set +e
    raw="$(capture_with_timeout "$COMMAND_TIMEOUT_SECONDS" lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null)"
    status=$?
    set -e
    LISTENER_SUMMARY_LOADED=1

    if [[ "$status" -eq 0 ]]; then
      LISTENER_SUMMARY_CACHE="$(printf '%s\n' "$raw" | awk 'NR>1 {print $1" "$2" "$9}')"
    else
      LISTENER_SUMMARY_CACHE=""
      if [[ "$status" -eq 124 ]]; then
        report_probe_issue_once "probe-lsof-timeout" "lsof listener probe timed out after ${COMMAND_TIMEOUT_SECONDS}s"
      else
        report_probe_issue_once "probe-lsof-failed" "lsof listener probe failed with exit $status"
      fi
    fi
  fi

  printf '%s\n' "$LISTENER_SUMMARY_CACHE"
}

check_port_conflicts() {
  local summary
  summary="$(listener_summary)"
  [ -n "$summary" ] || return 0

  printf '%s\n' "$summary" | awk '
    {
      split($3, addr, ":")
      port = addr[length(addr)]
      key = port FS $1
      seen[key] = 1
      ports[port] = ports[port] "|" $1
    }
    END {
      for (port in ports) {
        n = split(ports[port], raw, "|")
        delete uniq
        count = 0
        for (i = 1; i <= n; i++) {
          if (raw[i] == "") continue
          if (!(raw[i] in uniq)) {
            uniq[raw[i]] = 1
            count++
          }
        }
        if (count > 1 && port != 80 && port != 443) {
          out = ""
          for (cmd in uniq) out = out (out ? ", " : "") cmd
          print port "|" out
        }
      }
    }
  ' | while IFS='|' read -r port commands; do
    add_issue "HIGH" "port-conflict-$port" "Multiple services share port $port ($commands) — $(port_context "$port")"
  done
}

check_wildcard_binds() {
  local wildcard
  wildcard="$(listener_summary | awk '$3 ~ /\*:80$/ || $3 ~ /0\.0\.0\.0:80$/ || $3 ~ /\*:443$/ || $3 ~ /0\.0\.0\.0:443$/ {print $1" "$2" "$3}')"
  [ -z "$wildcard" ] && return 0

  while IFS= read -r row; do
    [ -n "$row" ] || continue
    add_issue "CRITICAL" "wildcard-bind" "Wildcard bind detected on 80/443: $row"
  done <<< "$wildcard"
}

check_hosts_drift() {
  [ -f "$LOCAL_WP_SITES_JSON" ] || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  python3 - "$LOCAL_WP_SITES_JSON" <<'PY' | while IFS= read -r host; do
import json, sys
sites_path = sys.argv[1]
try:
    with open(sites_path, 'r', encoding='utf-8') as handle:
        payload = json.load(handle)
except Exception:
    sys.exit(0)

domains = set()
for site in payload.values():
    domain = site.get('domain')
    if domain:
        domains.add(domain.strip().lower())

with open('/etc/hosts', 'r', encoding='utf-8') as handle:
    for line in handle:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        parts = line.split()
        for host in parts[1:]:
            host = host.lower()
            if host.endswith('.local') and host not in domains and host[4:] not in domains:
                print(host)
PY
    [ -n "$host" ] || continue
    add_issue "MEDIUM" "stale-host-$host" "Possible stale /etc/hosts entry for $host (not present in Local WP sites.json)"
  done
}

check_expected_services() {
  local summary
  summary="$(listener_summary)"

  pgrep -f dnsmasq >/dev/null 2>&1 || add_issue "LOW" "dnsmasq-down" "dnsmasq is not running — *.test resolution may be broken"
  case "$summary" in
    *":3306"*) ;;
    *) add_issue "FYI" "mysql-not-listening" "Nothing is listening on port 3306" ;;
  esac
}

check_valet_ip_binding() {
  local summary
  summary="$(listener_summary)"

  if command -v valet >/dev/null 2>&1; then
    case "$summary" in
      *"127.0.0.2:80"*) ;;
      *) add_issue "MEDIUM" "valet-bind" "Valet does not appear to be listening on 127.0.0.2:80" ;;
    esac
  fi
}

build_issue_set() {
  : > "$ISSUES_FILE"
  check_port_conflicts
  check_wildcard_binds
  check_hosts_drift
  check_expected_services
  check_valet_ip_binding
}

emit_json() {
  python3 - "$ISSUES_FILE" "$DEVICE_NAME" <<'PY'
import json, sys, datetime
issues_path, device = sys.argv[1:]
issues = []
counts = {"critical": 0, "high": 0, "medium": 0, "low": 0, "fyi": 0, "total": 0}
rank_map = {"CRITICAL": "critical", "HIGH": "high", "MEDIUM": "medium", "LOW": "low", "FYI": "fyi"}

with open(issues_path, 'r', encoding='utf-8') as handle:
    for raw in handle:
        raw = raw.rstrip('\n')
        if not raw:
            continue
        severity, key, message = raw.split('|', 2)
        issues.append({"severity": severity, "key": key, "message": message})
        bucket = rank_map.get(severity, 'fyi')
        counts[bucket] += 1
        counts["total"] += 1

status = "ok" if not issues else "issues"
print(json.dumps({
    "status": status,
  "timestamp": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat().replace('+00:00', 'Z'),
    "device": device,
    "counts": counts,
    "issues": issues,
}))
PY
}

update_baseline_hash() {
  local current_hash
  current_hash="$(shasum -a 256 "$ISSUES_FILE" | awk '{print $1}')"
  write_hash_atomic "$current_hash"
}

maybe_send_email() {
  local current_hash previous_hash
  current_hash="$(shasum -a 256 "$ISSUES_FILE" | awk '{print $1}')"
  previous_hash="$(cat "$HASH_FILE" 2>/dev/null || true)"

  if [[ "$current_hash" == "$previous_hash" ]]; then
    exit 0
  fi

  local subject body
  subject="[$DEVICE_NAME] Servers monitor issues changed"
  body="$(awk -F'|' '{printf "%s %s - %s\n", $1, $2, $3}' "$ISSUES_FILE")"

  if ! capture_with_timeout "$EMAIL_TIMEOUT_SECONDS" curl -sS https://api.resend.com/emails \
    -H "Authorization: Bearer $RESEND_API_KEY" \
    -H 'Content-Type: application/json' \
    -d "$(python3 - <<PY
import json
print(json.dumps({
  'from': '$FROM_EMAIL',
  'to': ['$TO_EMAIL'],
  'subject': '$subject',
  'text': '''$body''',
}))
PY
)" >/dev/null; then
    echo "servers-monitor.sh email send failed or timed out after ${EMAIL_TIMEOUT_SECONDS}s" >&2
    return 1
  fi

  update_baseline_hash
}

if ! acquire_lock; then
  exit 0
fi

build_issue_set

if [[ "$JSON_MODE" -eq 1 ]]; then
  emit_json
  exit 0
fi

if [[ ! -s "$ISSUES_FILE" ]]; then
  update_baseline_hash
  exit 0
fi

maybe_send_email