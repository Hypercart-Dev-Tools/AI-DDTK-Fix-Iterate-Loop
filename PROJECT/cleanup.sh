#!/usr/bin/env bash
# =============================================================================
# cleanup.sh — PROJECT folder hygiene · Phases 0–4 + repo-case + secrets + scrub
# version 1.8 - attn: update this number as improvements are added
# =============================================================================
# Phase 0 (auto):    pre-check git cleanliness + zip backup before mutations.
# Phase 1 (default): scan .md files stale >N days → add/downgrade P3 prefix.
# Phase 2 (scan):    extract all markdown links, build bidirectional registry,
#                    detect broken links, save .xref-registry.json.
# Phase 3 (meta):    enforce frontmatter metadata on every project doc.
# Phase 4 (promote): detect done/misplaced docs → recommend folder moves.
# Secrets (secrets): detect accidentally committed credentials, IPs, keys, tokens.
# Scrub (scrub):     redact client/project names using external .scrub-list.json.
#
# AI AGENT HOOKS
#   --json      Emit structured JSON to stdout for agent/MCP consumption
#   Exit codes  Phase 0: 0=clean · 1=dirty (blocked --apply) · 99=error
#               Phase 1: 0=clean · 1=stale found · 2=applied · 99=error
#               Phase 2: 0=clean · 1=broken links found · 99=error
#               Phase 3: 0=clean · 1=gaps found · 2=applied · 99=error
#               Phase 4: 0=clean · 1=moves recommended · 2=applied · 99=error
#               Secrets: 0=clean · 1=findings detected · 99=error
#               Scrub:   0=clean · 1=matches found (dry-run) · 2=applied · 99=error
#   Always emits ##AGENT-CONTEXT and ##AGENT-PROMPTS blocks at end of stdout.
#
# PHASE 0 — Pre-check (runs automatically before every phase)
#   Checks for uncommitted/unpushed changes. On --apply, creates a zip backup
#   of PROJECT/ under temp/ and blocks if git is dirty (use --force to bypass).
#
# USAGE — Phase 1 (prefix hygiene)
#   ./PROJECT/cleanup.sh                    # dry-run — safe default, no writes
#   ./PROJECT/cleanup.sh --apply            # rename files (git mv when in repo)
#   ./PROJECT/cleanup.sh --apply --force    # apply even if git is dirty
#   ./PROJECT/cleanup.sh --json             # structured JSON output only
#   ./PROJECT/cleanup.sh --days 14          # custom stale threshold (default: 8)
#   ./PROJECT/cleanup.sh --include-done     # also scan the 3-DONE/ subfolder
#   ./PROJECT/cleanup.sh --no-exclude-meta  # include DOCS-INSTRUCTIONS.md
#
# USAGE — Phase 2 (cross-reference registry)
#   ./PROJECT/cleanup.sh scan               # build .xref-registry.json + report
#   ./PROJECT/cleanup.sh scan --check       # report only, no file written
#   ./PROJECT/cleanup.sh scan --json        # JSON registry to stdout only
#
# USAGE — Phase 3 (frontmatter enforcement)
#   ./PROJECT/cleanup.sh meta               # dry-run — report missing/incomplete
#   ./PROJECT/cleanup.sh meta --apply       # inject/normalize frontmatter
#   ./PROJECT/cleanup.sh meta --json        # structured JSON report only
#   ./PROJECT/cleanup.sh meta --include-done # also scan 3-DONE/ subfolder
#
# USAGE — Phase 4 (folder promotion / demotion)
#   ./PROJECT/cleanup.sh promote            # dry-run — recommend folder moves
#   ./PROJECT/cleanup.sh promote --apply    # execute moves (git mv when in repo)
#   ./PROJECT/cleanup.sh promote --json     # structured JSON report only
#
# USAGE — Repo Case (repo-wide lowercase filename normalization)
#   ./PROJECT/cleanup.sh uppercase          # dry-run — find lowercase *.md/*.txt across repo
#   ./PROJECT/cleanup.sh uppercase --apply  # rename to UPPERCASE.md / UPPERCASE.txt
#   ./PROJECT/cleanup.sh uppercase --json   # structured JSON action plan only
#
# USAGE — Secrets (detect accidentally committed credentials & secrets)
#   ./PROJECT/cleanup.sh secrets            # scan repo for secrets — report only
#   ./PROJECT/cleanup.sh secrets --json     # structured JSON report only
#   ./PROJECT/cleanup.sh secrets --project-only  # limit scan to PROJECT/ folder
#
# USAGE — Scrub (redact client/project names from documents)
#   ./PROJECT/cleanup.sh scrub-intake       # print reusable intake questions before scrub runs
#   ./PROJECT/cleanup.sh scrub-intake --json # structured intake prompt payload for agents
#   ./PROJECT/cleanup.sh scrub              # dry-run — report matches, no changes
#   ./PROJECT/cleanup.sh scrub --apply      # replace matches in-place + log to .scrub-log.jsonl
#   ./PROJECT/cleanup.sh scrub --json       # structured JSON report only
#   ./PROJECT/cleanup.sh scrub --path ./src # limit scan to a specific subfolder
#   Scrub list: PROJECT/.scrub-list.json (gitignored — contains real client names)
#   Revert log: PROJECT/.scrub-log.jsonl (gitignored — append-only change history)
#
# USAGE — Portable Doc (embed the executable script into CLEANUP.md)
#   ./PROJECT/cleanup.sh portable-doc         # print a portable CLEANUP.md to stdout
#   ./PROJECT/cleanup.sh portable-doc --apply # update CLEANUP.md with embedded script appendix
#
# PHASE ROADMAP
#   Phase 0 (this) — pre-check: git cleanliness gate + zip backup
#   Phase 1 (this) — scan + P3 prefix/downgrade, xref warnings, agent hooks
#   Phase 2 (this) — cross-reference registry: detect and record broken links
#   Phase 3 (this) — enforce frontmatter metadata on every project doc
#   Phase 4 (this) — detect done/misplaced docs, recommend folder moves
#   Secrets (this) — detect credentials, IPs, API keys, tokens in tracked files
#   Scrub   (this) — redact client/project names using external .scrub-list.json
#   Phase 5        — git/CHANGELOG correlation for activity detection
#   Phase 6        — MCP server adapter for continuous hygiene orchestration
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
COMMAND="hygiene"       # hygiene (Phase 1) | scan (Phase 2) | meta (Phase 3) | promote (Phase 4) | uppercase | secrets | scrub-intake | scrub | portable-doc
SECRETS_PROJECT_ONLY=false  # secrets: limit scan to PROJECT/ folder only
SCRUB_PATH=""               # scrub: optional subfolder path to limit scan scope
DAYS_THRESHOLD=8
DRY_RUN=true
JSON_MODE=false
INCLUDE_DONE=false
EXCLUDE_META=true       # skip meta-docs like DOCS-INSTRUCTIONS.md by default
SCAN_CHECK_ONLY=false   # Phase 2: report without writing registry file
FORCE=false             # Phase 0: bypass git-dirty gate on --apply

# ── Arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    scan)              COMMAND="scan" ;;
    meta)              COMMAND="meta" ;;
    promote)           COMMAND="promote" ;;
    uppercase)         COMMAND="uppercase" ;;
    secrets)           COMMAND="secrets" ;;
    scrub-intake)      COMMAND="scrub-intake" ;;
    scrub)             COMMAND="scrub" ;;
    portable-doc)      COMMAND="portable-doc" ;;
    --apply)           DRY_RUN=false ;;
    --force)           FORCE=true ;;
    --check)           SCAN_CHECK_ONLY=true ;;
    --project-only)    SECRETS_PROJECT_ONLY=true ;;
    --path)
      [[ -d "${2:-}" ]] || { echo "ERROR: --path requires a valid directory" >&2; exit 99; }
      SCRUB_PATH="$(cd "$2" && pwd)"; shift ;;
    --json)            JSON_MODE=true ;;
    --include-done)    INCLUDE_DONE=true ;;
    --no-exclude-meta) EXCLUDE_META=false ;;
    --days)
      [[ "${2:-}" =~ ^[0-9]+$ ]] || { echo "ERROR: --days requires a positive integer" >&2; exit 99; }
      DAYS_THRESHOLD="$2"; shift ;;
    --help|-h)
      sed -n '/^# USAGE/,/^# PHASE/p' "$0" | sed 's/^# \?//' | grep -v '^$' | head -30
      exit 0 ;;
    *) echo "ERROR: Unknown argument: $1 (try --help)" >&2; exit 99 ;;
  esac
  shift
done

DOC_PATH="$SCRIPT_DIR/2-WORKING/CLEANUP.md"
PORTABLE_SECTION_START="<!-- PORTABLE-SCRIPT:SECTION-START -->"
PORTABLE_SECTION_END="<!-- PORTABLE-SCRIPT:SECTION-END -->"

render_portable_doc() {
  python3 - "$DOC_PATH" "$0" "$PORTABLE_SECTION_START" "$PORTABLE_SECTION_END" <<'PYEOF'
from pathlib import Path
import sys

doc_path = Path(sys.argv[1])
script_path = Path(sys.argv[2])
section_start = sys.argv[3]
section_end = sys.argv[4]

doc_text = doc_path.read_text()
script_text = script_path.read_text()

section_body = (
    f"{section_start}\n"
    "```bash\n"
    f"{script_text.rstrip()}\n"
    "```\n"
    f"{section_end}"
)

if section_start in doc_text and section_end in doc_text:
    before, remainder = doc_text.split(section_start, 1)
    _, after = remainder.split(section_end, 1)
    sys.stdout.write(before.rstrip() + "\n\n" + section_body + after)
    raise SystemExit(0)

anchor = "## Open Questions"
if anchor not in doc_text:
    raise SystemExit("Portable doc anchor not found in CLEANUP.md")

insert_at = doc_text.index(anchor)
portable_section = (
    "## Portable Script\n\n"
    "This appendix is generated from `PROJECT/cleanup.sh`. Refresh it with `./PROJECT/cleanup.sh portable-doc --apply` when the script changes so the document can travel as a one-file artifact.\n\n"
    f"{section_body}\n\n"
)
sys.stdout.write(doc_text[:insert_at].rstrip() + "\n\n" + portable_section + doc_text[insert_at:])
PYEOF
}

write_portable_doc() {
  local tmp_file=""

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/cleanup-portable-XXXXXX")" || exit 99
  render_portable_doc > "$tmp_file"
  mv "$tmp_file" "$DOC_PATH"
}

if [[ "$COMMAND" == "portable-doc" ]]; then
  if $DRY_RUN; then
    render_portable_doc
  else
    write_portable_doc
    if $JSON_MODE; then
      printf '{"tool":"project-cleanup","command":"portable-doc","updated":"%s"}\n' "$DOC_PATH"
    else
      echo "Updated $DOC_PATH with embedded cleanup.sh appendix."
    fi
  fi
  exit 0
fi

print_scrub_intake() {
  local prompt_text
  prompt_text=$(cat <<'EOF'
Before I run cleanup redaction, supply the protected terms for this repo.

Please fill in any that apply:
- Client names:
- Project, product, or brand names:
- Domains, subdomains, or hostnames tied to that client/project:
- Filenames or directory names that include those identifiers:
- Preferred replacement tokens if you do not want the defaults:

Default replacement tokens:
- [CLIENT]
- [PROJECT]
- [CLIENT-DOMAIN]
- [CLIENT-FILE]

Notes:
- Include alternate spellings, acronyms, and lowercase/slug variants if they matter.
- If you are unsure, I can do a best-effort scan first, but I will treat that as a review queue rather than auto-apply truth.
- Filename renames are reviewed separately from content replacements because they may affect links, imports, or external integrations.
EOF
)

  if $JSON_MODE; then
    python3 - <<'PYEOF'
import json

payload = {
    "tool": "project-scrub-intake",
    "phase": "scrub-intake",
    "version": "1.0.0",
    "questions": [
        {"id": "client_names", "label": "Client names", "placeholder": "Acme Corp, Acme Health"},
        {"id": "project_names", "label": "Project, product, or brand names", "placeholder": "Northstar, CarePortal"},
        {"id": "domains", "label": "Domains, subdomains, or hostnames", "placeholder": "acmehealth.com, portal.acmehealth.test"},
        {"id": "filenames", "label": "Filenames or directory names with client/project identifiers", "placeholder": "Acme-export.csv, acme-client-notes.md"},
        {"id": "replacements", "label": "Preferred replacement tokens", "placeholder": "[CLIENT], [PROJECT], [CLIENT-DOMAIN], [CLIENT-FILE]"},
    ],
    "defaults": {
        "client": "[CLIENT]",
        "project": "[PROJECT]",
        "domain": "[CLIENT-DOMAIN]",
        "filename": "[CLIENT-FILE]",
    },
    "prompt_template": "Before I run cleanup redaction, supply the protected terms for this repo. Fill in: client names; project, product, or brand names; domains, subdomains, or hostnames; filenames or directory names that include those identifiers; preferred replacement tokens if you do not want the defaults.",
}
print(json.dumps(payload, indent=2))
PYEOF
    return 0
  fi

  echo ""
  echo "=== project.sh · Scrub Intake Prompt ==="
  echo "$prompt_text"
  echo ""
  echo "##AGENT-PROMPTS"
  echo "- Ask the user for protected client, project, hostname, and filename terms before running scrub."
  echo "- Use default replacement tokens unless the user supplies alternatives."
  echo "- Treat filename renames as a reviewed step separate from content replacement."
  echo "##END-AGENT-PROMPTS"
}

if [[ "$COMMAND" == "scrub-intake" ]]; then
  print_scrub_intake
  exit 0
fi

# ── Git detection ─────────────────────────────────────────────────────────────
USE_GIT=false
git -C "$SCRIPT_DIR" rev-parse --git-dir &>/dev/null 2>&1 && USE_GIT=true || true

# ── Phase 0: pre-check — git cleanliness + zip backup ───────────────────────
# Runs automatically before every phase. Warns on dry-run, blocks on --apply.
REPO_ROOT=""
$USE_GIT && REPO_ROOT=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)

phase0_scope_root() {
  if [[ "$COMMAND" == "uppercase" ]] && [[ -n "$REPO_ROOT" ]]; then
    printf '%s\n' "$REPO_ROOT"
  else
    printf '%s\n' "$SCRIPT_DIR"
  fi
}

phase0_scope_label() {
  if [[ "$COMMAND" == "uppercase" ]]; then
    printf '%s\n' "repo"
  else
    printf '%s\n' "PROJECT/"
  fi
}

phase0_scope_pathspec() {
  local scope_root
  scope_root="$(phase0_scope_root)"
  if [[ -n "$REPO_ROOT" && "$scope_root" == "$REPO_ROOT" ]]; then
    printf '%s\n' "."
  elif [[ -n "$REPO_ROOT" ]]; then
    printf '%s/\n' "${scope_root#"$REPO_ROOT/"}"
  fi
}

phase0_check() {
  local has_uncommitted=false
  local has_unpushed=false
  local has_untracked=false
  local uncommitted_count=0
  local unpushed_count=0
  local untracked_count=0

  if ! $USE_GIT; then
    # Not a git repo — skip git checks, still do zip backup on --apply
    return 0
  fi

  local scope_root scope_label scope_pathspec
  scope_root="$(phase0_scope_root)"
  scope_label="$(phase0_scope_label)"
  scope_pathspec="$(phase0_scope_pathspec)"

  # Check for uncommitted changes (staged + unstaged) in the active mutation scope
  uncommitted_count=$(git -C "$REPO_ROOT" diff --name-only -- "$scope_pathspec" 2>/dev/null | wc -l | tr -d ' ')
  local staged_count
  staged_count=$(git -C "$REPO_ROOT" diff --cached --name-only -- "$scope_pathspec" 2>/dev/null | wc -l | tr -d ' ')
  uncommitted_count=$((uncommitted_count + staged_count))
  (( uncommitted_count > 0 )) && has_uncommitted=true

  # Check for untracked files in the active mutation scope
  untracked_count=$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "$scope_pathspec" 2>/dev/null | wc -l | tr -d ' ')
  (( untracked_count > 0 )) && has_untracked=true

  # Check for unpushed commits on current branch
  local branch
  branch=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  if [[ -n "$branch" ]] && git -C "$REPO_ROOT" rev-parse --verify "origin/$branch" &>/dev/null; then
    unpushed_count=$(git -C "$REPO_ROOT" rev-list "origin/$branch..HEAD" 2>/dev/null | wc -l | tr -d ' ')
    (( unpushed_count > 0 )) && has_unpushed=true
  fi

  local is_dirty=false
  ($has_uncommitted || $has_untracked || $has_unpushed) && is_dirty=true

  # ── Build Phase 0 result ─────────────────────────────────────────────────
  local p0_json
  p0_json=$(cat <<JSONEOF
{
  "tool": "project-precheck",
  "phase": 0,
  "version": "1.0.0",
  "git": {
    "dirty": $is_dirty,
    "uncommitted_changes": $uncommitted_count,
    "untracked_files": $untracked_count,
    "unpushed_commits": $unpushed_count,
    "branch": "$branch"
  }
}
JSONEOF
  )

  # ── Human / agent output ─────────────────────────────────────────────────
  if $is_dirty; then
    local p0_prompts=()
    $has_uncommitted && p0_prompts+=("${uncommitted_count} uncommitted change(s) in ${scope_label} — commit before running --apply for accurate detection.")
    $has_untracked   && p0_prompts+=("${untracked_count} untracked file(s) in ${scope_label} — consider adding them to git.")
    $has_unpushed    && p0_prompts+=("${unpushed_count} unpushed commit(s) on branch '$branch' — push to preserve your work before mutations.")
    p0_prompts+=("Ask the user to commit and push, then re-run. Use --force to bypass this check.")

    if ! $JSON_MODE; then
      echo ""
      echo "=== project.sh · Phase 0 Pre-Check ==="
      printf "  Scope       : %s\n" "$scope_label"
      $has_uncommitted && printf "  Uncommitted : %d change(s) in %s\n" "$uncommitted_count" "$scope_label"
      $has_untracked   && printf "  Untracked   : %d file(s) in %s\n" "$untracked_count" "$scope_label"
      $has_unpushed    && printf "  Unpushed    : %d commit(s) on '%s'\n" "$unpushed_count" "$branch"
      echo ""
    fi

    # On --apply without --force: block execution
    if ! $DRY_RUN && ! $FORCE; then
      if ! $JSON_MODE; then
        echo "  BLOCKED: --apply requires a clean git state. Commit and push first, or use --force."
        echo ""
        echo "##AGENT-CONTEXT"
        echo "$p0_json"
        echo "##END-AGENT-CONTEXT"
        echo ""
        echo "##AGENT-PROMPTS"
        for p in "${p0_prompts[@]}"; do echo "- $p"; done
        echo "##END-AGENT-PROMPTS"
      else
        echo "$p0_json"
      fi
      exit 1
    fi

    # On dry-run or --force: warn and continue
    if ! $JSON_MODE; then
      if $DRY_RUN; then
        echo "  (dry-run — continuing with warning)"
      else
        echo "  (--force specified — continuing despite dirty state)"
      fi
      echo ""
    fi
  else
    $JSON_MODE || true  # silent pass on clean state
  fi

  return 0
}

# Create timestamped zip backup before any --apply mutation
phase0_backup() {
  if $DRY_RUN; then return 0; fi

  local backup_root
  backup_root="$(phase0_scope_root)"
  local backup_dir
  if [[ -n "$REPO_ROOT" ]]; then
    backup_dir="$REPO_ROOT/temp"
  else
    backup_dir="$SCRIPT_DIR/../temp"
  fi
  mkdir -p "$backup_dir"

  local timestamp
  timestamp=$(date +%Y-%m-%d-%H%M%S)
  local zip_name="project-backup-${timestamp}.zip"
  local zip_path="$backup_dir/$zip_name"

  local backup_label backup_target
  if [[ "$backup_root" == "$REPO_ROOT" ]] && [[ -n "$REPO_ROOT" ]]; then
    backup_label="repo"
    backup_target="."
  else
    backup_label="$(basename "$backup_root")"
    backup_target="$(basename "$backup_root")"
  fi

  # Zip the active mutation scope, excluding generated or heavy directories
  if command -v zip &>/dev/null; then
    (
      cd "${REPO_ROOT:-"$SCRIPT_DIR/.."}" && zip -rq "$zip_path" "$backup_target" \
        -x "*/.git/*" "*/node_modules/*" "*/temp/*" "*/.DS_Store" "*/.*" 2>/dev/null
    ) || true
    if [[ -f "$zip_path" ]]; then
      $JSON_MODE || echo "  Backup: $zip_name ($(du -h "$zip_path" | cut -f1)) [${backup_label}]"
      $JSON_MODE || echo ""
    fi
  else
    $JSON_MODE || echo "  Backup: skipped (zip not available)"
    $JSON_MODE || echo ""
  fi
}

# Run Phase 0
phase0_check
phase0_backup

# ── Helpers ───────────────────────────────────────────────────────────────────

# Remove ALL leading P[0-9]- prefixes — prevents P3-P3-P3- accumulation
strip_priority_prefix() {
  local n="$1"
  while [[ "$n" =~ ^[Pp][0-9]- ]]; do n="${n:3}"; done
  echo "$n"
}

make_p3_name() { echo "P3-$(strip_priority_prefix "$1")"; }

upper_ascii() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]'
}

lower_ascii() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

rename_with_case_support() {
  local src="$1"
  local dst="$2"
  local src_folded dst_folded tmp_dst

  src_folded="$(lower_ascii "$src")"
  dst_folded="$(lower_ascii "$dst")"

  if [[ "$src_folded" == "$dst_folded" ]]; then
    tmp_dst="${dst}.tmp-case-rename-$$"
    if $USE_GIT; then
      git mv "$src" "$tmp_dst" && git mv "$tmp_dst" "$dst"
    else
      mv "$src" "$tmp_dst" && mv "$tmp_dst" "$dst"
    fi
  else
    if $USE_GIT; then
      git mv "$src" "$dst"
    else
      mv "$src" "$dst"
    fi
  fi
}

# Returns: already-p3 | downgrade | add-prefix
classify_action() {
  local name="$1"
  if   [[ "$name" =~ ^P3- ]]; then echo "already-p3"
  elif [[ "$name" =~ ^P[12]- ]]; then echo "downgrade"
  else echo "add-prefix"
  fi
}

# JSON string escaper — handles backslash, quotes, newlines, tabs, and control chars
# Uses python3 for reliable cross-platform JSON escaping
json_str() {
  printf '%s' "$1" | python3 -c "import json,sys; sys.stdout.write(json.dumps(sys.stdin.read())[1:-1])" 2>/dev/null \
    || printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# Returns file age in whole days; -1 means "skip" (dirty/unreadable).
# Priority: git log commit timestamp (tracked+clean) → mtime (fallback).
# Dirty files (modified or staged but not committed) are never considered stale.
get_file_age() {
  local filepath="$1" ts=""
  if $USE_GIT; then
    ts=$(git -C "$SCRIPT_DIR" log -1 --format="%ct" -- "$filepath" 2>/dev/null || true)
    if [[ -n "$ts" ]]; then
      # File is git-tracked; treat as not-stale if it has uncommitted changes
      if ! git -C "$SCRIPT_DIR" diff --quiet -- "$filepath" 2>/dev/null ||
         ! git -C "$SCRIPT_DIR" diff --cached --quiet -- "$filepath" 2>/dev/null; then
        echo "-1"; return   # dirty — actively being edited
      fi
      echo $(( (NOW - ts) / 86400 )); return
    fi
    # Untracked file — fall through to mtime
  fi
  # Fallback: portable mtime (macOS stat -f %m · Linux stat -c %Y)
  if ts=$(stat -f %m "$filepath" 2>/dev/null); then :
  else ts=$(stat -c %Y "$filepath" 2>/dev/null) || { echo "-1"; return; }
  fi
  echo $(( (NOW - ts) / 86400 ))
}

# ── Phase 2: cross-reference registry ─────────────────────────────────────────
run_scan() {
  command -v python3 &>/dev/null || { echo "ERROR: python3 is required for 'scan' (Phase 2)" >&2; exit 99; }

  local registry_file="$SCRIPT_DIR/.xref-registry.json"

  # Build registry via Python — handles link extraction, resolution, and JSON
  local py_result
  py_result=$(SCAN_ROOT="$SCRIPT_DIR" python3 - <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone

scan_root = os.environ['SCAN_ROOT']
link_re   = re.compile(r'\[([^\]]*)\]\(([^)]+)\)')
md_files  = []

for root, dirs, files in os.walk(scan_root):
    dirs[:] = sorted(d for d in dirs if not d.startswith('.'))
    for fname in sorted(files):
        if fname.endswith('.md'):
            md_files.append(os.path.join(root, fname))

registry  = {}   # rel_path -> {links, referenced_by}
broken    = []

MAX_FILE_SIZE = 1_048_576  # 1 MB — skip oversized files to avoid memory issues

for filepath in md_files:
    rel = os.path.relpath(filepath, scan_root)
    links = []
    try:
        if os.path.getsize(filepath) > MAX_FILE_SIZE:
            registry[rel] = {'links': [], 'referenced_by': [], 'skipped': 'file too large'}
            continue
        with open(filepath, 'r', errors='replace') as fh:
            for lineno, line in enumerate(fh, 1):
                for m in link_re.finditer(line):
                    text, target = m.group(1), m.group(2)
                    # Only local .md refs; skip http/https/anchors-only
                    if target.startswith(('http://', 'https://', '#')):
                        continue
                    # Strip fragment (#section) for existence check
                    target_path = target.split('#')[0]
                    if not target_path.endswith('.md'):
                        continue
                    file_dir     = os.path.dirname(filepath)
                    resolved_abs = os.path.normpath(os.path.join(file_dir, target_path))
                    resolved_rel = os.path.relpath(resolved_abs, scan_root)
                    exists       = os.path.isfile(resolved_abs)
                    link_entry   = {
                        'line': lineno, 'text': text, 'target': target,
                        'resolved': resolved_rel, 'exists': exists, 'raw': m.group(0)
                    }
                    links.append(link_entry)
                    if not exists:
                        broken.append({'in_file': rel, 'line': lineno, 'text': text,
                                       'target': target, 'resolved': resolved_rel,
                                       'raw': m.group(0)})
    except OSError:
        pass
    registry[rel] = {'links': links, 'referenced_by': []}

# Build incoming refs (referenced_by) from outgoing links
for rel, info in registry.items():
    for lnk in info['links']:
        target_rel = lnk['resolved']
        if target_rel in registry and rel not in registry[target_rel]['referenced_by']:
            registry[target_rel]['referenced_by'].append(rel)

total_links = sum(len(v['links']) for v in registry.values())
result = {
    'tool': 'project-xref-registry',
    'phase': 2,
    'version': '1.0.0',
    'generated_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'scan_root': os.path.basename(scan_root) + '/',
    'stats': {
        'files_scanned': len(registry),
        'total_links': total_links,
        'broken_links': len(broken)
    },
    'files': registry,
    'broken_links': broken
}
print(json.dumps(result, indent=2))
PYEOF
  ) || { echo "ERROR: registry build failed" >&2; exit 99; }

  local broken_count files_count total_links
  broken_count=$(echo "$py_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['broken_links'])")
  files_count=$(echo "$py_result"  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['files_scanned'])")
  total_links=$(echo "$py_result"  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['total_links'])")

  # ── Persist registry ──────────────────────────────────────────────────────
  if ! $SCAN_CHECK_ONLY && ! $JSON_MODE; then
    echo "$py_result" > "$registry_file"
  fi

  # ── Agent prompts ─────────────────────────────────────────────────────────
  local prompts=()
  if (( broken_count == 0 )); then
    prompts+=("Registry built: ${files_count} files, ${total_links} links, 0 broken. All links resolve correctly.")
  else
    prompts+=("⚠️  ${broken_count} broken link(s) found across ${files_count} files. Review 'broken_links' in the registry.")
    prompts+=("Phase 3 (planned): run auto-repair to rewrite broken links via search-and-replace.")
  fi
  $SCAN_CHECK_ONLY && prompts+=("Check-only mode: registry NOT written to disk. Run without --check to save.")
  ! $SCAN_CHECK_ONLY && ! $JSON_MODE && prompts+=("Registry saved to: $(basename "$registry_file")")
  prompts+=("Run \`./PROJECT/cleanup.sh scan --json\` to get the full machine-readable registry for agent use.")

  # ── Route output ──────────────────────────────────────────────────────────
  if $JSON_MODE; then
    echo "$py_result"
  else
    echo ""
    echo "=== project.sh · Phase 2 Cross-Reference Registry ==="
    printf "  Files scanned : %s\n" "$files_count"
    printf "  Total links   : %s\n" "$total_links"
    printf "  Broken links  : %s\n" "$broken_count"
    $SCAN_CHECK_ONLY && echo "  Mode          : check-only (registry not written)"
    $SCAN_CHECK_ONLY || echo "  Registry      : .xref-registry.json"
    echo ""
    if (( broken_count > 0 )); then
      echo "  Broken links:"
      echo "$py_result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for b in d['broken_links']:
    print(f\"    [{b['in_file']}:{b['line']}]  {b['raw']}  → not found: {b['resolved']}\")
"
      echo ""
    fi
    echo "##AGENT-CONTEXT"
    echo "$py_result"
    echo "##END-AGENT-CONTEXT"
    echo ""
    echo "##AGENT-PROMPTS"
    for p in "${prompts[@]}"; do echo "- $p"; done
    echo "##END-AGENT-PROMPTS"
  fi

  (( broken_count > 0 )) && exit 1 || exit 0
}

# ── Phase 3: frontmatter enforcement ─────────────────────────────────────────
run_meta() {
  command -v python3 &>/dev/null || { echo "ERROR: python3 is required for 'meta' (Phase 3)" >&2; exit 99; }

  # Collect .md files to scan (respects --include-done and --no-exclude-meta)
  local md_files=()
  while IFS= read -r -d '' filepath; do
    local fname; fname="$(basename "$filepath")"
    if $EXCLUDE_META && [[ "$fname" == "DOCS-INSTRUCTIONS.md" ]]; then continue; fi
    # Skip non-project docs (SERVERS-GCP etc. are handled if in subfolders)
    md_files+=("$filepath")
  done < <(
    if $INCLUDE_DONE; then
      find "$SCRIPT_DIR" -name "*.md" -not -name "$SCRIPT_NAME" -print0 2>/dev/null
    else
      find "$SCRIPT_DIR" -name "*.md" -not -name "$SCRIPT_NAME" \
        -not -path "*/3-DONE/*" -print0 2>/dev/null
    fi
  )

  # Build file list as JSON array for Python
  local files_json="[" fsep=""
  for f in "${md_files[@]}"; do
    files_json+="${fsep}\"$(json_str "$f")\""
    fsep=","
  done
  files_json+="]"

  # Git dates: build a map of file → {first_commit_date, last_commit_date, author}
  # Uses Python to collect git data in bulk and produce valid JSON safely
  local git_dates_json="{}"
  if $USE_GIT; then
    git_dates_json=$(GIT_DIR="$SCRIPT_DIR" python3 -c "
import json, os, subprocess, sys

files = json.loads(os.environ['FILES_JSON'])
git_dir = os.environ['GIT_DIR']
result = {}

def git_query(args, f):
    return subprocess.run(
        ['git', '-C', git_dir] + args + ['--', f],
        capture_output=True, text=True, timeout=10
    ).stdout.strip()

for f in files:
    try:
        first_line = git_query(['log', '--diff-filter=A', '--follow', '--format=%ai'], f)
        first = first_line.split('\n')[-1] if first_line else ''
        last = git_query(['log', '-1', '--format=%ai'], f)
        author_line = git_query(['log', '--diff-filter=A', '--follow', '--format=%an'], f)
        author = author_line.split('\n')[-1] if author_line else ''
        result[f] = {
            'created': first[:10] if first else '',
            'updated': last[:10] if last else '',
            'author': author
        }
    except Exception:
        pass

print(json.dumps(result))
" 2>/dev/null) || git_dates_json="{}"
  fi

  local py_result
  py_result=$(FILES_JSON="$files_json" GIT_DATES="$git_dates_json" SCAN_ROOT="$SCRIPT_DIR" \
    DRY_RUN="$DRY_RUN" python3 - <<'PYEOF'
import json, os, re, sys
from datetime import date

scan_root  = os.environ['SCAN_ROOT']
files      = json.loads(os.environ['FILES_JSON'])
git_dates  = json.loads(os.environ.get('GIT_DATES', '{}'))
dry_run    = os.environ.get('DRY_RUN', 'true') == 'true'

REQUIRED_FIELDS = ['title', 'status', 'priority', 'created', 'updated', 'author', 'goal']

# ── Folder → status mapping ────────────────────────────────────────────────
def infer_status(filepath):
    rel = os.path.relpath(filepath, scan_root)
    if rel.startswith('1-INBOX'):   return 'inbox'
    if rel.startswith('2-WORKING'): return 'working'
    if rel.startswith('3-DONE'):    return 'done'
    if rel.startswith('4-MISC'):    return 'misc'
    return 'inbox'

# ── Filename → priority ────────────────────────────────────────────────────
def infer_priority(filepath):
    fname = os.path.basename(filepath)
    m = re.match(r'^[Pp]([123])-', fname)
    return f'P{m.group(1)}' if m else 'P3'

# ── First heading → title ──────────────────────────────────────────────────
def infer_title(filepath, content):
    for line in content.split('\n'):
        m = re.match(r'^#{1,2}\s+(.+)', line)
        if m:
            # Strip leading emoji (common in these docs)
            title = re.sub(r'^[\U0001f300-\U0001f9ff\u2600-\u27bf]+\s*', '', m.group(1)).strip()
            return title
    # Fallback: clean filename
    fname = os.path.basename(filepath).replace('.md', '')
    fname = re.sub(r'^[Pp][0-9]-', '', fname)
    return fname.replace('-', ' ').title()

# ── Parse existing frontmatter ─────────────────────────────────────────────
def parse_frontmatter(content):
    """Returns (dict_of_fields, body_after_frontmatter, had_frontmatter)."""
    if not content.startswith('---'):
        return {}, content, False
    end = content.find('\n---', 3)
    if end == -1:
        return {}, content, False
    fm_block = content[3:end].strip()
    body = content[end+4:].lstrip('\n')
    fields = {}
    for line in fm_block.split('\n'):
        m = re.match(r'^(\w[\w_-]*)\s*:\s*(.*?)$', line)
        if m:
            key = m.group(1).lower().strip()
            val = m.group(2).strip().strip('"').strip("'")
            fields[key] = val
    return fields, body, True

# ── Normalize existing field names to canonical ────────────────────────────
FIELD_ALIASES = {
    'date': 'created',
    'category': None,      # drop — not in canonical schema
    'project': None,       # drop — redundant (always AI-DDTK in this repo)
    'parent': None,        # drop — not in canonical schema
    'source': None,        # drop
    'reviewer': None,      # drop
}

def normalize_fields(fields):
    """Map old field names to canonical ones."""
    out = {}
    for k, v in fields.items():
        canon = FIELD_ALIASES.get(k, k)  # None means drop
        if canon is not None:
            out[canon] = v
    return out

# ── Normalize status values ────────────────────────────────────────────────
STATUS_MAP = {
    'inbox': 'inbox', 'in_progress': 'working', 'in progress': 'working',
    'active': 'working', 'working': 'working', 'paused': 'paused',
    'done': 'done', 'completed': 'done', 'misc': 'misc',
    'partially in progress': 'working',
    'paused after phase 1 and 2 completed': 'paused',
}

def normalize_status(val, filepath):
    low = val.lower().strip()
    return STATUS_MAP.get(low, infer_status(filepath))

# ── Build frontmatter string ──────────────────────────────────────────────
def build_frontmatter(fields):
    lines = ['---']
    for key in REQUIRED_FIELDS:
        val = fields.get(key, '')
        if ' ' in val or ':' in val or '"' in val:
            lines.append(f'{key}: "{val}"')
        else:
            lines.append(f'{key}: {val}')
    lines.append('---')
    return '\n'.join(lines)

# ── Process each file ──────────────────────────────────────────────────────
results = []
applied_count = 0
gap_count = 0

for filepath in sorted(files):
    rel = os.path.relpath(filepath, scan_root)
    try:
        with open(filepath, 'r', errors='replace') as fh:
            content = fh.read()
    except OSError:
        results.append({'file': rel, 'status': 'error', 'message': 'Could not read file'})
        continue

    existing, body, had_fm = parse_frontmatter(content)
    existing = normalize_fields(existing)

    # Git-derived dates and author
    gd = git_dates.get(filepath, {})

    # Build canonical fields, preferring existing values
    canonical = {}
    canonical['title']    = existing.get('title', infer_title(filepath, body))
    raw_status            = existing.get('status', '')
    canonical['status']   = normalize_status(raw_status, filepath) if raw_status else infer_status(filepath)
    canonical['priority'] = existing.get('priority', infer_priority(filepath))
    canonical['created']  = existing.get('created', gd.get('created', str(date.today())))
    canonical['updated']  = existing.get('updated', gd.get('updated', str(date.today())))
    canonical['author']   = existing.get('author') or gd.get('author') or 'noelsaw'
    canonical['goal']     = existing.get('goal', '')

    # Normalize priority format (e.g. "high" → P1)
    prio = canonical['priority'].upper().strip()
    if prio in ('HIGH', 'P1'): canonical['priority'] = 'P1'
    elif prio in ('MEDIUM', 'MED', 'P2'): canonical['priority'] = 'P2'
    else: canonical['priority'] = 'P3'

    # Truncate dates to YYYY-MM-DD
    for dk in ('created', 'updated'):
        canonical[dk] = canonical[dk][:10] if canonical[dk] else str(date.today())

    # Detect missing fields
    missing = [k for k in REQUIRED_FIELDS if not canonical.get(k)]
    # goal is allowed to be empty (we won't count it as "missing" for gap detection)
    missing_required = [k for k in missing if k != 'goal']

    # Compare only canonical fields to detect if update is needed
    fields_match = had_fm and all(existing.get(k) == canonical.get(k) for k in REQUIRED_FIELDS)
    needs_update = not had_fm or missing_required or not fields_match

    entry = {
        'file': rel,
        'had_frontmatter': had_fm,
        'missing_fields': missing_required,
        'canonical': canonical,
        'needs_update': needs_update,
    }

    if needs_update:
        gap_count += 1
        if not dry_run:
            new_fm = build_frontmatter(canonical)
            new_content = new_fm + '\n\n' + body
            try:
                with open(filepath, 'w') as fh:
                    fh.write(new_content)
                entry['applied'] = True
                applied_count += 1
            except OSError as e:
                entry['applied'] = False
                entry['error'] = str(e)

    results.append(entry)

output = {
    'tool': 'project-meta',
    'phase': 3,
    'version': '1.0.0',
    'dry_run': dry_run,
    'stats': {
        'files_scanned': len(results),
        'with_frontmatter': sum(1 for r in results if r.get('had_frontmatter')),
        'missing_frontmatter': sum(1 for r in results if not r.get('had_frontmatter')),
        'needs_update': gap_count,
        'applied': applied_count,
    },
    'files': results,
}
print(json.dumps(output, indent=2))
PYEOF
  ) || { echo "ERROR: meta analysis failed" >&2; exit 99; }

  local files_scanned with_fm missing_fm needs_update applied
  files_scanned=$(echo "$py_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['files_scanned'])")
  with_fm=$(echo "$py_result"       | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['with_frontmatter'])")
  missing_fm=$(echo "$py_result"    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['missing_frontmatter'])")
  needs_update=$(echo "$py_result"  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['needs_update'])")
  applied=$(echo "$py_result"       | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['applied'])")

  # ── Agent prompts ──────────────────────────────────────────────────────────
  local prompts=()
  if (( needs_update == 0 )); then
    prompts+=("All ${files_scanned} files have complete, canonical frontmatter. Nothing to do.")
  elif $DRY_RUN; then
    prompts+=("${needs_update} of ${files_scanned} file(s) need frontmatter updates. Run \`./PROJECT/cleanup.sh meta --apply\` to fix them.")
    (( missing_fm > 0 )) && prompts+=("${missing_fm} file(s) have no frontmatter at all — they will get a full block injected.")
    prompts+=("Review the 'files' array in JSON output for per-file details.")
  else
    prompts+=("${applied} file(s) updated with canonical frontmatter.")
    prompts+=("Run \`git diff\` to review the changes before committing.")
  fi

  # ── Route output ───────────────────────────────────────────────────────────
  if $JSON_MODE; then
    echo "$py_result"
  else
    local mode_label="DRY-RUN"; $DRY_RUN || mode_label="APPLY"
    echo ""
    echo "=== project.sh · Phase 3 Frontmatter Enforcement · ${mode_label} ==="
    printf "  Files scanned   : %s\n" "$files_scanned"
    printf "  Has frontmatter : %s\n" "$with_fm"
    printf "  Missing entirely: %s\n" "$missing_fm"
    printf "  Needs update    : %s\n" "$needs_update"
    $DRY_RUN || printf "  Applied         : %s\n" "$applied"
    echo ""

    if (( needs_update > 0 )); then
      echo "  Files needing updates:"
      echo "$py_result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for f in d['files']:
    if not f.get('needs_update'): continue
    tag = 'NO-FM' if not f['had_frontmatter'] else 'UPDATE'
    missing = ', '.join(f.get('missing_fields', [])) or 'normalization only'
    applied = ' ✓ applied' if f.get('applied') else ''
    print(f'    [{tag}]  {f[\"file\"]}  — {missing}{applied}')
"
      echo ""
    else
      echo "  ✅ All files have complete, canonical frontmatter."
      echo ""
    fi

    echo "##AGENT-CONTEXT"
    echo "$py_result"
    echo "##END-AGENT-CONTEXT"
    echo ""
    echo "##AGENT-PROMPTS"
    for p in "${prompts[@]}"; do echo "- $p"; done
    echo "##END-AGENT-PROMPTS"
  fi

  # ── Exit codes ──────────────────────────────────────────────────────────────
  ! $DRY_RUN && (( applied > 0 )) && exit 2
  (( needs_update > 0 )) && exit 1
  exit 0
}

# ── Phase 4: folder promotion / demotion ─────────────────────────────────────
run_promote() {
  command -v python3 &>/dev/null || { echo "ERROR: python3 is required for 'promote' (Phase 4)" >&2; exit 99; }

  # Collect all .md files across 1-INBOX, 2-WORKING, 4-MISC (not 3-DONE — those are done)
  local md_files=()
  while IFS= read -r -d '' filepath; do
    local fname; fname="$(basename "$filepath")"
    # Skip meta docs and blanks
    if [[ "$fname" == "DOCS-INSTRUCTIONS.md" || "$fname" == "blank.md" ]]; then continue; fi
    md_files+=("$filepath")
  done < <(
    find "$SCRIPT_DIR" -name "*.md" -not -name "$SCRIPT_NAME" \
      -not -path "*/3-DONE/*" -print0 2>/dev/null
  )

  # Build file list JSON
  local files_json="[" fsep=""
  for f in "${md_files[@]}"; do
    files_json+="${fsep}\"$(json_str "$f")\""
    fsep=","
  done
  files_json+="]"

  # Git staleness: days since last commit touching each file
  # Uses Python to collect git timestamps in bulk and produce valid JSON safely
  local git_stale_json="{}"
  if $USE_GIT; then
    git_stale_json=$(GIT_DIR="$SCRIPT_DIR" python3 -c "
import json, os, subprocess, time, sys

files = json.loads(os.environ['FILES_JSON'])
git_dir = os.environ['GIT_DIR']
now_ts = int(time.time())
result = {}

for f in files:
    try:
        out = subprocess.run(
            ['git', '-C', git_dir, 'log', '-1', '--format=%ct', '--', f],
            capture_output=True, text=True, timeout=10
        ).stdout.strip()
        if out:
            days = (now_ts - int(out)) // 86400
        else:
            days = -1
        result[f] = days
    except Exception:
        result[f] = -1

print(json.dumps(result))
" 2>/dev/null) || git_stale_json="{}"
  fi

  local py_result
  py_result=$(FILES_JSON="$files_json" GIT_STALE="$git_stale_json" SCAN_ROOT="$SCRIPT_DIR" \
    DRY_RUN="$DRY_RUN" USE_GIT="$USE_GIT" python3 - <<'PYEOF'
import json, os, re, sys

scan_root  = os.environ['SCAN_ROOT']
files      = json.loads(os.environ['FILES_JSON'])
git_stale  = json.loads(os.environ.get('GIT_STALE', '{}'))
dry_run    = os.environ.get('DRY_RUN', 'true') == 'true'
use_git    = os.environ.get('USE_GIT', 'false') == 'true'

# ── Folder detection ──────────────────────────────────────────────────────
def current_folder(filepath):
    rel = os.path.relpath(filepath, scan_root)
    parts = rel.split(os.sep)
    return parts[0] if len(parts) > 1 else '_root'

def target_folder_for_status(status):
    return {
        'inbox': '1-INBOX', 'working': '2-WORKING', 'paused': '2-WORKING',
        'done': '3-DONE', 'misc': '4-MISC',
    }.get(status, '1-INBOX')

# ── Parse frontmatter ────────────────────────────────────────────────────
def parse_frontmatter(content):
    if not content.startswith('---'):
        return {}
    end = content.find('\n---', 3)
    if end == -1:
        return {}
    fields = {}
    for line in content[3:end].strip().split('\n'):
        m = re.match(r'^(\w[\w_-]*)\s*:\s*(.*?)$', line)
        if m:
            fields[m.group(1).lower().strip()] = m.group(2).strip().strip('"').strip("'")
    return fields

# ── Checklist analysis ───────────────────────────────────────────────────
def analyze_checklist(content):
    checked   = len(re.findall(r'- \[x\]', content, re.IGNORECASE))
    unchecked = len(re.findall(r'- \[ \]', content))
    total = checked + unchecked
    ratio = checked / total if total > 0 else None
    return {'checked': checked, 'unchecked': unchecked, 'total': total, 'ratio': ratio}

# ── Score a file for "done-ness" ─────────────────────────────────────────
# Returns: score 0-100, reason string, recommended action
def score_file(filepath, fm, checklist, stale_days):
    score = 0
    reasons = []
    status = fm.get('status', '').lower()

    # Signal 1: frontmatter status (strongest signal — explicit human intent)
    if status == 'done':
        score += 50
        reasons.append('status=done (+50)')
    elif status == 'paused':
        score += 10
        reasons.append('status=paused (+10)')
    elif status in ('working', 'inbox'):
        score += 0

    # Signal 2: checklist completion ratio
    if checklist['total'] > 0:
        r = checklist['ratio']
        if r == 1.0:
            score += 30
            reasons.append(f'checklist 100% ({checklist["checked"]}/{checklist["total"]}) (+30)')
        elif r >= 0.9:
            score += 20
            reasons.append(f'checklist {r:.0%} ({checklist["checked"]}/{checklist["total"]}) (+20)')
        elif r >= 0.7:
            score += 5
            reasons.append(f'checklist {r:.0%} ({checklist["checked"]}/{checklist["total"]}) (+5)')
        else:
            reasons.append(f'checklist {r:.0%} ({checklist["checked"]}/{checklist["total"]}) (+0)')

    # Signal 3: staleness (days since last git commit)
    if stale_days >= 0:
        if stale_days >= 30:
            score += 15
            reasons.append(f'{stale_days}d stale (+15)')
        elif stale_days >= 14:
            score += 10
            reasons.append(f'{stale_days}d stale (+10)')
        elif stale_days >= 7:
            score += 5
            reasons.append(f'{stale_days}d stale (+5)')
        else:
            reasons.append(f'{stale_days}d stale (+0)')

    return score, reasons

# ── Determine recommended move ───────────────────────────────────────────
def recommend_move(filepath, fm, score, checklist):
    cur = current_folder(filepath)
    status = fm.get('status', '').lower()

    # Case 1: Done candidate (high score in WORKING or INBOX)
    if score >= 60 and cur in ('2-WORKING', '1-INBOX'):
        return '3-DONE', 'done-candidate'

    # Case 2: Status says done but file isn't in 3-DONE
    if status == 'done' and cur != '3-DONE':
        return '3-DONE', 'status-mismatch'

    # Case 3: Status says working but file is in INBOX
    # (capacity check is done after all recommendations are collected)
    if status == 'working' and cur == '1-INBOX':
        return '2-WORKING', 'activate-candidate'

    # Case 4: Status says paused, high completion, stale → done candidate
    if status == 'paused' and score >= 50 and checklist['ratio'] is not None and checklist['ratio'] >= 0.9:
        return '3-DONE', 'paused-but-complete'

    # Case 5: Status says inbox/misc but file is in WORKING (shouldn't be active)
    if status in ('inbox', 'misc') and cur == '2-WORKING':
        target = '1-INBOX' if status == 'inbox' else '4-MISC'
        return target, 'demote-candidate'

    return None, 'no-move'

# ── Process each file ────────────────────────────────────────────────────
results = []
moves = []

for filepath in sorted(files):
    rel = os.path.relpath(filepath, scan_root)
    try:
        with open(filepath, 'r', errors='replace') as fh:
            content = fh.read()
    except OSError:
        results.append({'file': rel, 'error': 'Could not read file'})
        continue

    fm = parse_frontmatter(content)
    checklist = analyze_checklist(content)
    stale_days = git_stale.get(filepath, -1)
    score, reasons = score_file(filepath, fm, checklist, stale_days)
    target, move_type = recommend_move(filepath, fm, score, checklist)

    entry = {
        'file': rel,
        'current_folder': current_folder(filepath),
        'status': fm.get('status', ''),
        'priority': fm.get('priority', ''),
        'score': score,
        'reasons': reasons,
        'checklist': checklist,
        'stale_days': stale_days,
        'move': None,
    }

    if target:
        move_entry = {
            'file': rel,
            'from_folder': current_folder(filepath),
            'to_folder': target,
            'type': move_type,
            'score': score,
            'src': filepath,
            'dst': os.path.join(scan_root, target, os.path.basename(filepath)),
        }
        entry['move'] = {
            'to_folder': target,
            'type': move_type,
        }
        moves.append(move_entry)

    results.append(entry)

# ── Apply moves ──────────────────────────────────────────────────────────
applied = 0
errors = 0
skipped = 0

if not dry_run:
    for mv in moves:
        dst = mv['dst']
        # Ensure target directory exists
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.exists(dst):
            mv['result'] = 'skipped'
            skipped += 1
            continue
        # Moves are done via git mv in the shell wrapper; here we just record intent
        mv['result'] = 'pending-shell'
        applied += 1

# ── Capacity check: max 3 in 2-WORKING per DOCS-INSTRUCTIONS ─────────
WORKING_MAX = 3
current_in_working = sum(1 for f in files if os.path.relpath(f, scan_root).startswith('2-WORKING'))
incoming_to_working = sum(1 for m in moves if m['to_folder'] == '2-WORKING')
leaving_working = sum(1 for m in moves if m['from_folder'] == '2-WORKING')
projected_working = current_in_working + incoming_to_working - leaving_working
capacity_warning = None
if projected_working > WORKING_MAX:
    capacity_warning = (
        f'2-WORKING would have {projected_working} files after moves '
        f'(max {WORKING_MAX} per DOCS-INSTRUCTIONS). '
        f'Consider triaging before applying.'
    )

output = {
    'tool': 'project-promote',
    'phase': 4,
    'version': '1.0.0',
    'dry_run': dry_run,
    'stats': {
        'files_scanned': len(results),
        'moves_recommended': len(moves),
        'applied': applied,
        'skipped': skipped,
        'errors': errors,
        'working_current': current_in_working,
        'working_projected': projected_working,
        'working_max': WORKING_MAX,
    },
    'capacity_warning': capacity_warning,
    'moves': moves,
    'files': results,
}
print(json.dumps(output, indent=2))
PYEOF
  ) || { echo "ERROR: promote analysis failed" >&2; exit 99; }

  local files_scanned moves_recommended
  files_scanned=$(echo "$py_result"      | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['files_scanned'])")
  moves_recommended=$(echo "$py_result"  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['moves_recommended'])")

  # ── Apply moves via shell (git mv or mv) ─────────────────────────────────
  local applied=0 skipped=0 errors=0
  if ! $DRY_RUN && (( moves_recommended > 0 )); then
    while IFS= read -r move_line; do
      local src dst to_folder move_type
      src=$(echo "$move_line"       | python3 -c "import json,sys; m=json.load(sys.stdin); print(m['src'])")
      dst=$(echo "$move_line"       | python3 -c "import json,sys; m=json.load(sys.stdin); print(m['dst'])")
      to_folder=$(echo "$move_line" | python3 -c "import json,sys; m=json.load(sys.stdin); print(m['to_folder'])")
      move_type=$(echo "$move_line" | python3 -c "import json,sys; m=json.load(sys.stdin); print(m['type'])")

      # Ensure target dir exists
      mkdir -p "$(dirname "$dst")"

      if [[ -e "$dst" ]]; then
        $JSON_MODE || echo "  SKIP (target exists): $(basename "$dst") → $to_folder/" >&2
        skipped=$((skipped + 1))
        continue
      fi

      if $USE_GIT; then
        git mv "$src" "$dst" \
          && applied=$((applied + 1)) \
          || { echo "  ERROR: git mv failed for $(basename "$src")" >&2; errors=$((errors + 1)); }
      else
        mv "$src" "$dst" \
          && applied=$((applied + 1)) \
          || { echo "  ERROR: mv failed for $(basename "$src")" >&2; errors=$((errors + 1)); }
      fi

      $JSON_MODE || echo "  ✓  $(basename "$src")  →  $to_folder/"
    done < <(echo "$py_result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for m in d['moves']:
    print(json.dumps(m))
")
    $JSON_MODE || echo ""
  fi

  # ── Capacity warning ────────────────────────────────────────────────────────
  local capacity_warning
  capacity_warning=$(echo "$py_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('capacity_warning') or '')")

  # ── Agent prompts ──────────────────────────────────────────────────────────
  local prompts=()
  if (( moves_recommended == 0 )); then
    prompts+=("All ${files_scanned} files are in their correct folders. Nothing to move.")
  elif $DRY_RUN; then
    prompts+=("${moves_recommended} folder move(s) recommended. Run \`./PROJECT/cleanup.sh promote --apply\` to execute them.")
    [[ -n "$capacity_warning" ]] && prompts+=("⚠️  $capacity_warning")
    prompts+=("Review the 'moves' array in JSON output for per-file details and scores.")
  else
    prompts+=("${applied} file(s) moved. ${skipped} skipped (target existed). ${errors} error(s).")
    (( applied > 0 )) && prompts+=("Run \`git diff --name-only --cached\` to review staged moves before committing.")
  fi

  # ── Route output ───────────────────────────────────────────────────────────
  if $JSON_MODE; then
    echo "$py_result"
  else
    local mode_label="DRY-RUN"; $DRY_RUN || mode_label="APPLY"
    echo ""
    echo "=== project.sh · Phase 4 Folder Promotion · ${mode_label} ==="
    printf "  Files scanned : %s\n" "$files_scanned"
    printf "  Moves planned : %s\n" "$moves_recommended"
    $DRY_RUN || printf "  Applied       : %s\n" "$applied"
    echo ""

    if [[ -n "$capacity_warning" ]]; then
      echo "  ⚠️  $capacity_warning"
      echo ""
    fi

    if (( moves_recommended > 0 )); then
      echo "  Recommended moves:"
      echo "$py_result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for m in d['moves']:
    print(f'    [{m[\"type\"]}]  {m[\"file\"]}  →  {m[\"to_folder\"]}/  (score: {m[\"score\"]})')
"
      echo ""
      echo "  Score breakdown (all files):"
      echo "$py_result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for f in d['files']:
    move_tag = ''
    if f.get('move'):
        move_tag = f'  → {f[\"move\"][\"to_folder\"]}/'
    cl = f['checklist']
    cl_str = f'{cl[\"checked\"]}/{cl[\"total\"]}' if cl['total'] > 0 else 'n/a'
    print(f'    {f[\"file\"]:45s}  score={f[\"score\"]:3d}  status={f[\"status\"]:8s}  checklist={cl_str:6s}  stale={f[\"stale_days\"]}d{move_tag}')
"
      echo ""
    else
      echo "  ✅ All files are in their correct folders. Nothing to move."
      echo ""
    fi

    echo "##AGENT-CONTEXT"
    echo "$py_result"
    echo "##END-AGENT-CONTEXT"
    echo ""
    echo "##AGENT-PROMPTS"
    for p in "${prompts[@]}"; do echo "- $p"; done
    echo "##END-AGENT-PROMPTS"
  fi

  # ── Exit codes ──────────────────────────────────────────────────────────────
  (( errors > 0 ))      && exit 99
  ! $DRY_RUN && (( applied > 0 )) && exit 2
  (( moves_recommended > 0 )) && exit 1
  exit 0
}

# ── Secrets: detect accidentally committed credentials & secrets ──────────────
run_secrets() {
  command -v python3 &>/dev/null || { echo "ERROR: python3 is required for 'secrets'" >&2; exit 99; }

  local scan_root
  if $SECRETS_PROJECT_ONLY; then
    scan_root="$SCRIPT_DIR"
  else
    scan_root="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
  fi

  # Load allowlist (one literal string per line, # comments)
  local allowlist_file="$SCRIPT_DIR/.secrets-allowlist"
  local allowlist_json="[]"
  if [[ -f "$allowlist_file" ]]; then
    allowlist_json=$(python3 -c "
import json, sys
lines = []
for line in open(sys.argv[1]):
    line = line.strip()
    if line and not line.startswith('#'):
        lines.append(line)
print(json.dumps(lines))
" "$allowlist_file" 2>/dev/null || echo "[]")
  fi

  local py_result
  py_result=$(SCAN_ROOT="$scan_root" ALLOWLIST="$allowlist_json" python3 - <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone

scan_root = os.environ['SCAN_ROOT']
allowlist = json.loads(os.environ.get('ALLOWLIST', '[]'))

# ── Directories and extensions to skip ────────────────────────────────────
SKIP_DIRS = {'.git', 'node_modules', 'temp', '__pycache__', 'vendor',
             '.venv', 'venv', '.tox', '.mypy_cache', '.pytest_cache'}

BINARY_EXT = {
    '.png', '.jpg', '.jpeg', '.gif', '.ico', '.bmp', '.svg', '.webp',
    '.woff', '.woff2', '.ttf', '.eot', '.otf',
    '.zip', '.gz', '.tar', '.bz2', '.xz', '.7z', '.rar',
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    '.mp3', '.mp4', '.mov', '.avi', '.mkv', '.wav', '.flac',
    '.exe', '.dll', '.so', '.dylib', '.pyc', '.pyo', '.class', '.o',
    '.wasm', '.map', '.min.js', '.min.css',
}

# ── Pattern definitions ───────────────────────────────────────────────────
# Each: (id, severity, compiled_regex, human_description)
RAW_PATTERNS = [
    # ── Critical: provider-specific tokens (almost always real) ───────────
    ('aws-access-key',     'critical', r'(?<![A-Z0-9])AKIA[0-9A-Z]{16}(?![A-Z0-9])',   'AWS Access Key ID'),
    ('private-key',        'critical', r'-----BEGIN\s+(?:RSA\s+|EC\s+|DSA\s+|OPENSSH\s+|PGP\s+)?PRIVATE KEY-----', 'Private Key Block'),
    ('github-pat',         'critical', r'(?<![A-Za-z0-9_])gh[ps]_[A-Za-z0-9_]{36,}',     'GitHub Personal Access Token'),
    ('github-fine-pat',    'critical', r'(?<![A-Za-z0-9_])github_pat_[A-Za-z0-9_]{22,}',  'GitHub Fine-Grained PAT'),
    ('slack-token',        'critical', r'(?<![A-Za-z0-9_])xox[bpors]-[A-Za-z0-9\-]{10,}', 'Slack Token'),
    ('stripe-secret',      'critical', r'(?<![A-Za-z0-9_])sk_live_[0-9a-zA-Z]{24,}',     'Stripe Secret Key'),
    ('google-api-key',     'critical', r'(?<![A-Za-z0-9_])AIza[0-9A-Za-z_\-]{35}',       'Google API Key'),
    ('anthropic-key',      'critical', r'(?<![A-Za-z0-9_])sk-ant-[A-Za-z0-9_\-]{20,}',   'Anthropic API Key'),
    ('openai-key',         'critical', r'(?<![A-Za-z0-9_])sk-[A-Za-z0-9]{40,}',          'OpenAI API Key'),
    ('sendgrid-key',       'critical', r'(?<![A-Za-z0-9_])SG\.[A-Za-z0-9_\-]{22,}\.[A-Za-z0-9_\-]{22,}', 'SendGrid API Key'),
    ('twilio-key',         'critical', r'(?<![A-Za-z0-9_])SK[0-9a-fA-F]{32}',            'Twilio API Key'),

    # ── High: generic credential patterns ─────────────────────────────────
    ('stripe-publishable', 'high',     r'(?<![A-Za-z0-9_])pk_live_[0-9a-zA-Z]{24,}',     'Stripe Publishable Key (live)'),
    ('password-assign',    'high',     r'(?i)(password|passwd|pwd|secret)\s*[:=]\s*[\x22\x27]?[^\s\x22\x27#]{8,}', 'Password / Secret Assignment'),
    ('connection-string',  'high',     r'(?i)(mysql|postgres(?:ql)?|mongodb(\+srv)?|redis|amqp)://[^\s\x22\x27]+@[^\s\x22\x27<>]+', 'Database Connection String'),
    ('bearer-token',       'high',     r'(?i)bearer\s+[A-Za-z0-9\-._~+/]{20,}=*',        'Bearer Token'),
    ('basic-auth-header',  'high',     r'(?i)authorization:\s*basic\s+[A-Za-z0-9+/]{20,}={0,2}', 'Basic Auth Header'),
    ('wp-auth-keys',       'high',     r'(?i)define\s*\(\s*[\x22\x27](?:AUTH_KEY|SECURE_AUTH_KEY|LOGGED_IN_KEY|NONCE_KEY|AUTH_SALT|SECURE_AUTH_SALT|LOGGED_IN_SALT|NONCE_SALT)[\x22\x27]\s*,\s*[\x22\x27][^\x22\x27]{20,}[\x22\x27]\s*\)', 'WordPress Auth Key/Salt'),

    # ── Medium: may be intentional in docs, but worth flagging ────────────
    ('generic-secret',     'medium',   r'(?i)(api[_-]?key|api[_-]?secret|access[_-]?token|secret[_-]?key|client[_-]?secret)\s*[:=]\s*[\x22\x27]?[A-Za-z0-9_\-./+]{16,}', 'Generic API Key / Secret'),
    ('ip-address',         'medium',   r'\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\b', 'IP Address'),
    ('internal-hostname',  'medium',   r'\b[a-zA-Z0-9][\w.-]*\.(?:internal|corp|staging|prod)\b', 'Internal Hostname'),
    ('env-file-content',   'medium',   r'^[A-Z][A-Z0-9_]{2,}=\S{12,}$',                  'Env-style Variable with Long Value'),
]

PATTERNS = [(pid, sev, re.compile(pat), desc) for pid, sev, pat, desc in RAW_PATTERNS]

# ── False-positive filters ────────────────────────────────────────────────
SAFE_IPS = {
    '0.0.0.0', '127.0.0.1', '255.255.255.255', '255.255.255.0',
    '0.0.0.1', '1.0.0.1', '1.1.1.1', '8.8.8.8', '8.8.4.4',
    '224.0.0.1',
}

# Patterns that look like IPs but are version strings (e.g. v1.2.3.4)
VERSION_CONTEXT_RE = re.compile(r'(?:v(?:ersion)?\s*\.?\s*|@)\d')

# Lines that are clearly documentation/examples
DOC_HINT_RE = re.compile(r'(?i)(example|placeholder|dummy|your[_-]?key|replace[_-]?with|xxx|changeme|TODO|FIXME|sample)')

def is_allowlisted(matched_text):
    for entry in allowlist:
        if entry in matched_text:
            return True
    return False

def should_skip(pid, matched_text, line, filepath):
    """Return True if this match is a known false positive."""
    if is_allowlisted(matched_text):
        return True

    rel = os.path.relpath(filepath, scan_root)

    # Skip matches inside this script itself
    if rel.endswith('project.sh'):
        return True

    # IP-specific filters
    if pid == 'ip-address':
        ip = matched_text
        if ip in SAFE_IPS:
            return True
        # Version strings: "v1.2.3.4", "version 1.2.3.4", "@1.2.3.4"
        idx = line.find(ip)
        if idx > 0 and VERSION_CONTEXT_RE.search(line[max(0, idx-12):idx]):
            return True
        # Subnet masks
        if ip.startswith('255.') or ip.endswith('.0') or ip.endswith('.255'):
            return True
        # localhost-range
        if ip.startswith('127.'):
            return True

    # env-file-content: only flag in actual env-like files
    if pid == 'env-file-content':
        fname = os.path.basename(filepath)
        if not (fname.startswith('.env') or fname.endswith('.env')
                or fname in ('env', 'environment')):
            return True

    # Doc/example hints — downgrade or skip
    if DOC_HINT_RE.search(line):
        return True

    # password-assign: skip if value looks like a variable reference ($, %, {{)
    if pid == 'password-assign':
        val_match = re.search(r'[:=]\s*[\x22\x27]?(.+?)(?:[\x22\x27]?\s*$)', matched_text)
        if val_match:
            val = val_match.group(1)
            if re.match(r'^[\$%\{]', val) or val.strip('\x22\x27') in ('', 'null', 'None', 'false', 'true'):
                return True

    # generic-secret: skip if value is a path or URL scheme
    if pid == 'generic-secret':
        if re.search(r'[:=]\s*[\x22\x27]?(?:https?://|/[a-z])', matched_text, re.I):
            return True

    return False

# ── Redact matched text ──────────────────────────────────────────────────
def redact(text, pid):
    """Show enough to identify the finding, mask the actual secret."""
    if pid == 'ip-address' or pid == 'internal-hostname':
        return text  # IPs/hosts are the finding itself, not a secret value
    if pid == 'private-key':
        return text[:40] + '...'
    if len(text) <= 12:
        return text[:3] + '****'
    return text[:6] + '****' + text[-4:]

# ── Scan files ───────────────────────────────────────────────────────────
findings = []
files_scanned = 0
files_with_findings = set()

for root, dirs, files_list in os.walk(scan_root):
    dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not d.startswith('.'))
    for fname in sorted(files_list):
        filepath = os.path.join(root, fname)
        ext = os.path.splitext(fname)[1].lower()

        # Skip binary by extension
        if ext in BINARY_EXT:
            continue
        # Skip hidden files
        if fname.startswith('.') and fname not in ('.env', '.env.local', '.env.production', '.env.staging'):
            continue
        # Skip large files (>1MB — unlikely to be hand-written)
        try:
            if os.path.getsize(filepath) > 1_048_576:
                continue
        except OSError:
            continue
        # Binary check: null bytes in first 8KB
        try:
            with open(filepath, 'rb') as bf:
                if b'\x00' in bf.read(8192):
                    continue
        except OSError:
            continue

        files_scanned += 1

        try:
            with open(filepath, 'r', errors='replace') as fh:
                for lineno, line in enumerate(fh, 1):
                    for pid, severity, regex, desc in PATTERNS:
                        for m in regex.finditer(line):
                            matched_text = m.group(0)
                            if should_skip(pid, matched_text, line, filepath):
                                continue
                            rel = os.path.relpath(filepath, scan_root)
                            files_with_findings.add(rel)
                            findings.append({
                                'file': rel,
                                'line': lineno,
                                'pattern': pid,
                                'severity': severity,
                                'description': desc,
                                'match_redacted': redact(matched_text, pid),
                                'context': line.rstrip()[:150],
                            })
        except OSError:
            continue

# ── Summarize by severity ────────────────────────────────────────────────
severity_counts = {'critical': 0, 'high': 0, 'medium': 0}
for f in findings:
    severity_counts[f['severity']] += 1

output = {
    'tool': 'project-secrets',
    'phase': 'secrets',
    'version': '1.0.0',
    'generated_at': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'scan_root': os.path.relpath(scan_root, os.getcwd()) + '/',
    'stats': {
        'files_scanned': files_scanned,
        'files_with_findings': len(files_with_findings),
        'total_findings': len(findings),
        'by_severity': severity_counts,
    },
    'findings': findings,
}
print(json.dumps(output, indent=2))
PYEOF
  ) || { echo "ERROR: secrets scan failed" >&2; exit 99; }

  local files_scanned total_findings files_with_findings
  local sev_critical sev_high sev_medium
  files_scanned=$(echo "$py_result"       | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['files_scanned'])")
  total_findings=$(echo "$py_result"      | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['total_findings'])")
  files_with_findings=$(echo "$py_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['files_with_findings'])")
  sev_critical=$(echo "$py_result"        | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['by_severity']['critical'])")
  sev_high=$(echo "$py_result"            | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['by_severity']['high'])")
  sev_medium=$(echo "$py_result"          | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['by_severity']['medium'])")

  # ── Agent prompts ──────────────────────────────────────────────────────────
  local prompts=()
  if (( total_findings == 0 )); then
    prompts+=("No secrets or credentials detected across ${files_scanned} files. Scan clean.")
  else
    (( sev_critical > 0 )) && prompts+=("CRITICAL: ${sev_critical} high-confidence secret(s) found — likely real credentials that should be removed and rotated immediately.")
    (( sev_high > 0 ))     && prompts+=("HIGH: ${sev_high} probable credential(s) found — review each for real vs placeholder values.")
    (( sev_medium > 0 ))   && prompts+=("MEDIUM: ${sev_medium} potential exposure(s) — IP addresses, internal hostnames, or generic key patterns worth reviewing.")
    prompts+=("Review findings and consider: (1) rotate any exposed credentials, (2) remove from tracked files, (3) add legitimate entries to .secrets-allowlist.")
  fi
  prompts+=("Run \`./PROJECT/cleanup.sh secrets --json\` for machine-readable output.")
  $SECRETS_PROJECT_ONLY || prompts+=("Add --project-only to limit scan to the PROJECT/ folder.")

  # ── Route output ───────────────────────────────────────────────────────────
  if $JSON_MODE; then
    echo "$py_result"
  else
    local scope_label="repo-wide"; $SECRETS_PROJECT_ONLY && scope_label="PROJECT/ only"
    echo ""
    echo "=== project.sh · Secrets Scanner ==="
    printf "  Scope           : %s\n" "$scope_label"
    printf "  Files scanned   : %s\n" "$files_scanned"
    printf "  Files w/findings: %s\n" "$files_with_findings"
    printf "  Total findings  : %s\n" "$total_findings"
    printf "  Critical        : %s\n" "$sev_critical"
    printf "  High            : %s\n" "$sev_high"
    printf "  Medium          : %s\n" "$sev_medium"
    echo ""

    if (( total_findings > 0 )); then
      echo "  Findings:"
      echo "$py_result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
prev_file = None
for f in d['findings']:
    if f['file'] != prev_file:
        if prev_file is not None:
            print()
        print(f'    {f[\"file\"]}')
        prev_file = f['file']
    sev_tag = {'critical': 'CRIT', 'high': 'HIGH', 'medium': 'MED '}[f['severity']]
    print(f'      L{f[\"line\"]:>4d}  [{sev_tag}]  {f[\"pattern\"]:22s}  {f[\"match_redacted\"]}')
"
      echo ""
    else
      echo "  No secrets or credentials detected."
      echo ""
    fi

    echo "##AGENT-CONTEXT"
    echo "$py_result"
    echo "##END-AGENT-CONTEXT"
    echo ""
    echo "##AGENT-PROMPTS"
    for p in "${prompts[@]}"; do echo "- $p"; done
    echo "##END-AGENT-PROMPTS"
  fi

  # ── Exit codes ──────────────────────────────────────────────────────────────
  (( total_findings > 0 )) && exit 1
  exit 0
}

run_scrub_intake() {
  print_scrub_intake
  exit 0
}

# ── Scrub: redact client/project names from repo documents ───────────────────
run_scrub() {
  command -v python3 &>/dev/null || { echo "ERROR: python3 is required for 'scrub'" >&2; exit 99; }

  local scrub_list="$SCRIPT_DIR/.scrub-list.json"
  local scrub_log="$SCRIPT_DIR/.scrub-log.jsonl"

  if [[ ! -f "$scrub_list" ]]; then
    cat > "$scrub_list" <<'INITEOF'
{
  "version": "1.0",
  "description": "Client and project names to redact from repository documents. THIS FILE IS GITIGNORED.",
  "terms": [
    { "pattern": "ExampleClient",     "replacement": "[CLIENT]",        "boundary": true,  "case_insensitive": true },
    { "pattern": "ExampleProject",    "replacement": "[PROJECT]",       "boundary": true,  "case_insensitive": true },
    { "pattern": "example-client.com","replacement": "[CLIENT-DOMAIN]", "boundary": false, "case_insensitive": true }
  ]
}
INITEOF
    if ! $JSON_MODE; then
      echo ""
      echo "  Initialized blank scrub list at PROJECT/.scrub-list.json"
      echo "  Edit it to add your real client/project names, then re-run."
      echo "  Tip: run ./PROJECT/cleanup.sh scrub-intake to get a reusable user-intake prompt first."
      echo ""
    fi
    exit 0
  fi

  # Determine scan root: --path overrides, else repo root, else parent of PROJECT/
  local scan_root
  if [[ -n "$SCRUB_PATH" ]]; then
    scan_root="$SCRUB_PATH"
  elif [[ -n "$REPO_ROOT" ]]; then
    scan_root="$REPO_ROOT"
  else
    scan_root="$(cd "$SCRIPT_DIR/.." && pwd)"
  fi

  local py_result
  py_result=$(SCAN_ROOT="$scan_root" SCRUB_LIST="$scrub_list" SCRUB_LOG="$scrub_log" \
    DRY_RUN="$DRY_RUN" python3 - <<'PYEOF'
import json, os, re, sys
from datetime import datetime, timezone

scan_root  = os.environ['SCAN_ROOT']
scrub_list = os.environ['SCRUB_LIST']
scrub_log  = os.environ['SCRUB_LOG']
dry_run    = os.environ['DRY_RUN'] == 'true'

# ── Load scrub list ──────────────────────────────────────────────────────
with open(scrub_list, 'r') as f:
    config = json.load(f)

terms = config.get('terms', [])
if not terms:
    print(json.dumps({
        'tool': 'project-scrub', 'phase': 'scrub', 'version': '1.0.0',
        'error': 'No terms defined in scrub list'
    }))
    sys.exit(0)

# Sort longest-first to prevent partial matches (e.g., "FooCorp.com" before "Foo")
terms.sort(key=lambda t: len(t['pattern']), reverse=True)

# ── Build compiled regex patterns ────────────────────────────────────────
compiled = []
for t in terms:
    pat = re.escape(t['pattern'])
    if t.get('boundary', True):
        pat = r'\b' + pat + r'\b'
    flags = re.IGNORECASE if t.get('case_insensitive', True) else 0
    compiled.append((re.compile(pat, flags), t['replacement'], t['pattern']))

# ── Directories and extensions to skip ───────────────────────────────────
SKIP_DIRS = {'.git', 'node_modules', 'temp', 'dist', 'build', 'vendor', '.DS_Store'}
BINARY_EXT = {
    '.png', '.jpg', '.jpeg', '.gif', '.ico', '.svg', '.webp', '.bmp',
    '.zip', '.tar', '.gz', '.bz2', '.7z', '.rar',
    '.pdf', '.doc', '.docx', '.xls', '.xlsx',
    '.woff', '.woff2', '.ttf', '.eot', '.otf',
    '.mp3', '.mp4', '.avi', '.mov', '.wav',
    '.exe', '.dll', '.so', '.dylib', '.o',
    '.pyc', '.pyo', '.class',
}

# Source code extensions: warn-only, never auto-replace
SOURCE_EXT = {
    '.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs',
    '.php', '.py', '.rb', '.go', '.rs', '.java',
    '.sh', '.bash', '.zsh', '.fish',
    '.c', '.cpp', '.h', '.hpp', '.cs',
    '.swift', '.kt', '.scala',
    '.sql', '.graphql', '.gql',
}

def is_warn_only(ext):
    """Source code files get warnings, not replacements."""
    return ext in SOURCE_EXT

# ── Scan and optionally replace ──────────────────────────────────────────
matches = []    # replaceable document matches
warnings = []   # source code warn-only matches
files_scanned = 0
files_with_matches = set()
files_with_warnings = set()
files_modified = 0
run_id = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
log_entries = []

for root, dirs, files_list in os.walk(scan_root):
    dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not d.startswith('.'))
    for fname in sorted(files_list):
        filepath = os.path.join(root, fname)
        ext = os.path.splitext(fname)[1].lower()

        # Skip the scrub list and log themselves
        if os.path.abspath(filepath) in (os.path.abspath(scrub_list), os.path.abspath(scrub_log)):
            continue
        if ext in BINARY_EXT:
            continue
        if fname.startswith('.') and ext not in ('.env', '.md', '.txt', '.yml', '.yaml'):
            continue
        try:
            if os.path.getsize(filepath) > 2_097_152:  # 2MB
                continue
        except OSError:
            continue
        # Binary check: null bytes in first 8KB
        try:
            with open(filepath, 'rb') as bf:
                if b'\x00' in bf.read(8192):
                    continue
        except OSError:
            continue

        files_scanned += 1
        warn_only = is_warn_only(ext)

        try:
            with open(filepath, 'r', errors='replace') as fh:
                lines = fh.readlines()
        except OSError:
            continue

        file_changed = False
        new_lines = []

        for lineno_idx, line in enumerate(lines):
            lineno = lineno_idx + 1
            original_line = line

            for regex, replacement, raw_pattern in compiled:
                for m in regex.finditer(line):
                    rel = os.path.relpath(filepath, scan_root)
                    entry = {
                        'file': rel,
                        'line': lineno,
                        'matched': m.group(0),
                        'pattern': raw_pattern,
                        'replacement': replacement,
                        'context': line.rstrip()[:200],
                    }
                    if warn_only:
                        files_with_warnings.add(rel)
                        entry['warn_only'] = True
                        warnings.append(entry)
                    else:
                        files_with_matches.add(rel)
                        matches.append(entry)

            # Only replace in document files, never in source code
            if warn_only:
                new_lines.append(line)
                continue

            replaced_line = line
            for regex, replacement, raw_pattern in compiled:
                replaced_line = regex.sub(replacement, replaced_line)

            if replaced_line != original_line:
                file_changed = True
                log_entries.append({
                    'run_id': run_id,
                    'file': os.path.relpath(filepath, scan_root),
                    'line': lineno,
                    'original': original_line.rstrip(),
                    'replaced': replaced_line.rstrip(),
                })

            new_lines.append(replaced_line)

        # Write back if applying and file was changed (never for warn-only)
        if not dry_run and file_changed and not warn_only:
            try:
                with open(filepath, 'w') as fh:
                    fh.writelines(new_lines)
                files_modified += 1
            except OSError as e:
                matches.append({
                    'file': os.path.relpath(filepath, scan_root),
                    'line': 0,
                    'matched': '',
                    'pattern': '',
                    'replacement': '',
                    'context': f'WRITE ERROR: {e}',
                })

# ── Write revert log ────────────────────────────────────────────────────
if not dry_run and log_entries:
    try:
        with open(scrub_log, 'a') as lf:
            for entry in log_entries:
                lf.write(json.dumps(entry) + '\n')
    except OSError:
        pass  # non-fatal — log is best-effort

# ── Build output ────────────────────────────────────────────────────────
output = {
    'tool': 'project-scrub',
    'phase': 'scrub',
    'version': '1.1.0',
    'dry_run': dry_run,
    'run_id': run_id,
    'scan_root': os.path.relpath(scan_root, os.getcwd()) + '/',
    'scrub_list': os.path.relpath(scrub_list, os.getcwd()),
    'config': {
        'terms_count': len(terms),
        'terms': [{'pattern': t['pattern'], 'replacement': t['replacement']} for t in terms],
    },
    'stats': {
        'files_scanned': files_scanned,
        'files_with_matches': len(files_with_matches),
        'total_matches': len(matches),
        'files_with_warnings': len(files_with_warnings),
        'total_warnings': len(warnings),
        'files_modified': files_modified,
        'log_entries_written': len(log_entries),
    },
    'matches': matches,
    'warnings': warnings,
}
print(json.dumps(output, indent=2))
PYEOF
  ) || { echo "ERROR: scrub scan failed" >&2; exit 99; }

  local files_scanned total_matches files_with_matches files_modified log_entries
  local total_warnings files_with_warnings
  files_scanned=$(echo "$py_result"        | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['files_scanned'])")
  total_matches=$(echo "$py_result"        | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['total_matches'])")
  files_with_matches=$(echo "$py_result"   | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['files_with_matches'])")
  total_warnings=$(echo "$py_result"       | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['total_warnings'])")
  files_with_warnings=$(echo "$py_result"  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['files_with_warnings'])")
  files_modified=$(echo "$py_result"       | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['files_modified'])")
  log_entries=$(echo "$py_result"          | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['stats']['log_entries_written'])")

  # ── Agent prompts ──────────────────────────────────────────────────────────
  local prompts=()
  if (( total_matches == 0 )) && (( total_warnings == 0 )); then
    prompts+=("No client/project names found across ${files_scanned} files. Documents are clean.")
  elif $DRY_RUN; then
    (( total_matches > 0 )) && prompts+=("Dry-run: ${total_matches} match(es) in ${files_with_matches} document file(s) will be redacted. Run \`./PROJECT/cleanup.sh scrub --apply\` to apply.")
    (( total_warnings > 0 )) && prompts+=("WARNING: ${total_warnings} match(es) in ${files_with_warnings} source code file(s). These are NOT auto-replaced — hardcoded values should be moved to config/env vars.")
    prompts+=("Review matches carefully before applying — replacements are logged to .scrub-log.jsonl for revert capability.")
  else
    (( files_modified > 0 )) && prompts+=("${files_modified} document file(s) modified. ${log_entries} replacement(s) logged to .scrub-log.jsonl for revert capability.")
    (( total_warnings > 0 )) && prompts+=("WARNING: ${total_warnings} match(es) in ${files_with_warnings} source code file(s) were NOT replaced. Hardcoded client names in code should be moved to config/env vars.")
    (( files_modified > 0 )) && prompts+=("Run \`git diff\` to review all changes before committing.")
  fi
  prompts+=("Scrub list: PROJECT/.scrub-list.json (gitignored). Edit to add/remove terms.")
  [[ -n "$SCRUB_PATH" ]] || prompts+=("Use --path <dir> to limit the scan to a specific subfolder.")

  # ── Route output ───────────────────────────────────────────────────────────
  if $JSON_MODE; then
    echo "$py_result"
  else
    local scope_label="repo-wide"; [[ -n "$SCRUB_PATH" ]] && scope_label="$SCRUB_PATH"
    echo ""
    echo "=== project.sh · Scrub (Client/Project Name Redaction) ==="
    printf "  Scope            : %s\n" "$scope_label"
    printf "  Scrub list       : PROJECT/.scrub-list.json (%d terms)\n" "$(echo "$py_result" | python3 -c "import json,sys; print(json.load(sys.stdin)['config']['terms_count'])")"
    printf "  Files scanned    : %s\n" "$files_scanned"
    echo ""
    printf "  Documents        : %s match(es) in %s file(s) [replaceable]\n" "$total_matches" "$files_with_matches"
    printf "  Source code      : %s match(es) in %s file(s) [warn-only]\n" "$total_warnings" "$files_with_warnings"
    if ! $DRY_RUN; then
      printf "  Files modified   : %s\n" "$files_modified"
      printf "  Log entries      : %s\n" "$log_entries"
    fi
    echo ""

    if (( total_matches > 0 )); then
      echo "  Document matches (will be replaced on --apply):"
      echo "$py_result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
prev_file = None
for m in d['matches']:
    if m['file'] != prev_file:
        if prev_file is not None:
            print()
        print(f'    {m[\"file\"]}')
        prev_file = m['file']
    print(f'      L{m[\"line\"]:>4d}  {m[\"matched\"]:20s}  ->  {m[\"replacement\"]}')
"
      echo ""
    fi

    if (( total_warnings > 0 )); then
      echo "  Source code warnings (NOT replaced — move to config/env vars):"
      echo "$py_result" | python3 -c "
import json, sys
d = json.load(sys.stdin)
prev_file = None
for w in d['warnings']:
    if w['file'] != prev_file:
        if prev_file is not None:
            print()
        print(f'    {w[\"file\"]}')
        prev_file = w['file']
    print(f'      L{w[\"line\"]:>4d}  {w[\"matched\"]:20s}  !!  hardcoded in source')
"
      echo ""
    fi

    if (( total_matches == 0 )) && (( total_warnings == 0 )); then
      echo "  No client/project names detected. Documents are clean."
      echo ""
    fi

    echo "##AGENT-CONTEXT"
    echo "$py_result"
    echo "##END-AGENT-CONTEXT"
    echo ""
    echo "##AGENT-PROMPTS"
    for p in "${prompts[@]}"; do echo "- $p"; done
    echo "##END-AGENT-PROMPTS"
  fi

  # ── Exit codes ──────────────────────────────────────────────────────────────
  # 0 = clean · 1 = matches found (dry-run) · 2 = applied · 99 = error
  ! $DRY_RUN && (( files_modified > 0 )) && exit 2
  (( total_matches > 0 )) && exit 1
  exit 0
}

# ── Route to Phase 2/3/4/secrets/scrub early if subcommand matches ───────────
[[ "$COMMAND" == "scan" ]]    && run_scan
[[ "$COMMAND" == "meta" ]]    && run_meta
[[ "$COMMAND" == "promote" ]] && run_promote
[[ "$COMMAND" == "secrets" ]] && run_secrets
[[ "$COMMAND" == "scrub-intake" ]] && run_scrub_intake
[[ "$COMMAND" == "scrub" ]]   && run_scrub
 
run_uppercase() {
  local scan_root
  scan_root="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

  ACTION_SRC=()
  ACTION_FROM=()
  ACTION_TO=()
  ACTION_TYPE=()
  ACTION_DAYS=()
  ACTION_XREFS=()
  XREF_COUNT=0

  local scanned=0
  local matched=0

  while IFS= read -r -d '' filepath; do
    local filename stem ext new_name xrefs=""
    filename="$(basename "$filepath")"
    ext="${filename##*.}"
    stem="${filename%.*}"
    scanned=$((scanned + 1))

    if [[ ! "$filename" =~ ^[a-z0-9][a-z0-9._-]*\.(md|txt)$ ]]; then
      continue
    fi
    local upper_stem
    upper_stem="$(upper_ascii "$stem")"
    if [[ "$stem" != "$upper_stem" ]]; then
      new_name="${upper_stem}.${ext}"
    else
      continue
    fi

    matched=$((matched + 1))

    while IFS= read -r ref; do
      xrefs+="${ref}|"
    done < <(
      grep -rIlF --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir="temp" \
        --include="*.md" --include="*.txt" -- "$filename" "$scan_root" 2>/dev/null \
        | grep -v "^${filepath}$" || true
    )
    xrefs="${xrefs%|}"
    [[ -n "$xrefs" ]] && XREF_COUNT=$((XREF_COUNT + 1))

    ACTION_SRC+=("$filepath")
    ACTION_FROM+=("$filename")
    ACTION_TO+=("$new_name")
    ACTION_TYPE+=("uppercase")
    ACTION_DAYS+=("0")
    ACTION_XREFS+=("$xrefs")
  done < <(
    find "$scan_root" \
      -path "*/.git" -prune -o \
      -path "*/node_modules" -prune -o \
      -path "*/temp" -prune -o \
      -type f \( -name "*.md" -o -name "*.txt" \) -print0 2>/dev/null
  )

  TOTAL_ACTIONS=${#ACTION_SRC[@]}
  MODE_LABEL="DRY-RUN"; $DRY_RUN || MODE_LABEL="APPLY"
  APPLIED=0; SKIPPED=0; ERRORS=0

  print_uppercase_summary() {
    echo ""
    echo "=== project.sh · Repo Case · ${MODE_LABEL} ==="
    printf "  Root     : %s\n" "$scan_root"
    printf "  Scanned  : %d .md/.txt files\n" "$scanned"
    printf "  Matches  : %d lowercase filename(s)\n" "$matched"
    printf "  Actions  : %d renames planned\n" "$TOTAL_ACTIONS"
    printf "  Xref warn: %d file(s) referenced in other text docs\n" "$XREF_COUNT"
    echo ""

    if (( TOTAL_ACTIONS == 0 )); then
      echo "  All matching filenames already use uppercase basenames. Nothing to do."
      return
    fi

    echo "  Planned renames:"
    for i in "${!ACTION_SRC[@]}"; do
      local rel
      rel="${ACTION_SRC[$i]#"$scan_root/"}"
      printf "    %s  →  %s\n" "$rel" "${ACTION_TO[$i]}"
      if [[ -n "${ACTION_XREFS[$i]}" ]]; then
        echo "    cross-ref in: ${ACTION_XREFS[$i]//|/, }"
      fi
    done
    echo ""
  }

  do_uppercase_apply() {
    for i in "${!ACTION_SRC[@]}"; do
      local src dst
      src="${ACTION_SRC[$i]}"
      dst="$(dirname "$src")/${ACTION_TO[$i]}"

      if [[ -e "$dst" ]] && [[ "$(lower_ascii "$src")" != "$(lower_ascii "$dst")" ]]; then
        echo "  SKIP (target exists): ${ACTION_TO[$i]}" >&2
        SKIPPED=$((SKIPPED + 1))
        continue
      fi

      rename_with_case_support "$src" "$dst" \
        && APPLIED=$((APPLIED + 1)) \
        || { echo "  ERROR: rename failed for ${ACTION_FROM[$i]}" >&2; ERRORS=$((ERRORS + 1)); }

      $JSON_MODE || echo "  ✓  ${ACTION_FROM[$i]}  →  ${ACTION_TO[$i]}"
    done
    $JSON_MODE || echo ""
  }

  $DRY_RUN || do_uppercase_apply

  PROMPTS=()
  if (( TOTAL_ACTIONS == 0 )); then
    PROMPTS+=("No lowercase .md or .txt filenames need repo-wide normalization.")
  elif $DRY_RUN; then
    PROMPTS+=("Dry-run: ${TOTAL_ACTIONS} repo-wide rename(s) planned. Run \`./PROJECT/cleanup.sh uppercase --apply\` to apply them.")
    (( XREF_COUNT > 0 )) && PROMPTS+=("⚠️  ${XREF_COUNT} rename(s) are referenced by other .md/.txt files. Review those references before applying.")
    PROMPTS+=("Run with \`--json\` to get the full machine-readable action plan for agent orchestration.")
  else
    PROMPTS+=("${APPLIED} file(s) renamed. ${SKIPPED} skipped (target already existed). ${ERRORS} error(s).")
    (( XREF_COUNT > 0 )) && PROMPTS+=("⚠️  ${XREF_COUNT} renamed file(s) are still referenced by existing .md/.txt content. Update those references separately.")
    PROMPTS+=("Run \`git diff --name-only --cached\` to review staged renames before committing.")
  fi

  emit_uppercase_json() {
    local actions_json="[" sep=""
    for i in "${!ACTION_SRC[@]}"; do
      local rel_src xrefs_arr="" xsep=""
      rel_src="${ACTION_SRC[$i]#"$scan_root/"}"
      if [[ -n "${ACTION_XREFS[$i]}" ]]; then
        IFS='|' read -ra xparts <<< "${ACTION_XREFS[$i]}"
        for xp in "${xparts[@]}"; do
          xrefs_arr+="${xsep}\"$(json_str "${xp#"$scan_root/"}")\""
          xsep=","
        done
      fi
      actions_json+="${sep}{"
      actions_json+="\"file\":\"$(json_str "$rel_src")\","
      actions_json+="\"from\":\"$(json_str "${ACTION_FROM[$i]}")\","
      actions_json+="\"to\":\"$(json_str "${ACTION_TO[$i]}")\","
      actions_json+="\"action\":\"${ACTION_TYPE[$i]}\","
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
  "tool": "project-repo-case",
  "phase": "repo-case",
  "version": "1.0.0",
  "dry_run": $DRY_RUN,
  "config": { "root": "$(json_str "$scan_root")", "extensions": ["md", "txt"] },
  "stats": {
    "scanned": $scanned,
    "matches": $matched,
    "actions_planned": $TOTAL_ACTIONS,
    "applied": $APPLIED,
    "skipped": $SKIPPED,
    "errors": $ERRORS,
    "xref_warnings": $XREF_COUNT
  },
  "actions": $actions_json,
  "agent_prompts": $prompts_json
}
JSON
  }

  if $JSON_MODE; then
    emit_uppercase_json
  else
    print_uppercase_summary
    echo "##AGENT-CONTEXT"
    emit_uppercase_json
    echo "##END-AGENT-CONTEXT"
    echo ""
    echo "##AGENT-PROMPTS"
    for p in "${PROMPTS[@]}"; do echo "- $p"; done
    echo "##END-AGENT-PROMPTS"
  fi

  (( ERRORS > 0 )) && exit 99
  ! $DRY_RUN && (( APPLIED > 0 )) && exit 2
  (( TOTAL_ACTIONS > 0 )) && exit 1
  exit 0
}

[[ "$COMMAND" == "uppercase" ]] && run_uppercase

# ── Phase 1: find stale .md files ─────────────────────────────────────────────
STALE_FILES=()
STALE_AGES=()
ALL_SCANNED=0
NOW=$(date +%s)

while IFS= read -r -d '' filepath; do
  filename="$(basename "$filepath")"

  # Skip meta docs unless --no-exclude-meta
  if $EXCLUDE_META && [[ "$filename" == "DOCS-INSTRUCTIONS.md" ]]; then continue; fi

  ALL_SCANNED=$((ALL_SCANNED + 1))

  age=$(get_file_age "$filepath")
  (( age < 0 )) && continue   # dirty or unreadable — skip
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
    grep -rl --include="*.md" -- "$filename" "$SCRIPT_DIR" 2>/dev/null \
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
    local src dst
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
  PROMPTS+=("Dry-run: ${TOTAL_ACTIONS} rename(s) planned. Run \`./PROJECT/cleanup.sh --apply\` to apply them.")
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
    { "phase": 2, "name": "link-registry",      "status": "implemented", "command": "scan",    "description": "Cross-reference registry: detect and record broken links" },
    { "phase": 3, "name": "frontmatter-meta",   "status": "implemented", "command": "meta",    "description": "Enforce frontmatter metadata on every project doc" },
    { "phase": 4, "name": "folder-promotion",   "status": "implemented", "command": "promote", "description": "Detect done/misplaced docs and recommend folder moves" },
    { "phase": 5, "name": "git-correlation",     "status": "planned",     "description": "Git/CHANGELOG correlation for activity detection" },
    { "phase": 6, "name": "mcp-adapter",         "status": "planned",     "description": "MCP server for continuous folder hygiene orchestration" }
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
