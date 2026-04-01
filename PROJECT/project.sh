#!/usr/bin/env bash
# =============================================================================
# project.sh — PROJECT folder hygiene · Phase 1
# =============================================================================
# Scans PROJECT/ .md files; any not edited in N days gets its P1-/P2- prefix
# downgraded to P3-, or gains a P3- prefix if currently untagged.
# Only touches .md files — all other extensions (including .sh) are left alone.
#
# AI AGENT HOOKS
#   --json      Emit structured JSON to stdout for agent/MCP consumption
#   Exit codes  0=clean · 1=stale found (dry-run) · 2=renames applied · 99=error
#   Always emits ##AGENT-CONTEXT and ##AGENT-PROMPTS blocks at end of stdout
#   so an orchestrating LLM can parse results and relay suggested prompts.
#
# USAGE
#   ./PROJECT/project.sh                 # dry-run — safe default, no writes
#   ./PROJECT/project.sh --apply         # rename files (git mv when in a repo)
#   ./PROJECT/project.sh --json          # structured JSON output only
#   ./PROJECT/project.sh --days 14       # custom stale threshold (default: 8)
#   ./PROJECT/project.sh --include-done  # also scan the 3-DONE/ subfolder
#   ./PROJECT/project.sh --no-exclude-meta  # include meta docs like DOCS-INSTRUCTIONS.md
#
# PHASE ROADMAP
#   Phase 1 (this) — scan + P3 prefix/downgrade, xref warnings, agent hooks
#   Phase 2        — cross-reference registry: detect and record broken links
#   Phase 3        — auto-update xrefs via search-and-replace
#   Phase 4        — MCP server adapter for continuous hygiene orchestration
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
DAYS_THRESHOLD=8
DRY_RUN=true
JSON_MODE=false
INCLUDE_DONE=false
EXCLUDE_META=true   # skip meta-docs like DOCS-INSTRUCTIONS.md by default

# ── Arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)           DRY_RUN=false ;;
    --json)            JSON_MODE=true ;;
    --include-done)    INCLUDE_DONE=true ;;
    --no-exclude-meta) EXCLUDE_META=false ;;
    --days)
      [[ "${2:-}" =~ ^[0-9]+$ ]] || { echo "ERROR: --days requires a positive integer" >&2; exit 99; }
      DAYS_THRESHOLD="$2"; shift ;;
    --help|-h)
      sed -n '/^# USAGE/,/^# PHASE/p' "$0" | sed 's/^# \?//' | grep -v '^$' | head -12
      exit 0 ;;
    *) echo "ERROR: Unknown flag: $1 (try --help)" >&2; exit 99 ;;
  esac
  shift
done

# ── Git detection ─────────────────────────────────────────────────────────────
USE_GIT=false
git -C "$SCRIPT_DIR" rev-parse --git-dir &>/dev/null 2>&1 && USE_GIT=true || true

# ── Helpers ───────────────────────────────────────────────────────────────────

# Remove ALL leading P[0-9]- prefixes — prevents P3-P3-P3- accumulation
strip_priority_prefix() {
  local n="$1"
  while [[ "$n" =~ ^[Pp][0-9]- ]]; do n="${n:3}"; done
  echo "$n"
}

make_p3_name() { echo "P3-$(strip_priority_prefix "$1")"; }

# Returns: already-p3 | downgrade | add-prefix
classify_action() {
  local name="$1"
  if   [[ "$name" =~ ^P3- ]]; then echo "already-p3"
  elif [[ "$name" =~ ^P[12]- ]]; then echo "downgrade"
  else echo "add-prefix"
  fi
}

# Minimal JSON string escaper (no control chars expected in filenames)
json_str() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# ── Scan: find stale .md files ────────────────────────────────────────────────
STALE_FILES=()
STALE_AGES=()
ALL_SCANNED=0
NOW=$(date +%s)

while IFS= read -r -d '' filepath; do
  filename="$(basename "$filepath")"

  # Skip meta docs unless --no-exclude-meta
  if $EXCLUDE_META && [[ "$filename" == "DOCS-INSTRUCTIONS.md" ]]; then continue; fi

  ALL_SCANNED=$((ALL_SCANNED + 1))

  # Portable mtime: macOS stat uses -f %m · Linux stat uses -c %Y
  if mtime=$(stat -f %m "$filepath" 2>/dev/null); then
    :
  else
    mtime=$(stat -c %Y "$filepath" 2>/dev/null) || continue
  fi

  age=$(( (NOW - mtime) / 86400 ))
  if (( age > DAYS_THRESHOLD )); then
    STALE_FILES+=("$filepath")
    STALE_AGES+=("$age")
  fi
done < <(
  if $INCLUDE_DONE; then
    find "$SCRIPT_DIR" -name "*.md" -not -name "$SCRIPT_NAME" -print0 2>/dev/null
  else
    find "$SCRIPT_DIR" -name "*.md" -not -name "$SCRIPT_NAME" \
      -not -path "*/3-DONE/*" -print0 2>/dev/null
  fi
)

# ── Build action plan (parallel arrays) ───────────────────────────────────────
ACTION_SRC=()
ACTION_FROM=()
ACTION_TO=()
ACTION_TYPE=()
ACTION_DAYS=()
ACTION_XREFS=()   # pipe-delimited list of files that reference each stale file
XREF_COUNT=0

for i in "${!STALE_FILES[@]}"; do
  filepath="${STALE_FILES[$i]}"
  days="${STALE_AGES[$i]}"
  filename="$(basename "$filepath")"
  dir="$(dirname "$filepath")"
  atype="$(classify_action "$filename")"

  # Nothing to rename if already P3
  [[ "$atype" == "already-p3" ]] && continue

  new_name="$(make_p3_name "$filename")"

  # Cross-reference check: find other .md files that mention this filename
  xrefs=""
  while IFS= read -r ref; do
    xrefs+="${ref}|"
  done < <(
    grep -rl --include="*.md" "$filename" "$SCRIPT_DIR" 2>/dev/null \
      | grep -v "^${filepath}$" || true
  )
  xrefs="${xrefs%|}"
  [[ -n "$xrefs" ]] && XREF_COUNT=$((XREF_COUNT + 1))

  ACTION_SRC+=("$filepath")
  ACTION_FROM+=("$filename")
  ACTION_TO+=("$new_name")
  ACTION_TYPE+=("$atype")
  ACTION_DAYS+=("$days")
  ACTION_XREFS+=("$xrefs")
done

# ── Human-readable output ─────────────────────────────────────────────────────
TOTAL_ACTIONS=${#ACTION_SRC[@]}
MODE_LABEL="DRY-RUN"; $DRY_RUN || MODE_LABEL="APPLY"

print_human_summary() {
  echo ""
  echo "=== project.sh · Phase 1 Hygiene · ${MODE_LABEL} ==="
  printf "  Scanned  : %d .md files  (threshold: %d days)\n" "$ALL_SCANNED" "$DAYS_THRESHOLD"
  printf "  Stale    : %d files\n" "${#STALE_FILES[@]}"
  printf "  Actions  : %d renames planned\n" "$TOTAL_ACTIONS"
  printf "  Xref warn: %d file(s) referenced in other docs\n" "$XREF_COUNT"
  echo ""

  if (( TOTAL_ACTIONS == 0 )); then
    echo "  ✅ All files are fresh or already P3. Nothing to do."
    return
  fi

  echo "  Planned renames:"
  for i in "${!ACTION_SRC[@]}"; do
    rel="${ACTION_SRC[$i]#"$SCRIPT_DIR/"}"
    printf "    [%s]  %s  →  %s  (%dd stale)\n" \
      "${ACTION_TYPE[$i]}" "${ACTION_FROM[$i]}" "${ACTION_TO[$i]}" "${ACTION_DAYS[$i]}"
    if [[ -n "${ACTION_XREFS[$i]}" ]]; then
      echo "    ⚠️  cross-ref in: ${ACTION_XREFS[$i]//|/, }"
    fi
  done
  echo ""
}

# ── Apply renames ─────────────────────────────────────────────────────────────
APPLIED=0; SKIPPED=0; ERRORS=0

do_apply() {
  for i in "${!ACTION_SRC[@]}"; do
    src="${ACTION_SRC[$i]}"
    dst="$(dirname "$src")/${ACTION_TO[$i]}"

    if [[ -e "$dst" ]]; then
      echo "  SKIP (target exists): ${ACTION_TO[$i]}" >&2
      SKIPPED=$((SKIPPED + 1))
      continue
    fi

    if $USE_GIT; then
      git mv "$src" "$dst" \
        && APPLIED=$((APPLIED + 1)) \
        || { echo "  ERROR: git mv failed for ${ACTION_FROM[$i]}" >&2; ERRORS=$((ERRORS + 1)); }
    else
      mv "$src" "$dst" \
        && APPLIED=$((APPLIED + 1)) \
        || { echo "  ERROR: mv failed for ${ACTION_FROM[$i]}" >&2; ERRORS=$((ERRORS + 1)); }
    fi

    $JSON_MODE || echo "  ✓  ${ACTION_FROM[$i]}  →  ${ACTION_TO[$i]}"
  done
  $JSON_MODE || echo ""
}

$DRY_RUN || do_apply

# ── Agent prompts (used by both JSON and ##AGENT-PROMPTS block) ───────────────
PROMPTS=()
if (( TOTAL_ACTIONS == 0 )); then
  PROMPTS+=("All scanned files are fresh or already P3 — no renames needed. Folder is clean.")
elif $DRY_RUN; then
  PROMPTS+=("Dry-run: ${TOTAL_ACTIONS} rename(s) planned. Run \`./PROJECT/project.sh --apply\` to apply them.")
  if (( XREF_COUNT > 0 )); then
    PROMPTS+=("⚠️  ${XREF_COUNT} file(s) have cross-references in other docs. Review before applying to avoid broken links.")
    PROMPTS+=("Phase 2 (planned): run the link-registry scan to capture and auto-update these references.")
  fi
  PROMPTS+=("Run with \`--json\` to get the full machine-readable action plan for agent orchestration.")
else
  PROMPTS+=("${APPLIED} file(s) renamed. ${SKIPPED} skipped (target already existed). ${ERRORS} error(s).")
  (( XREF_COUNT > 0 )) && \
    PROMPTS+=("⚠️  ${XREF_COUNT} renamed file(s) had cross-references — broken links may now exist. Phase 2 will repair these.")
  PROMPTS+=("Run \`git diff --name-only --cached\` to review staged renames before committing.")
fi

# ── JSON emitter ──────────────────────────────────────────────────────────────
emit_json() {
  local actions_json="[" sep=""
  for i in "${!ACTION_SRC[@]}"; do
    local rel_src xrefs_arr="" xsep=""
    rel_src="${ACTION_SRC[$i]#"$SCRIPT_DIR/"}"
    if [[ -n "${ACTION_XREFS[$i]}" ]]; then
      IFS='|' read -ra xparts <<< "${ACTION_XREFS[$i]}"
      for xp in "${xparts[@]}"; do
        xrefs_arr+="${xsep}\"$(json_str "${xp#"$SCRIPT_DIR/"}")\""
        xsep=","
      done
    fi
    actions_json+="${sep}{"
    actions_json+="\"file\":\"$(json_str "${rel_src}")\","
    actions_json+="\"from\":\"$(json_str "${ACTION_FROM[$i]}")\","
    actions_json+="\"to\":\"$(json_str "${ACTION_TO[$i]}")\","
    actions_json+="\"action\":\"${ACTION_TYPE[$i]}\","
    actions_json+="\"days_stale\":${ACTION_DAYS[$i]},"
    actions_json+="\"xrefs\":[${xrefs_arr}]}"
    sep=","
  done
  actions_json+="]"

  local prompts_json="[" psep=""
  for p in "${PROMPTS[@]}"; do
    prompts_json+="${psep}\"$(json_str "$p")\""
    psep=","
  done
  prompts_json+="]"

  cat <<JSON
{
  "tool": "project-hygiene",
  "phase": 1,
  "version": "1.0.0",
  "dry_run": $DRY_RUN,
  "config": { "threshold_days": $DAYS_THRESHOLD, "include_done": $INCLUDE_DONE, "exclude_meta": $EXCLUDE_META },
  "stats": {
    "scanned": $ALL_SCANNED,
    "stale": ${#STALE_FILES[@]},
    "actions_planned": $TOTAL_ACTIONS,
    "applied": $APPLIED,
    "skipped": $SKIPPED,
    "errors": $ERRORS,
    "xref_warnings": $XREF_COUNT
  },
  "actions": $actions_json,
  "agent_prompts": $prompts_json,
  "next_phases": [
    { "phase": 2, "name": "link-registry",  "status": "planned", "description": "Detect and record cross-references to renamed files" },
    { "phase": 3, "name": "xref-repair",    "status": "planned", "description": "Auto-update broken links via search-and-replace" },
    { "phase": 4, "name": "mcp-adapter",    "status": "planned", "description": "MCP server for continuous folder hygiene orchestration" }
  ]
}
JSON
}

# ── Route output ──────────────────────────────────────────────────────────────
if $JSON_MODE; then
  emit_json
else
  print_human_summary
  echo "##AGENT-CONTEXT"
  emit_json
  echo "##END-AGENT-CONTEXT"
  echo ""
  echo "##AGENT-PROMPTS"
  for p in "${PROMPTS[@]}"; do echo "- $p"; done
  echo "##END-AGENT-PROMPTS"
fi

# ── Exit codes ────────────────────────────────────────────────────────────────
# 0 = nothing to do · 1 = stale found, dry-run · 2 = renames applied · 99 = error
(( ERRORS > 0 ))      && exit 99
! $DRY_RUN && (( APPLIED > 0 )) && exit 2
(( TOTAL_ACTIONS > 0 )) && exit 1
exit 0
