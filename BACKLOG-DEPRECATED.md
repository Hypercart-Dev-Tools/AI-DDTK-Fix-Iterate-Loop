# BACKLOG

## TOC
- Discovery Problem
- WPCC Performance: .wpcignore Support & Timeout Handling
-VS Code Extension

## 1. Discovery Problem
Status: Not Started

Yes, that makes perfect sense. You want AI agents to **automatically know** about AI-DDTK tools without you having to remind them every time. This is a **context discovery** problem.

---

## The Problem

| Current State | Desired State |
|---------------|---------------|
| AI agent starts fresh in each repo | AI agent knows AI-DDTK exists |
| You say "use wpcc" every time | AI agent discovers `wpcc` is available |
| No awareness of AGENTS.md guidelines | AI agent reads AGENTS.md automatically |
| Tools are in PATH but invisible to AI | Tools + docs are part of agent context |

---

## Solutions (Ranked by Effort/Impact)

### 1. **`.ai-ddtk` Marker File** (Lowest Effort)

Add a small file to each repo that tells AI agents where to find AI-DDTK:

```bash
# In each project repo
cat > .ai-ddtk <<EOF
# AI-DDTK Integration
# This project uses AI-DDTK tools from ~/bin/ai-ddtk
# 
# Available tools:
# - wpcc: WordPress Code Check (security/performance scanner)
# - Performance Timer: Runtime profiling (requires WP plugin)
#
# Documentation:
# - Guidelines: ~/bin/ai-ddtk/AGENTS.md
# - Recipes: ~/bin/ai-ddtk/recipes/
# - WPCC Features: wpcc --features
#
# Quick Start:
# - Scan this plugin: wpcc --paths .
# - Show all features: wpcc --features
# - Performance audit: See ~/bin/ai-ddtk/recipes/performance-audit.md
EOF
```

**Pros**: 
- ✅ Simple, just one file per repo
- ✅ AI agents will read it (they scan for config files)
- ✅ Can be committed to repo

**Cons**:
- ⚠️ Requires adding file to each repo
- ⚠️ AI might not read it unless prompted

---

### 2. **VS Code Workspace Settings** (Medium Effort)

Add AI-DDTK awareness to `.vscode/settings.json`:

```json
{
  "ai-ddtk.enabled": true,
  "ai-ddtk.path": "~/bin/ai-ddtk",
  "ai-ddtk.guidelines": "~/bin/ai-ddtk/AGENTS.md",
  "ai-ddtk.tools": {
    "wpcc": {
      "command": "wpcc",
      "features": "wpcc --features",
      "docs": "~/bin/ai-ddtk/tools/wp-code-check/dist/TEMPLATES/_AI_INSTRUCTIONS.md"
    }
  }
}
```

**Pros**:
- ✅ VS Code-specific, works with Augment/Claude Code
- ✅ Can be committed to repo

**Cons**:
- ⚠️ Not all AI agents read VS Code settings
- ⚠️ Requires `.vscode/` folder in each repo

---

### 3. **MCP Server** (High Effort, Best Long-Term)

Create an MCP server that AI agents can discover automatically:

```json
// ~/.config/Code/User/globalStorage/augment.mcp-servers.json
{
  "mcpServers": {
    "ai-ddtk": {
      "command": "node",
      "args": ["~/bin/ai-ddtk/mcp/server.js"],
      "env": {
        "AI_DDTK_PATH": "~/bin/ai-ddtk"
      }
    }
  }
}
```

The MCP server would expose:
- `wpcc_scan` tool
- `wpcc_triage` tool
- `get_guidelines` tool (returns AGENTS.md)
- `get_recipe` tool (returns workflow recipes)

**Pros**:
- ✅ AI agents auto-discover tools
- ✅ Works across all repos
- ✅ No per-repo configuration needed
- ✅ Structured tool responses (not just CLI output)

**Cons**:
- ⚠️ Requires building MCP server
- ⚠️ Only works with MCP-compatible AI agents (Augment, Claude Desktop)

---

### 4. **Git Template with Hooks** (Medium Effort)

Set up a git template that auto-adds AI-DDTK awareness:

```bash
# One-time setup
mkdir -p ~/.git-templates/hooks
cat > ~/.git-templates/hooks/post-checkout <<'EOF'
#!/bin/bash
# Auto-create .ai-ddtk file if it doesn't exist
if [ ! -f .ai-ddtk ] && [ -d ~/bin/ai-ddtk ]; then
    cp ~/bin/ai-ddtk/.ai-ddtk.template .ai-ddtk
    echo "✓ Added AI-DDTK integration file"
fi
EOF
chmod +x ~/.git-templates/hooks/post-checkout

# Configure git to use template
git config --global init.templateDir ~/.git-templates
```

**Pros**:
- ✅ Automatic for new repos
- ✅ One-time setup

**Cons**:
- ⚠️ Doesn't help existing repos
- ⚠️ Requires git hook support

---

### 5. **Augment/Claude System Instructions** (Immediate, No Code)

Add to your AI agent's system instructions:

```markdown
# AI-DDTK Integration

This workspace has access to AI-DDTK tools installed at ~/bin/ai-ddtk.

Before starting any WordPress development task:
1. Check if wpcc is available: `which wpcc`
2. Read guidelines: `cat ~/bin/ai-ddtk/AGENTS.md`
3. For WordPress projects, always consider using wpcc for code analysis

Available tools:
- wpcc: WordPress security/performance scanner
- Performance Timer: Runtime profiling (requires WP plugin)

Documentation:
- ~/bin/ai-ddtk/AGENTS.md - WordPress development guidelines
- ~/bin/ai-ddtk/recipes/ - Workflow recipes
- wpcc --features - Show all WPCC capabilities
```

**Pros**:
- ✅ Works immediately
- ✅ No code changes needed
- ✅ Works across all repos

**Cons**:
- ⚠️ Requires configuring each AI agent
- ⚠️ Not automatic for new team members

---

## My Recommendation: **Hybrid Approach**

Combine **#1 (marker file)** + **#5 (system instructions)** + **#3 (MCP server, future)**:

### Phase 1 (Now): Marker File + System Instructions

1. **Create `.ai-ddtk.template` in AI-DDTK repo**:
```bash
cat > ~/bin/ai-ddtk/.ai-ddtk.template <<'EOF'
# AI-DDTK Integration
# See: ~/bin/ai-ddtk/AGENTS.md for WordPress development guidelines
# Run: wpcc --features to see all available tools
EOF
```

2. **Add helper script to AI-DDTK**:
```bash
# ~/bin/ai-ddtk/bin/init-project
#!/bin/bash
# Initialize AI-DDTK in current project
cp ~/bin/ai-ddtk/.ai-ddtk.template .ai-ddtk
echo "✓ AI-DDTK integration added to $(pwd)"
```

3. **Update your AI agent system instructions** (one-time)

### Phase 2 (Future): MCP Server

Build MCP server for automatic tool discovery (already in your roadmap).

---

## Quick Win: Add to AGENTS.md

Let me add a section to AGENTS.md about this:

Would you like me to:
1. **Create the `.ai-ddtk.template` file** and `bin/init-project` script?
2. **Add a "Project Integration" section to AGENTS.md** explaining this?
3. **Draft system instructions** you can paste into Augment/Claude settings?
4. **All of the above**?

---

## 2. WPCC Performance: .wpcignore Support & Timeout Handling

**Status**: Planned
**Priority**: High
**Effort**: Medium (2-3 hours)
**GitHub Issues**:
- AI-DDTK: [#5](https://github.com/Hypercart-Dev-Tools/AI-DDTK-Fix-Iterate-Loop/issues/5)
- WP-Code-Check: [#112](https://github.com/Hypercart-Dev-Tools/WP-Code-Check/issues/112)

### Problem

When scanning large directories (especially AI-DDTK itself which contains embedded WPCC via git subtree), the scanner stalls during the "Magic String Detector" phase due to:

1. **Recursive scanning** - WPCC scans itself when run from AI-DDTK root
2. **No exclusion mechanism** - Can't easily exclude `tools/`, `.git/`, `node_modules/`
3. **No progress indicators** - Users don't know if it's working or hung
4. **No timeout handling** - Scans can run indefinitely

**Example failure:**
```bash
wpcc --paths . --format json
# Stalls at: [Magic String Detector] Aggregating patterns...
```

### Root Cause

Scanning `.` from AI-DDTK root includes:
- `tools/wp-code-check/` - **100+ files** (WPCC scanning itself)
- `.git/` - **Thousands of objects**
- Embedded dependencies
- **Total: 10K+ files** → Magic String Detector timeout

### Proposed Solution

**Phase 1: .wpcignore Support** (1 hour)
- Add `.wpcignore` file support (like `.gitignore`)
- Default exclusions: `.git/`, `node_modules/`, `vendor/`, `tools/`, `dist/logs/`, `dist/reports/`
- Create template `.wpcignore` for AI-DDTK repository
- Update WPCC to read and respect `.wpcignore` patterns

**Phase 2: Progress Indicators** (30 min)
- Add file count progress: `[Magic String Detector] Processing 1234/5678 files...`
- Add time elapsed indicator
- Add estimated time remaining (based on avg file processing speed)

**Phase 3: Timeout Handling** (30 min)
- Add configurable timeout for each scan phase
- Default: 60s per phase, 300s total
- Graceful degradation: Skip slow phases, continue with partial results
- Add `--timeout` CLI flag

**Phase 4: Performance Optimization** (1 hour)
- Cache Magic String Detector results per file hash
- Skip unchanged files on subsequent scans
- Parallelize file processing where possible

### Implementation Plan

```bash
# 1. Create .wpcignore template
cat > tools/wp-code-check/.wpcignore.template << 'EOF'
# Version control
.git/
.svn/

# Dependencies
node_modules/
vendor/
bower_components/

# Build artifacts
dist/
build/
*.min.js
*.min.css

# WPCC output
dist/logs/
dist/reports/
dist/issues/

# Temporary files
temp/
tmp/
*.log
*.cache

# Embedded tools (for meta-repos like AI-DDTK)
tools/
EOF

# 2. Add to AI-DDTK root
cp tools/wp-code-check/.wpcignore.template .wpcignore

# 3. Update WPCC scanner to read .wpcignore
# (Implementation in WPCC codebase)

# 4. Test with AI-DDTK
wpcc --paths . --format json  # Should now exclude tools/
```

### Success Criteria

- [ ] `.wpcignore` file support implemented in WPCC
- [ ] Template `.wpcignore` created and documented
- [ ] AI-DDTK includes `.wpcignore` in root
- [ ] Progress indicators show during long scans
- [ ] Timeout handling prevents indefinite hangs
- [ ] Scanning AI-DDTK root completes in <30s
- [ ] Documentation updated in WPCC README and AI-DDTK AGENTS.md

### Workaround (Until Fixed)

```bash
# When scanning AI-DDTK itself, exclude embedded tools
wpcc --paths . --exclude "tools/,.git/,node_modules/" --format json

# Or scan only specific directories
wpcc --paths "bin/ recipes/ templates/" --format json
```

### Related Issues

- WPCC Magic String Detector performance on large codebases
- Need for better scan progress visibility
- AI-DDTK self-scanning creates recursive problem

### Next Steps

1. Create issue in WP-Code-Check repository
2. Implement `.wpcignore` support in WPCC
3. Add progress indicators and timeout handling
4. Update AI-DDTK with `.wpcignore` file
5. Document in both WPCC and AI-DDTK READMEs
