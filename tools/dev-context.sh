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
}

cmd_valet() {
  head "Switching to Valet Mode"

  if [ -n "$(port80_wildcard)" ]; then
    warn "A wildcard listener currently owns port 80"
    info "Stop Local WP's router before relying on Valet-only routing"
  fi

  if localwp_router_running; then
    warn "Local WP router appears to be running"
    info "Stop all sites in Local WP or quit the app before continuing"
    exit 1
  fi

  if command -v valet >/dev/null 2>&1; then
    info "Restarting Valet"
    valet restart >/dev/null
    ok "Valet restarted"
  else
    err "valet CLI not found in PATH"
    exit 1
  fi

  cmd_status
}

cmd_localwp() {
  head "Switching to Local WP Mode"

  if [ -n "$(port80_valet)" ]; then
    info "Stopping Valet nginx so Local WP can reclaim port 80"
    if command -v valet >/dev/null 2>&1; then
      valet stop >/dev/null || true
      ok "Valet stopped"
    else
      warn "valet CLI not found; stop Valet manually if it is running"
    fi
  fi

  info "Start or restart the needed Local WP site from the Local app"
  info "Local WP's router should then reclaim port 80"

  cmd_status
}

cmd_help() {
  cat <<EOF
Usage:
  dev-context status [--json]   Show current state
  dev-context valet             Switch to Valet mode
  dev-context localwp           Switch to Local WP mode
  dev-context help              Show this help
EOF
}

case "${1:-status}" in
  status)
    shift || true
    cmd_status "$@"
    ;;
  valet)
    cmd_valet
    ;;
  localwp)
    cmd_localwp
    ;;
  help|-h|--help)
    cmd_help
    ;;
  *)
    err "Unknown command: ${1:-}"
    echo
    cmd_help
    exit 1
    ;;
esac