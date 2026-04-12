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
STATE_FILE="/tmp/servers-monitor-last-alert.state"
HASH_FILE="/tmp/servers-monitor-baseline.hash"
LOCAL_WP_SITES_JSON="$HOME/Library/Application Support/Local/sites.json"

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

ISSUES_FILE=$(mktemp /tmp/servers-monitor-issues.XXXXXX)
trap "rm -f '$ISSUES_FILE'" EXIT

add_issue() {
  local severity="$1" key="$2" message="$3"
  echo "$severity|$key|$message" >> "$ISSUES_FILE"
}

# --- Checks ---

# 1. Port conflicts: multiple DISTINCT SERVICES listening on same port.
# Dedupe by process COMMAND (not PID) since nginx has many workers sharing
# a listening socket — all the same service. Also dedupe IPv4+IPv6 duplicates.
check_port_conflicts() {
  local listen_rows
  listen_rows=$(lsof -i -P -n 2>/dev/null | grep LISTEN) || true
  [[ -z "$listen_rows" ]] && return

  # Build "port<TAB>command" pairs, unique them
  local port_cmd_pairs
  port_cmd_pairs=$(echo "$listen_rows" | awk '{
    n = split($9, parts, ":");
    port = parts[n];
    sub(/[^0-9].*$/, "", port);
    if (port != "") print port "\t" $1
  }' | sort -u)

  local ports_with_multi
  ports_with_multi=$(echo "$port_cmd_pairs" | awk '{print $1}' | sort | uniq -c | awk '$1 > 1 {print $2}')

  while read -r port; do
    [[ -z "$port" ]] && continue

    local cmd_list
    cmd_list=$(echo "$port_cmd_pairs" | awk -v p="$port" '$1 == p {print $2}' | sort -u | tr '\n' ' ')
    local cmd_count
    cmd_count=$(echo "$port_cmd_pairs" | awk -v p="$port" '$1 == p' | wc -l | tr -d ' ')

    local ctx
    ctx=$(port_context "$port")

    local sev="HIGH"
    if [[ "$port" == "5432" ]]; then sev="CRITICAL"; fi
    if [[ "$port" == "5000" ]] || [[ "$port" == "7000" ]] || [[ "$port" == "64343" ]]; then sev="FYI"; fi

    add_issue "$sev" "port-conflict-$port" "Port $port contested by $cmd_count services ($ctx): $cmd_list"
  done <<< "$ports_with_multi"
}

# 2. Wildcard bind on port 80 or 443 (blocks coexistence)
check_wildcard_80() {
  local port
  for port in 80 443; do
    local wildcard_procs
    wildcard_procs=$(lsof -i :"$port" -P -n 2>/dev/null | grep LISTEN | grep '\*:' || true)
    if [[ -n "$wildcard_procs" ]]; then
      local proc_names ctx
      proc_names=$(echo "$wildcard_procs" | awk '{printf "%s ", $1}')
      ctx=$(port_context "$port")
      add_issue "CRITICAL" "wildcard-$port" "0.0.0.0:$port binding blocks coexistence ($ctx): $proc_names"
    fi
  done
}

# 3. Stale /etc/hosts entries (*.local with no Local WP site)
check_stale_hosts() {
  [[ ! -f "$LOCAL_WP_SITES_JSON" ]] && return

  local hosts_locals
  hosts_locals=$(grep -E '\.local' /etc/hosts 2>/dev/null | grep -v '^#' | awk '{for(i=2;i<=NF;i++) print $i}' | grep '\.local$' | sort -u) || true

  local wp_domains
  wp_domains=$(python3 -c "
import json, sys
try:
    sites = json.load(open(sys.argv[1]))
    for sid, s in sites.items():
        d = s.get('domain', '')
        if d: print(d)
except: pass
" "$LOCAL_WP_SITES_JSON" 2>/dev/null | sort -u) || true

  local stale_list=""
  local stale_count=0
  while read -r host; do
    [[ -z "$host" ]] && continue
    # Strip www. prefix — Local WP auto-creates www.<domain> /etc/hosts entries
    # but only stores the bare domain in sites.json
    local bare_host="${host#www.}"
    if ! echo "$wp_domains" | grep -qxF "$bare_host"; then
      if [[ -n "$stale_list" ]]; then stale_list="$stale_list, "; fi
      stale_list="$stale_list$host"
      stale_count=$((stale_count + 1))
    fi
  done <<< "$hosts_locals"

  if [[ "$stale_count" -gt 0 ]]; then
    add_issue "LOW" "stale-hosts" "Stale /etc/hosts entries — $stale_count orphaned .local hostname(s) (Local WP): $stale_list"
  fi
}

# 4. Expected services check
check_expected_services() {
  if ! pgrep -f dnsmasq >/dev/null 2>&1; then
    add_issue "HIGH" "dnsmasq-down" "dnsmasq not running — *.test DNS resolution broken (Valet)"
  fi
  if ! lsof -i :3306 -P -n 2>/dev/null | grep -q LISTEN; then
    add_issue "MEDIUM" "mysql-down" "Nothing listening on port 3306 — MySQL may be down (LTVera / binoid_scratchpad)"
  fi
}

# 5. Valet binding wrong IP (should only be 127.0.0.2, not 127.0.0.1)
check_valet_ip() {
  local valet_on_loopback1
  valet_on_loopback1=$(lsof -i :80 -P -n 2>/dev/null | grep LISTEN | grep 'nginx' | grep '127.0.0.1:80' || true)
  local localwp_running
  localwp_running=$(lsof -i :80 -P -n 2>/dev/null | grep LISTEN | grep '127.0.0.1:80' | grep -v nginx || true)

  if [[ -n "$valet_on_loopback1" ]] && [[ -n "$localwp_running" ]]; then
    add_issue "CRITICAL" "valet-ip-conflict" "Valet nginx and Local WP both binding 127.0.0.1:80 — coexistence broken"
  elif [[ -n "$valet_on_loopback1" ]]; then
    add_issue "HIGH" "valet-wrong-ip" "Valet nginx binding 127.0.0.1:80 — should only bind 127.0.0.2:80 (Valet)"
  fi
}

# --- Run all checks ---
check_port_conflicts
check_wildcard_80
check_stale_hosts
check_expected_services
check_valet_ip

# --- JSON mode: emit structured output and exit (no email, no baseline update) ---
if [[ "$JSON_MODE" -eq 1 ]]; then
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Count by severity
  CRIT=0; HIGH=0; MED=0; LOW=0; FYI=0
  if [[ -s "$ISSUES_FILE" ]]; then
    CRIT=$(awk -F'|' '$1=="CRITICAL"' "$ISSUES_FILE" | wc -l | tr -d ' ')
    HIGH=$(awk -F'|' '$1=="HIGH"'     "$ISSUES_FILE" | wc -l | tr -d ' ')
    MED=$(awk  -F'|' '$1=="MEDIUM"'   "$ISSUES_FILE" | wc -l | tr -d ' ')
    LOW=$(awk  -F'|' '$1=="LOW"'      "$ISSUES_FILE" | wc -l | tr -d ' ')
    FYI=$(awk  -F'|' '$1=="FYI"'      "$ISSUES_FILE" | wc -l | tr -d ' ')
  fi
  TOTAL=$((CRIT + HIGH + MED + LOW + FYI))

  if [[ "$TOTAL" -eq 0 ]]; then
    STATUS="ok"
  else
    STATUS="issues"
  fi

  # Emit JSON via python (already required elsewhere in this script, and it
  # handles escaping messages with quotes/backslashes safely).
  python3 - "$ISSUES_FILE" "$STATUS" "$TIMESTAMP" "$DEVICE_NAME" "$CRIT" "$HIGH" "$MED" "$LOW" "$FYI" "$TOTAL" <<'PY'
import json, sys
issues_path, status, ts, device, crit, high, med, low, fyi, total = sys.argv[1:]
issues = []
try:
    with open(issues_path) as f:
        for line in f:
            line = line.rstrip('\n')
            if not line:
                continue
            parts = line.split('|', 2)
            if len(parts) != 3:
                continue
            severity, key, message = parts
            issues.append({"severity": severity, "key": key, "message": message})
except FileNotFoundError:
    pass

print(json.dumps({
    "status": status,
    "timestamp": ts,
    "device": device,
    "counts": {
        "critical": int(crit),
        "high": int(high),
        "medium": int(med),
        "low": int(low),
        "fyi": int(fyi),
        "total": int(total),
    },
    "issues": issues,
}))
PY
  exit 0
fi

# --- Check if any issues found ---
if [[ ! -s "$ISSUES_FILE" ]]; then
  # All clear — if we previously had issues, clear the baseline so
  # a future recurrence triggers a fresh alert
  if [[ -f "$HASH_FILE" ]]; then
    rm -f "$HASH_FILE"
  fi
  exit 0
fi

# --- Baseline dedup: hash all issue keys, skip email if unchanged ---
# Sort issue keys for deterministic hash
CURRENT_HASH=$(awk -F'|' '{print $2}' "$ISSUES_FILE" | sort | shasum -a 256 | awk '{print $1}')

if [[ -f "$HASH_FILE" ]]; then
  PREVIOUS_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")
  if [[ "$CURRENT_HASH" == "$PREVIOUS_HASH" ]]; then
    # Same baseline — suppress email entirely
    exit 0
  fi
fi

# --- Sort issues by severity ---
SORTED_FILE=$(mktemp /tmp/servers-monitor-sorted.XXXXXX)
trap "rm -f '$ISSUES_FILE' '$SORTED_FILE'" EXIT

while IFS='|' read -r severity key message; do
  [[ -z "$severity" ]] && continue
  rank=$(severity_rank "$severity")
  echo "${rank}|${severity}|${key}|${message}"
done < "$ISSUES_FILE" | sort -t'|' -k1,1n > "$SORTED_FILE"

ISSUE_COUNT=$(wc -l < "$SORTED_FILE" | tr -d ' ')

# Count by severity for subject line
CRIT_COUNT=$(grep -c '^1|' "$SORTED_FILE" || true)
HIGH_COUNT=$(grep -c '^2|' "$SORTED_FILE" || true)
MED_COUNT=$(grep -c '^3|' "$SORTED_FILE" || true)
LOW_COUNT=$(grep -c '^4|' "$SORTED_FILE" || true)
FYI_COUNT=$(grep -c '^5|' "$SORTED_FILE" || true)

# Build severity summary for subject
SEVERITY_SUMMARY=""
if [[ "$CRIT_COUNT" -gt 0 ]]; then SEVERITY_SUMMARY="${CRIT_COUNT} critical"; fi
if [[ "$HIGH_COUNT" -gt 0 ]]; then
  if [[ -n "$SEVERITY_SUMMARY" ]]; then SEVERITY_SUMMARY="$SEVERITY_SUMMARY, "; fi
  SEVERITY_SUMMARY="${SEVERITY_SUMMARY}${HIGH_COUNT} high"
fi
if [[ "$MED_COUNT" -gt 0 ]]; then
  if [[ -n "$SEVERITY_SUMMARY" ]]; then SEVERITY_SUMMARY="$SEVERITY_SUMMARY, "; fi
  SEVERITY_SUMMARY="${SEVERITY_SUMMARY}${MED_COUNT} medium"
fi
if [[ "$LOW_COUNT" -gt 0 ]]; then
  if [[ -n "$SEVERITY_SUMMARY" ]]; then SEVERITY_SUMMARY="$SEVERITY_SUMMARY, "; fi
  SEVERITY_SUMMARY="${SEVERITY_SUMMARY}${LOW_COUNT} low"
fi
if [[ "$FYI_COUNT" -gt 0 ]]; then
  if [[ -n "$SEVERITY_SUMMARY" ]]; then SEVERITY_SUMMARY="$SEVERITY_SUMMARY, "; fi
  SEVERITY_SUMMARY="${SEVERITY_SUMMARY}${FYI_COUNT} fyi"
fi

# --- Build email body ---
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S %Z')

# Determine highest severity for subject prefix
TOP_SEV="FYI"
if [[ "$CRIT_COUNT" -gt 0 ]]; then TOP_SEV="CRITICAL";
elif [[ "$HIGH_COUNT" -gt 0 ]]; then TOP_SEV="HIGH";
elif [[ "$MED_COUNT" -gt 0 ]]; then TOP_SEV="MEDIUM";
elif [[ "$LOW_COUNT" -gt 0 ]]; then TOP_SEV="LOW";
fi

BODY="$(severity_emoji "$TOP_SEV") Servers Monitor — $DEVICE_NAME
$TIMESTAMP
$ISSUE_COUNT issue(s): $SEVERITY_SUMMARY

"

# Group by severity with headers
CURRENT_SEV=""
while IFS='|' read -r rank severity key message; do
  if [[ "$severity" != "$CURRENT_SEV" ]]; then
    CURRENT_SEV="$severity"
    BODY="$BODY
$(severity_emoji "$severity") $severity
$(printf '%0.s─' {1..40})
"
  fi
  BODY="$BODY  • $message
"
done < "$SORTED_FILE"

BODY="$BODY

───────────────────────────────────
Quick checks:
  lsof -i :80 -P -n | grep LISTEN
  ~/bin/ai-ddtk/tools/servers-audit.sh
  ~/bin/servers-monitor  (manual re-run)

Ref: ~/bin/servers-conflict-free.md

This alert will not repeat unless the issue
baseline changes (new issue appears or one resolves).
"

BODY_JSON=$(printf '%s' "$BODY" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

# --- Send via Resend API ---
SUBJECT="[${TOP_SEV}] $DEVICE_NAME — $SEVERITY_SUMMARY"
SUBJECT_JSON=$(printf '%s' "$SUBJECT" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

HTTP_CODE=$(curl -s -o /tmp/servers-monitor-response.json -w "%{http_code}" \
  -X POST "https://api.resend.com/emails" \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"from\": \"Server Monitor <$FROM_EMAIL>\",
    \"to\": [\"$TO_EMAIL\"],
    \"subject\": $SUBJECT_JSON,
    \"text\": $BODY_JSON
  }")

if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "202" ]]; then
  # Save baseline hash — no re-alert until issues change
  echo "$CURRENT_HASH" > "$HASH_FILE"
  echo "Alert sent ($ISSUE_COUNT issues: $SEVERITY_SUMMARY) — HTTP $HTTP_CODE"
else
  echo "WARNING: Resend API returned HTTP $HTTP_CODE" >&2
  cat /tmp/servers-monitor-response.json >&2 2>/dev/null || true
fi
