#!/bin/bash
# local-nginx-shim-install.sh — Installer for the Local WP nginx coexistence shim.
#
# This replaces Local WP's bundled nginx binary with a wrapper (see
# experimental/local-nginx-shim) that rewrites router config bindings from
# 0.0.0.0:80 → 127.0.0.1:80 at runtime, enabling Local WP + Valet coexistence.
#
# Usage:
#   local-nginx-shim-install.sh install     Install or refresh the shim
#   local-nginx-shim-install.sh uninstall   Restore the original nginx binary
#   local-nginx-shim-install.sh status      Show install state
#
# Re-run `install` after any Local WP update (which may replace the nginx binary
# and wipe the shim).
#
# See: ~/bin/servers.md for the full architecture

set -euo pipefail

SHIM_SOURCE="$(cd "$(dirname "$0")" && pwd)/local-nginx-shim"
LIGHTNING_DIR="$HOME/Library/Application Support/Local/lightning-services"
SHIM_MARKER="# MARKER: local-nginx-shim v1"

# --- Colors ---
if [ -t 1 ]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

ok()   { printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
warn() { printf "  ${YELLOW}⚠${RESET} %s\n" "$1"; }
err()  { printf "  ${RED}✗${RESET} %s\n" "$1"; }
info() { printf "  ${BLUE}›${RESET} %s\n" "$1"; }

# --- Locate Local WP's nginx binary ---
# Path pattern: .../lightning-services/nginx-X.Y.Z+N/bin/<arch>/sbin/nginx
# Multiple versions may exist; pick the newest by mtime.
find_nginx() {
  [ -d "$LIGHTNING_DIR" ] || return 1
  find "$LIGHTNING_DIR" -type f -name nginx -path '*/sbin/nginx' 2>/dev/null \
    | while read -r f; do printf '%s\t%s\n' "$(stat -f '%m' "$f")" "$f"; done \
    | sort -rn \
    | head -1 \
    | cut -f2-
}

is_shimmed() {
  local f="$1"
  [ -f "$f" ] && head -40 "$f" 2>/dev/null | grep -q "$SHIM_MARKER"
}

# --- Commands ---

cmd_status() {
  printf "\n${BOLD}Local WP nginx shim status${RESET}\n\n"

  if [ ! -d "$LIGHTNING_DIR" ]; then
    err "Local WP lightning-services directory not found"
    info "Expected: $LIGHTNING_DIR"
    info "Is Local WP installed?"
    return 1
  fi

  local all_nginx
  all_nginx="$(find "$LIGHTNING_DIR" -type f -name nginx -path '*/sbin/nginx' 2>/dev/null)"

  if [ -z "$all_nginx" ]; then
    warn "No nginx binaries found under $LIGHTNING_DIR"
    return 0
  fi

  while IFS= read -r nginx_path; do
    local dir="$(dirname "$nginx_path")"
    local real="$dir/nginx.real"
    local rel="${nginx_path#$LIGHTNING_DIR/}"

    printf "  ${BOLD}%s${RESET}\n" "$rel"

    if is_shimmed "$nginx_path"; then
      ok "SHIMMED (wrapper in place)"
      if [ -x "$real" ]; then
        ok "nginx.real backup present"
      else
        err "nginx.real backup MISSING — shim will fail to exec"
      fi
    else
      info "not shimmed (stock Local WP nginx)"
      if [ -x "$real" ]; then
        warn "stray nginx.real exists but nginx is not a shim — manual cleanup needed"
      fi
    fi
    printf "\n"
  done <<< "$all_nginx"
}

cmd_install() {
  printf "\n${BOLD}Installing Local WP nginx shim${RESET}\n\n"

  if [ ! -f "$SHIM_SOURCE" ]; then
    err "Shim source not found at: $SHIM_SOURCE"
    exit 1
  fi

  local nginx_path
  nginx_path="$(find_nginx || true)"

  if [ -z "$nginx_path" ]; then
    err "Could not locate Local WP nginx binary"
    info "Expected under: $LIGHTNING_DIR/nginx-*/bin/*/sbin/nginx"
    info "Is Local WP installed?"
    exit 1
  fi

  info "Target: $nginx_path"

  local dir="$(dirname "$nginx_path")"
  local real="$dir/nginx.real"

  # Warn if Local WP router is currently running (nginx will be locked / in use)
  if pgrep -f "$nginx_path" >/dev/null 2>&1; then
    warn "Local WP nginx processes are currently running"
    info "Stop all sites in Local WP (or Cmd+Q the app) before installing the shim"
    info "Then re-run: local-nginx-shim-install.sh install"
    exit 1
  fi

  if is_shimmed "$nginx_path"; then
    info "Shim is already installed — refreshing from source"
    cp "$SHIM_SOURCE" "$nginx_path"
    chmod +x "$nginx_path"
    ok "Shim refreshed"
    if [ ! -x "$real" ]; then
      err "nginx.real backup is missing — cannot continue safely"
      err "You must restore Local WP's bundled nginx first (reinstall Local WP or restore from Time Machine)"
      exit 1
    fi
    ok "nginx.real backup still present"
    return 0
  fi

  # Fresh install: back up the real binary, replace with shim
  if [ -e "$real" ]; then
    err "Unexpected: $real already exists but nginx is not shimmed"
    info "Manual intervention required — inspect both files before proceeding"
    exit 1
  fi

  info "Backing up original nginx → nginx.real"
  mv "$nginx_path" "$real"
  ok "Backup created: $real"

  info "Installing shim in place of nginx"
  cp "$SHIM_SOURCE" "$nginx_path"
  chmod +x "$nginx_path"
  ok "Shim installed: $nginx_path"

  printf "\n${BOLD}Verify:${RESET}\n"
  info "Run 'local-nginx-shim-install.sh status' to confirm"
  info "Then start a site in Local WP — the router should now bind 127.0.0.1:80"
  info ""
  info "When both Valet and Local WP are up, verify with:"
  info "  lsof -i :80 -P -n | grep LISTEN"
  info "You should see nginx on 127.0.0.1:80 AND 127.0.0.2:80 simultaneously."
  printf "\n"
}

cmd_uninstall() {
  printf "\n${BOLD}Uninstalling Local WP nginx shim${RESET}\n\n"

  local nginx_path
  nginx_path="$(find_nginx || true)"

  if [ -z "$nginx_path" ]; then
    err "Could not locate Local WP nginx binary"
    exit 1
  fi

  local dir="$(dirname "$nginx_path")"
  local real="$dir/nginx.real"

  if ! is_shimmed "$nginx_path"; then
    info "nginx at $nginx_path is not a shim — nothing to uninstall"
    return 0
  fi

  if [ ! -x "$real" ]; then
    err "nginx.real backup is missing — cannot restore"
    err "You'll need to reinstall Local WP to get the original nginx binary back"
    exit 1
  fi

  # Warn if Local WP router is currently running
  if pgrep -f "$nginx_path" >/dev/null 2>&1; then
    warn "Local WP nginx processes are currently running"
    info "Stop all sites (or Cmd+Q Local WP) before uninstalling"
    exit 1
  fi

  info "Removing shim"
  rm "$nginx_path"
  ok "Shim removed"

  info "Restoring nginx.real → nginx"
  mv "$real" "$nginx_path"
  chmod +x "$nginx_path"
  ok "Original nginx restored"

  printf "\n"
  info "Local WP will revert to binding 0.0.0.0:80 on next router start."
  info "Use 'dev-context localwp' to avoid conflicts with Valet."
  printf "\n"
}

cmd_help() {
  cat <<EOF
${BOLD}local-nginx-shim-install.sh${RESET} — Install/manage the Local WP nginx coexistence shim

${BOLD}USAGE${RESET}
    local-nginx-shim-install.sh <command>

${BOLD}COMMANDS${RESET}
    ${BOLD}install${RESET}      Install the shim (backs up original as nginx.real)
    ${BOLD}uninstall${RESET}    Restore original nginx (removes shim)
    ${BOLD}status${RESET}       Show current install state
    ${BOLD}help${RESET}         Show this message

${BOLD}WHAT IT DOES${RESET}
    Replaces Local WP's bundled nginx binary with a wrapper script that
    rewrites the router's listen directives at runtime from 0.0.0.0:80
    (wildcard) to 127.0.0.1:80 (specific). This enables Local WP to coexist
    with Valet (on 127.0.0.2:80) and other loopback-bound services on port 80.

${BOLD}WHEN TO RE-RUN${RESET}
    After any Local WP app update — updates may replace the nginx binary
    and wipe the shim. Run 'status' to check, 'install' to re-shim.

${BOLD}SAFETY${RESET}
    The original nginx binary is backed up as 'nginx.real' in the same
    directory before being replaced. The shim execs nginx.real unchanged
    after patching the config, so nginx behaves identically except for
    the listen addresses.

    Per-site nginx configs (which use high ports like 10139) are not
    touched — only router configs under run/router/nginx/conf/ are patched.

${BOLD}SEE ALSO${RESET}
    experimental/local-nginx-shim       The shim itself (this script installs it)
    experimental/dev-context.sh         Alternative: context switcher (mutex model)
    ~/bin/servers.md                    Full machine registry
EOF
}

# --- Dispatch ---
case "${1:-help}" in
  install)   cmd_install ;;
  uninstall) cmd_uninstall ;;
  status)    cmd_status ;;
  help|-h|--help) cmd_help ;;
  *) err "Unknown command: $1"; echo; cmd_help; exit 1 ;;
esac
