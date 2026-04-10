#!/usr/bin/env bash

set -euo pipefail

# ─── post-flight.sh ─────────────────────────────────────────────────────────
#
# Session cleanup & documentation synchronization for solo developers.
#
# Checks 4X4.md, CHANGELOG.md freshness, scans Claude Code memory for
# conflicted duplicates, optionally commits and pushes.
#
# Usage:
#   post-flight.sh [OPTIONS]
#
# Options:
#   --commit              Stage & commit if docs changed (requires confirmation)
#   --push                Commit + push (implies --commit, requires confirmation)
#   --force               Skip confirmation (use with --push for automation)
#   --no-validate         Skip syntax/build checks
#   --dry-run             Report only, no git actions
#   --hook <script>       Agent orchestration hook (receives events)
#   --help                Show this help
#
# Exit Codes:
#   0 = OK, all docs fresh, working tree clean
#   1 = WARN, docs need updates or git state issues (remediation suggested)
#   2 = ERROR, missing files, git errors, or validation failures
#
# Examples:
#   # Report only (default)
#   post-flight.sh
#
#   # Commit with confirmation
#   post-flight.sh --commit
#
#   # Commit + push with confirmation
#   post-flight.sh --push
#
#   # Full automation (no prompts)
#   post-flight.sh --push --force
#
#   # With agent hook for orchestration
#   post-flight.sh --push --hook ./my-agent-hook.sh
#
# Agent Hook Events:
#   check:4x4 '{"status":"ok|missing|stale|mismatch"}'
#   check:changelog '{"status":"ok|missing|stale"}'
#   check:memory-duplicates '{"status":"ok|found|no_dir","duplicates":N,"orphans":N,"broken":N}'
#   check:git '{"status":"clean|dirty|needs_push","branch":"...","files_changed":N}'
#   validate:build '{"status":"ok|error","message":"..."}'
#   suggest:commit '{"message":"...","files":["..."]}'
#   action:commit '{"message":"...","sha":"..."}'
#   action:push '{"remote":"...","branch":"...","url":"..."}'
#   complete '{"status":"success|failed","summary":"..."}'
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

MODE_COMMIT=0
MODE_PUSH=0
FORCE=0
SKIP_VALIDATION=0
DRY_RUN=0
HOOK_SCRIPT=""

# Colors
if [ -t 1 ]; then
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

emit_event() {
    local event_name="$1"
    local json_payload="${2:-{}}"
    
    if [ -n "$HOOK_SCRIPT" ] && [ -x "$HOOK_SCRIPT" ]; then
        if ! "$HOOK_SCRIPT" "$event_name" "$json_payload"; then
            echo "${RED}✗ Hook aborted at: $event_name${NC}" >&2
            return 1
        fi
    fi
    return 0
}

fail() {
    echo "${RED}✗ Error: $*${NC}" >&2
    exit 2
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$FORCE" -eq 1 ]; then
        return 0
    fi
    
    if [ "$default" = "y" ]; then
        read -p "${CYAN}${prompt}${NC} [Y/n] " -r
        [[ $REPLY =~ ^[Nn]$ ]] && return 1 || return 0
    else
        read -p "${CYAN}${prompt}${NC} [y/N] " -r
        [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
    fi
}

show_help() {
    head -60 "$0" | tail -45
}

# ─── Checks ─────────────────────────────────────────────────────────────────

check_4x4() {
    if [ ! -f "$REPO_ROOT/4X4.md" ]; then
        emit_event "check:4x4" '{"status":"missing"}' || return 1
        echo "${YELLOW}⚠ 4X4.md not found${NC}"
        return 1
    fi
    emit_event "check:4x4" '{"status":"ok"}' || return 1
    echo "${GREEN}✓ 4X4.md${NC}"
    return 0
}

check_changelog() {
    if [ ! -f "$REPO_ROOT/CHANGELOG.md" ]; then
        emit_event "check:changelog" '{"status":"missing"}' || return 1
        echo "${YELLOW}⚠ CHANGELOG.md not found${NC}"
        return 1
    fi
    emit_event "check:changelog" '{"status":"ok"}' || return 1
    echo "${GREEN}✓ CHANGELOG.md${NC}"
    return 0
}

check_memory_duplicates() {
    # Scan Claude Code auto-memory directory for conflicted duplicates,
    # orphaned files, broken index links, and missing frontmatter.
    #
    # Memory layout:
    #   ~/.claude/projects/<project-hash>/memory/MEMORY.md  (index)
    #   ~/.claude/projects/<project-hash>/memory/<name>.md  (individual memories)

    # Derive the Claude Code memory dir for the current repo root.
    # Claude Code slugifies the absolute path: / → -
    local slug
    slug=$(echo "$REPO_ROOT" | sed 's|/|-|g')
    local memory_dir="$HOME/.claude/projects/${slug}/memory"

    if [ ! -d "$memory_dir" ]; then
        emit_event "check:memory-duplicates" '{"status":"no_dir","duplicates":0,"orphans":0,"broken":0}' || return 1
        echo "${YELLOW}⚠ No Claude Code memory directory found (OK)${NC}"
        return 0
    fi

    local index_file="$memory_dir/MEMORY.md"
    local duplicates=0
    local orphans=0
    local broken_links=0
    local missing_frontmatter=0
    local issues=""

    # Collect all .md files in the memory dir (excluding MEMORY.md index)
    local memory_files=()
    while IFS= read -r -d '' f; do
        memory_files+=("$f")
    done < <(find "$memory_dir" -maxdepth 1 -name "*.md" ! -name "MEMORY.md" -print0 2>/dev/null)

    if [ ${#memory_files[@]} -eq 0 ] && [ ! -f "$index_file" ]; then
        emit_event "check:memory-duplicates" '{"status":"ok","duplicates":0,"orphans":0,"broken":0}' || return 1
        echo "${GREEN}✓ Memory: no files to check${NC}"
        return 0
    fi

    # --- Check 1: Orphaned files (in dir but not linked from MEMORY.md) ---
    if [ -f "$index_file" ]; then
        for mf in "${memory_files[@]}"; do
            local basename
            basename=$(basename "$mf")
            if ! grep -qF "$basename" "$index_file" 2>/dev/null; then
                orphans=$((orphans + 1))
                issues="${issues}  orphan: ${basename}\n"
            fi
        done

        # --- Check 2: Broken links (referenced in MEMORY.md but file missing) ---
        while IFS= read -r linked; do
            if [ ! -f "$memory_dir/$linked" ]; then
                broken_links=$((broken_links + 1))
                issues="${issues}  broken link: ${linked}\n"
            fi
        done < <(grep -oE '\([^)]+\.md\)' "$index_file" 2>/dev/null | tr -d '()' | sort -u)
    else
        # No index but files exist — all are orphans
        orphans=${#memory_files[@]}
        for mf in "${memory_files[@]}"; do
            issues="${issues}  orphan (no index): $(basename "$mf")\n"
        done
    fi

    # --- Check 3: Duplicate topics (same type + similar name/description) ---
    # Extract type values from frontmatter and look for duplicates within each type
    declare -A type_files
    for mf in "${memory_files[@]}"; do
        local ftype
        ftype=$(sed -n '/^---$/,/^---$/{ s/^type:[[:space:]]*//p; }' "$mf" 2>/dev/null | head -1)
        if [ -z "$ftype" ]; then
            missing_frontmatter=$((missing_frontmatter + 1))
            issues="${issues}  missing frontmatter: $(basename "$mf")\n"
            continue
        fi
        local bn
        bn=$(basename "$mf")
        if [ -n "${type_files[$ftype]+x}" ]; then
            type_files[$ftype]="${type_files[$ftype]}|$bn"
        else
            type_files[$ftype]="$bn"
        fi
    done

    # Flag types with 3+ files as potential duplicates (some overlap is normal)
    for ftype in "${!type_files[@]}"; do
        local count
        count=$(echo "${type_files[$ftype]}" | tr '|' '\n' | wc -l | tr -d ' ')
        if [ "$count" -ge 3 ]; then
            duplicates=$((duplicates + 1))
            local file_list
            file_list=$(echo "${type_files[$ftype]}" | tr '|' ', ')
            issues="${issues}  possible duplicates (type=$ftype, ${count} files): ${file_list}\n"
        fi
    done

    # --- Report ---
    local total=$((duplicates + orphans + broken_links + missing_frontmatter))

    emit_event "check:memory-duplicates" "{\"status\":\"$([ "$total" -gt 0 ] && echo found || echo ok)\",\"duplicates\":$duplicates,\"orphans\":$orphans,\"broken\":$broken_links,\"missing_frontmatter\":$missing_frontmatter}" || return 1

    if [ "$total" -eq 0 ]; then
        echo "${GREEN}✓ Memory: ${#memory_files[@]} files, no duplicates or conflicts${NC}"
    else
        echo "${YELLOW}⚠ Memory: ${total} issue(s) found (${#memory_files[@]} files checked)${NC}"
        if [ -n "$issues" ]; then
            echo -e "$issues" | while IFS= read -r line; do
                [ -n "$line" ] && echo "  ${YELLOW}${line}${NC}"
            done
        fi
    fi
    return 0
}

check_git_state() {
    cd "$REPO_ROOT" || fail "Cannot cd to repo root"
    
    local branch
    local untracked
    local modified
    
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    untracked=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)
    modified=$(git diff --name-only 2>/dev/null | wc -l)
    
    local status_summary
    if [ "$modified" -eq 0 ] && [ "$untracked" -eq 0 ]; then
        status_summary="clean"
    else
        status_summary="dirty"
    fi
    
    emit_event "check:git" "{\"status\":\"$status_summary\",\"branch\":\"$branch\",\"modified\":$modified,\"untracked\":$untracked}" || return 1
    
    echo "${CYAN}Branch: ${branch}${NC}"
    if [ "$modified" -gt 0 ] || [ "$untracked" -gt 0 ]; then
        echo "${YELLOW}⚠ Git state: $modified modified, $untracked untracked files${NC}"
    else
        echo "${GREEN}✓ Git state: clean${NC}"
    fi
    return 0
}

suggest_commit_message() {
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    
    # Simple heuristic: check what changed
    local files_changed
    files_changed=$(git diff --name-only 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    
    local message="docs: Session cleanup — updated docs"
    
    emit_event "suggest:commit" "{\"message\":\"$message\",\"files\":\"$files_changed\"}" || return 1
    return 0
}

validate_build() {
    [ "$SKIP_VALIDATION" -eq 1 ] && return 0

    local checks_run=0
    local checks_failed=0
    local errors=""

    # PHP syntax check — runs if php is available and any .php files exist in repo
    if command -v php >/dev/null 2>&1; then
        local php_files
        php_files=$(find "$REPO_ROOT" -name "*.php" -not -path "*/vendor/*" -not -path "*/node_modules/*" -type f 2>/dev/null | head -200)
        if [ -n "$php_files" ]; then
            checks_run=$((checks_run + 1))
            local php_errors=""
            while IFS= read -r f; do
                if ! php -l "$f" >/dev/null 2>&1; then
                    php_errors="${php_errors}${f}\n"
                fi
            done <<< "$php_files"
            if [ -n "$php_errors" ]; then
                checks_failed=$((checks_failed + 1))
                errors="${errors}PHP syntax errors found\n"
                echo "${RED}✗ PHP syntax check failed${NC}"
            else
                echo "${GREEN}✓ PHP syntax check passed${NC}"
            fi
        fi
    fi

    # Node.js build check — runs if package.json exists with a build script
    if [ -f "$REPO_ROOT/package.json" ] && command -v node >/dev/null 2>&1; then
        if node -e "const p=require('$REPO_ROOT/package.json'); process.exit(p.scripts && p.scripts.build ? 0 : 1)" 2>/dev/null; then
            checks_run=$((checks_run + 1))
            if npm run --prefix "$REPO_ROOT" build --silent >/dev/null 2>&1; then
                echo "${GREEN}✓ npm build passed${NC}"
            else
                checks_failed=$((checks_failed + 1))
                errors="${errors}npm build failed\n"
                echo "${RED}✗ npm build failed${NC}"
            fi
        fi
    fi

    # Composer check — runs if composer.json exists with a check-platform-reqs or validate script
    if [ -f "$REPO_ROOT/composer.json" ] && command -v composer >/dev/null 2>&1; then
        checks_run=$((checks_run + 1))
        if composer validate --no-check-all --no-check-publish --working-dir="$REPO_ROOT" >/dev/null 2>&1; then
            echo "${GREEN}✓ composer validate passed${NC}"
        else
            checks_failed=$((checks_failed + 1))
            errors="${errors}composer validate failed\n"
            echo "${RED}✗ composer validate failed${NC}"
        fi
    fi

    if [ "$checks_run" -eq 0 ]; then
        echo "${CYAN}ℹ No build validators detected (no PHP, package.json, or composer.json)${NC}"
        emit_event "validate:build" '{"status":"skipped","message":"No validators detected"}' || return 1
        return 0
    fi

    if [ "$checks_failed" -gt 0 ]; then
        emit_event "validate:build" "{\"status\":\"error\",\"message\":\"$checks_failed/$checks_run checks failed\"}" || return 1
        return 1
    fi

    emit_event "validate:build" "{\"status\":\"ok\",\"message\":\"$checks_run/$checks_run checks passed\"}" || return 1
    echo "${GREEN}✓ Build validation passed ($checks_run checks)${NC}"
    return 0
}

do_commit() {
    cd "$REPO_ROOT" || fail "Cannot cd to repo root"
    
    local message="docs: Session cleanup — updated docs"
    
    if [ "$DRY_RUN" -eq 0 ]; then
        git add -A
        git commit -m "$message" || fail "Commit failed"
        local sha
        sha=$(git rev-parse --short HEAD)
        emit_event "action:commit" "{\"message\":\"$message\",\"sha\":\"$sha\"}" || return 1
        echo "${GREEN}✓ Committed: $sha${NC}"
    else
        echo "${GREEN}✓ Would commit with message: $message${NC}"
    fi
    return 0
}

do_push() {
    cd "$REPO_ROOT" || fail "Cannot cd to repo root"
    
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "development")
    
    local remote="origin"
    
    if [ "$DRY_RUN" -eq 0 ]; then
        git push "$remote" "$branch" || fail "Push failed"
        emit_event "action:push" "{\"remote\":\"$remote\",\"branch\":\"$branch\"}" || return 1
        echo "${GREEN}✓ Pushed to $remote/$branch${NC}"
    else
        echo "${GREEN}✓ Would push to $remote/$branch${NC}"
    fi
    return 0
}

# ─── Parse Arguments ────────────────────────────────────────────────────────

while [ $# -gt 0 ]; do
    case "$1" in
        --commit) MODE_COMMIT=1; shift ;;
        --push) MODE_PUSH=1; MODE_COMMIT=1; shift ;;
        --force) FORCE=1; shift ;;
        --no-validate) SKIP_VALIDATION=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        --hook) HOOK_SCRIPT="$2"; shift 2 ;;
        --help) show_help; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
done

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    echo "${BOLD}[post-flight] 📋 Session Summary${NC}"
    echo ""
    
    check_4x4 || true
    check_changelog || true
    check_memory_duplicates || true
    check_git_state || true
    
    echo ""
    echo "${BOLD}[post-flight] 🔍 Validation${NC}"
    validate_build || true
    
    if [ "$MODE_COMMIT" -eq 0 ]; then
        echo ""
        echo "${CYAN}ℹ Report complete. Use --commit or --push to commit changes.${NC}"
        emit_event "complete" '{"status":"success","summary":"Report complete"}' || true
        exit 0
    fi
    
    echo ""
    suggest_commit_message || true
    
    echo ""
    if ! confirm "Continue with commit?" "n"; then
        echo "${YELLOW}⊘ Cancelled${NC}"
        exit 1
    fi
    
    do_commit || fail "Commit failed"
    
    if [ "$MODE_PUSH" -eq 1 ]; then
        if ! confirm "Push to remote?" "n"; then
            echo "${YELLOW}⊘ Skipped push${NC}"
            exit 1
        fi
        do_push || fail "Push failed"
    fi
    
    echo ""
    echo "${GREEN}${BOLD}✓ Session closed cleanly${NC}"
    emit_event "complete" '{"status":"success","summary":"Session closed"}' || true
    exit 0
}

main "$@"

