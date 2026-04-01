#!/usr/bin/env bash
# =============================================================================
# project.sh — PROJECT folder hygiene · Phases 1 + 2 + 3
# version 1.1 - attn: update this number as improvements are added
# =============================================================================
# Phase 1 (default): scan .md files stale >N days → add/downgrade P3 prefix.
# Phase 2 (scan):    extract all markdown links, build bidirectional registry,
#                    detect broken links, save .xref-registry.json.
# Phase 3 (meta):    enforce frontmatter metadata on every project doc.
#
# AI AGENT HOOKS
#   --json      Emit structured JSON to stdout for agent/MCP consumption
#   Exit codes  Phase 1: 0=clean · 1=stale found · 2=applied · 99=error
#               Phase 2: 0=clean · 1=broken links found · 99=error
#               Phase 3: 0=clean · 1=gaps found · 2=applied · 99=error
#   Always emits ##AGENT-CONTEXT and ##AGENT-PROMPTS blocks at end of stdout.
#
# USAGE — Phase 1 (prefix hygiene)
#   ./PROJECT/project.sh                    # dry-run — safe default, no writes
#   ./PROJECT/project.sh --apply            # rename files (git mv when in repo)
#   ./PROJECT/project.sh --json             # structured JSON output only
#   ./PROJECT/project.sh --days 14          # custom stale threshold (default: 8)
#   ./PROJECT/project.sh --include-done     # also scan the 3-DONE/ subfolder
#   ./PROJECT/project.sh --no-exclude-meta  # include DOCS-INSTRUCTIONS.md
#
# USAGE — Phase 2 (cross-reference registry)
#   ./PROJECT/project.sh scan               # build .xref-registry.json + report
#   ./PROJECT/project.sh scan --check       # report only, no file written
#   ./PROJECT/project.sh scan --json        # JSON registry to stdout only
#
# USAGE — Phase 3 (frontmatter enforcement)
#   ./PROJECT/project.sh meta               # dry-run — report missing/incomplete
#   ./PROJECT/project.sh meta --apply       # inject/normalize frontmatter
#   ./PROJECT/project.sh meta --json        # structured JSON report only
#   ./PROJECT/project.sh meta --include-done # also scan 3-DONE/ subfolder
#
# PHASE ROADMAP
#   Phase 1 (this) — scan + P3 prefix/downgrade, xref warnings, agent hooks
#   Phase 2 (this) — cross-reference registry: detect and record broken links
#   Phase 3 (this) — enforce frontmatter metadata on every project doc
#   Phase 4        — scan 2-WORKING for done-folder promotion candidates
#   Phase 5        — git/CHANGELOG correlation for activity detection
#   Phase 6        — MCP server adapter for continuous hygiene orchestration
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
COMMAND="hygiene"       # hygiene (Phase 1) | scan (Phase 2) | meta (Phase 3)
DAYS_THRESHOLD=8
DRY_RUN=true
JSON_MODE=false
INCLUDE_DONE=false
EXCLUDE_META=true       # skip meta-docs like DOCS-INSTRUCTIONS.md by default
SCAN_CHECK_ONLY=false   # Phase 2: report without writing registry file

# ── Arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    scan)              COMMAND="scan" ;;
    meta)              COMMAND="meta" ;;
    --apply)           DRY_RUN=false ;;
    --check)           SCAN_CHECK_ONLY=true ;;
    --json)            JSON_MODE=true ;;
    --include-done)    INCLUDE_DONE=true ;;
    --no-exclude-meta) EXCLUDE_META=false ;;
    --days)
      [[ "${2:-}" =~ ^[0-9]+$ ]] || { echo "ERROR: --days requires a positive integer" >&2; exit 99; }
      DAYS_THRESHOLD="$2"; shift ;;
    --help|-h)
      sed -n '/^# USAGE/,/^# PHASE/p' "$0" | sed 's/^# \?//' | grep -v '^$' | head -20
      exit 0 ;;
    *) echo "ERROR: Unknown argument: $1 (try --help)" >&2; exit 99 ;;
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

for filepath in md_files:
    rel = os.path.relpath(filepath, scan_root)
    links = []
    try:
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
  prompts+=("Run \`./PROJECT/project.sh scan --json\` to get the full machine-readable registry for agent use.")

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
  local git_dates_json="{}"
  if $USE_GIT; then
    git_dates_json=$(
      for f in "${md_files[@]}"; do
        local rel; rel="${f#"$SCRIPT_DIR/"}"
        local first last author
        first=$(git -C "$SCRIPT_DIR" log --diff-filter=A --follow --format="%ai" -- "$f" 2>/dev/null | tail -1 || true)
        last=$(git -C "$SCRIPT_DIR" log -1 --format="%ai" -- "$f" 2>/dev/null || true)
        author=$(git -C "$SCRIPT_DIR" log --diff-filter=A --follow --format="%an" -- "$f" 2>/dev/null | tail -1 || true)
        # Output one JSON fragment per file
        printf '"%s":{"created":"%s","updated":"%s","author":"%s"}\n' \
          "$(json_str "$f")" \
          "${first:0:10}" "${last:0:10}" "$(json_str "$author")"
      done | paste -sd',' - | sed 's/^/{/;s/$/}/'
    )
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
    prompts+=("${needs_update} of ${files_scanned} file(s) need frontmatter updates. Run \`./PROJECT/project.sh meta --apply\` to fix them.")
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

# ── Route to Phase 2/3 early if subcommand matches ──────────────────────────
[[ "$COMMAND" == "scan" ]] && run_scan
[[ "$COMMAND" == "meta" ]] && run_meta

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
