#!/bin/bash
# dev-context — Port 80 context switcher for Local WP ↔ Valet mutex.
#
# Local WP's router nginx binds 0.0.0.0:80 (wildcard) and cannot coexist with
# any specific-IP bind on port 80. Valet binds 127.0.0.2:80. Docker Dify runs
# on its own high ports (8741/8742) and is always fine.
#
# This script switches between:
#   - valet mode:   Valet owns 127.0.0.2:80, Docker Dify reachable via http://dify.test
#   - localwp mode: Local WP owns 0.0.0.0:80, Valet stopped, dify.test unreachable
#                   (use http://localhost:8741 for Dify in this mode)
#
# Dify/Docker is NEVER stopped by this script — it doesn't compete for port 80.
#
# Usage:
#   dev-context status        Show current state
#   dev-context valet         Switch to Valet mode (stops Local WP router if active)
#   dev-context localwp       Switch to Local WP mode (stops Valet nginx)
#
# See: ~/bin/servers.md § "Troubleshooting / Decision Tree"
#      ~/bin/servers-conflict-free.md

set -euo pipefail

# --- Colors ---
if [ -t 1 ]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; BLUE=$'\033[34m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; DIM=""; RESET=""
fi

ok()    { printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
warn()  { printf "  ${YELLOW}⚠${RESET} %s\n" "$1"; }
err()   { printf "  ${RED}✗${RESET} %s\n" "$1"; }
info()  { printf "  ${BLUE}›${RESET} %s\n" "$1"; }
head()  { printf "\n${BOLD}%s${RESET}\n" "$1"; }

# --- State detection ---

port80_listeners() {
  lsof -i :80 -P -n 2>/dev/null | grep LISTEN || true
}

port80_wildcard() {
  port80_listeners | grep -E '\*:80|0\.0\.0\.0:80' || true
}

port80_valet() {
  port80_listeners | grep '127.0.0.2:80' || true
}

port80_localwp_loopback() {
  # Local WP binds 0.0.0.0 but appears as *:80. Also check 127.0.0.1 for safety.
  port80_listeners | grep '127.0.0.1:80' || true
}

localwp_router_running() {
  # Local WP router nginx lives under ~/Library/Application Support/Local/run/router
  pgrep -f "Local/run/router/nginx" >/dev/null 2>&1
}

valet_nginx_running() {
  # Valet's nginx is PHP-FPM paired; distinct from Local WP's nginx by path
  pgrep -f "/opt/homebrew/.*nginx" >/dev/null 2>&1 || \
  pgrep -f "valet.*nginx" >/dev/null 2>&1 || \
  [ -n "$(port80_valet)" ]
}

dify_running() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^docker-nginx-1$'
}

dnsmasq_running() {
  pgrep -f dnsmasq >/dev/null 2>&1
}

detect_mode() {
  local wildcard valet
  wildcard="$(port80_wildcard)"
  valet="$(port80_valet)"

  if [ -n "$wildcard" ] && [ -n "$valet" ]; then
    echo "conflict"
  elif [ -n "$wildcard" ]; then
    echo "localwp"
  elif [ -n "$valet" ]; then
    echo "valet"
  else
    echo "none"
  fi
}

# --- Commands ---

cmd_status_json() {
  local mode
  mode="$(detect_mode)"

  local valet_nginx dnsmasq localwp_router dify
  [ -n "$(port80_valet)" ] && valet_nginx="true" || valet_nginx="false"
  dnsmasq_running && dnsmasq="true" || dnsmasq="false"
  localwp_router_running && localwp_router="true" || localwp_router="false"
  dify_running && dify="true" || dify="false"

  # Pipe listener rows + valet proxies output through python for safe JSON escaping
  python3 - "$mode" "$valet_nginx" "$dnsmasq" "$localwp_router" "$dify" <<PY
import json, sys, subprocess, re
mode, valet_nginx, dnsmasq, localwp_router, dify = sys.argv[1:]

# Port 80 listeners
listeners = []
try:
    out = subprocess.check_output(
        ["lsof", "-i", ":80", "-P", "-n"], stderr=subprocess.DEVNULL, text=True
    )
    for line in out.splitlines():
        if "LISTEN" not in line:
            continue
        parts = line.split()
        if len(parts) >= 9:
            listeners.append({"command": parts[0], "pid": parts[1], "address": parts[8]})
except Exception:
    pass

# Valet proxies
proxies = []
try:
    out = subprocess.check_output(["valet", "proxies"], stderr=subprocess.DEVNULL, text=True)
    for line in out.splitlines():
        if not line.startswith("|") or "Site" in line or "---" in line:
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) >= 4 and cells[0]:
            proxies.append({
                "site": cells[0],
                "ssl": bool(cells[1]),
                "url": cells[2],
                "host": cells[3],
            })
except Exception:
    pass

print(json.dumps({
    "mode": mode,
    "services": {
        "valet_nginx": valet_nginx == "true",
        "dnsmasq": dnsmasq == "true",
        "localwp_router": localwp_router == "true",
        "dify_docker": dify == "true",
    },
    "port80Listeners": listeners,
    "valetProxies": proxies,
}))
PY
}

cmd_status() {
  # --json flag → structured output
  if [ "${1:-}" = "--json" ]; then
    cmd_status_json
    return
  fi

  local mode valet_proxies
  mode="$(detect_mode)"

  head "Development Context Status"

  case "$mode" in
    valet)
      ok "${BOLD}Mode: VALET${RESET} (Valet owns 127.0.0.2:80, *.test sites active)"
      ;;
    localwp)
      ok "${BOLD}Mode: LOCAL WP${RESET} (Local WP router owns 0.0.0.0:80, *.local sites active)"
      warn "http://dify.test and http://ltvera.test are unreachable in this mode"
      info "Access Dify directly at http://localhost:8741"
      ;;
    conflict)
      err "${BOLD}Mode: CONFLICT${RESET} — both Valet and Local WP are trying to hold port 80"
      err "Run 'dev-context valet' or 'dev-context localwp' to resolve"
      ;;
    none)
      warn "${BOLD}Mode: IDLE${RESET} — nothing is holding port 80"
      ;;
  esac

  head "Services"

  if dnsmasq_running; then
    ok "dnsmasq running (Valet DNS resolver — *.test → 127.0.0.2)"
  else
    warn "dnsmasq NOT running — *.test DNS resolution broken"
  fi

  if [ -n "$(port80_valet)" ]; then
    ok "Valet nginx listening on 127.0.0.2:80"
  else
    info "Valet nginx stopped"
  fi

  if localwp_router_running; then
    ok "Local WP router nginx running"
  else
    info "Local WP router stopped (start a site in Local WP GUI to bring it up)"
  fi

  if dify_running; then
    ok "Docker Dify stack running (docker-nginx-1 on *:8741)"
  else
    info "Docker Dify stopped — start with: cd ~/Documents/GH\ Repos/dify/docker && docker compose up -d"
  fi

  head "Valet Proxies"
  if command -v valet >/dev/null 2>&1; then
    valet proxies 2>/dev/null | sed 's/^/  /' || info "(none registered)"
  else
    warn "valet CLI not found in PATH"
  fi

  head "Port 80 listeners (raw)"
  local listeners
  listeners="$(port80_listeners)"
  if [ -n "$listeners" ]; then
    echo "$listeners" | awk '{printf "  %-12s PID %-8s %s\n", $1, $2, $9}'
  else
    info "(nothing listening on port 80)"
  fi
  printf "\n"
}

cmd_valet() {
  head "Switching to VALET mode"

  if localwp_router_running; then
    warn "Local WP router is running and binds 0.0.0.0:80 (will block Valet)"
    err "Stop all sites in the Local WP GUI first, then retry."
    err "Local WP doesn't expose a CLI to stop the router without the GUI."
    info "Tip: Local WP → click the 'Stop' button on each running site"
    info "     (or fully quit Local WP with Cmd+Q)"
    exit 1
  fi

  # Free port 80 if anything else is holding the wildcard
  local wildcard
  wildcard="$(port80_wildcard)"
  if [ -n "$wildcard" ]; then
    err "Something is binding 0.0.0.0:80 (neither Valet nor Local WP recognised):"
    echo "$wildcard" | awk '{print "      " $1 " PID " $2 " " $9}'
    err "Stop this process first, then retry 'dev-context valet'."
    exit 1
  fi

  if [ -n "$(port80_valet)" ]; then
    ok "Valet already on 127.0.0.2:80 — no change needed"
  else
    info "Starting Valet nginx..."
    valet start
    ok "Valet started"
  fi

  if dify_running; then
    ok "Docker Dify untouched (still on 8741/8742)"
    info "Dify accessible at http://dify.test via Valet proxy"
  else
    info "Docker Dify is not running (start manually if needed)"
  fi

  printf "\n"
  cmd_status
}

cmd_localwp() {
  head "Switching to LOCAL WP mode"

  if [ -n "$(port80_valet)" ]; then
    info "Stopping Valet nginx (dnsmasq keeps running for *.test DNS)..."
    valet stop
    ok "Valet stopped"
  else
    info "Valet nginx already stopped"
  fi

  # Verify port 80 is actually free now
  local remaining
  remaining="$(port80_listeners)"
  if [ -n "$remaining" ]; then
    warn "Port 80 still has listeners:"
    echo "$remaining" | awk '{print "      " $1 " PID " $2 " " $9}'
    warn "Local WP will fail to bind unless these are stopped."
  else
    ok "Port 80 is free — Local WP router can now bind 0.0.0.0:80"
  fi

  if dify_running; then
    warn "Docker Dify is still running, but http://dify.test is NOT reachable in this mode"
    info "Valet proxy is down — access Dify directly at http://localhost:8741"
  fi

  head "Next steps"
  info "1. Open Local WP"
  info "2. Click 'Start site' on the site you want (e.g., Bloomz-Prod-08-15)"
  info "3. Local WP will bind 0.0.0.0:80 and the site will be reachable at http://<site>.local"
  info ""
  info "When done, run 'dev-context valet' to bring Valet + Dify routing back"
  printf "\n"
}

cmd_help() {
  cat <<EOF
${BOLD}dev-context${RESET} — Port 80 context switcher

${BOLD}USAGE${RESET}
    dev-context <command>

${BOLD}COMMANDS${RESET}
    ${BOLD}status${RESET}      Show current mode, services, and port 80 listeners
    ${BOLD}valet${RESET}       Switch to Valet mode (serves *.test + Dify proxy)
    ${BOLD}localwp${RESET}     Switch to Local WP mode (serves *.local)
    ${BOLD}help${RESET}        Show this message

${BOLD}WHY${RESET}
    Local WP's router nginx binds 0.0.0.0:80 (wildcard) and cannot coexist
    with Valet's 127.0.0.2:80 binding. Docker Dify uses its own high ports
    (8741/8742) and is never affected by this switch.

${BOLD}SEE ALSO${RESET}
    ~/bin/servers.md                   Full machine registry + decision tree
    ~/bin/servers-conflict-free.md     Architecture plan
    ~/bin/servers-monitor              Conflict monitor (runs every 30 min)
EOF
}

# --- Dispatch ---
case "${1:-help}" in
  status)  shift; cmd_status "$@" ;;
  valet)   cmd_valet ;;
  localwp) cmd_localwp ;;
  help|-h|--help) cmd_help ;;
  *)       err "Unknown command: $1"; echo; cmd_help; exit 1 ;;
esac
