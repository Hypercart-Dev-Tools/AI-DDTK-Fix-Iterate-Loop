---
title: "My Analysis: VS Code Extension for AI-DDTK"
status: inbox
priority: P3
created: 2026-02-07
updated: 2026-04-01
author: noelsaw1
goal: 
---

## 🤔 My Analysis: VS Code Extension for AI-DDTK

### Current State Assessment

**What we have now:**
- ✅ CLI tools (`wpcc`, `local-wp`) - work from any terminal
- ✅ MCP server integration - works with Claude Desktop, Cline, etc.
- ✅ PATH-based installation - accessible from any project
- ✅ AI agent guidelines (AGENTS.md) - copy/paste into system instructions
- ✅ `/temp` folder structure - manual but well-documented

**What's missing:**
- ❌ No visual UI for scan results
- ❌ No inline code annotations (e.g., "Security issue on line 42")
- ❌ No one-click "Fix this issue" buttons
- ❌ No VS Code-native integration (sidebar, status bar, etc.)
- ❌ Manual setup for AI agents (copy/paste AGENTS.md)

---

## 💡 VS Code Extension: Pros & Cons

### ✅ Pros (High Value)

#### 1. **Visual Scan Results**
```
Instead of:  wpcc --paths . --format json > temp/reports/wpcc/scan.json
You get:     Click "Scan" button → Results in sidebar with severity badges
```

**Value**: Beginners don't need to read JSON. Issues are clickable, filterable, sortable.

#### 2. **Inline Code Annotations**
```php
// Line 42 in plugin.php
$user_input = $_POST['data'];  // ⚠️ WPCC: Missing sanitization (spo-001)
                                // 💡 Quick Fix: Add sanitize_text_field()
```

**Value**: Developers see issues exactly where they occur. No context switching.

#### 3. **One-Click Fixes**
```
Issue: Missing nonce verification
[Fix Automatically] [Ignore] [Learn More]
```

**Value**: AI agents can suggest fixes, extension applies them. Faster workflow.

#### 4. **Auto-Load AGENTS.md into AI Context**
```
Extension detects AI-DDTK installation
→ Automatically adds AGENTS.md to Augment/Cline/Continue context
→ No manual copy/paste needed
```

**Value**: Zero-config AI agent setup. Just install extension, start coding.

#### 5. **Status Bar Integration**
```
Bottom bar: [WPCC: 3 issues] [PHPStan: 0 errors] [Temp: 12 files]
Click → Opens sidebar with details
```

**Value**: Always-visible code quality metrics. Encourages continuous scanning.

#### 6. **Temp Folder Management**
```
Sidebar: "Temp Files"
├── 📁 credentials (2 files)
├── 📁 reports/wpcc (5 scans)
├── 📁 logs (3 files)
└── 🗑️ Clean up old files (30+ days)
```

**Value**: Visual management of `/temp` folder. One-click cleanup.

---

### ❌ Cons (Challenges)

#### 1. **Maintenance Burden**
- Need to maintain extension + CLI tools + MCP server
- VS Code API changes require updates
- Extension marketplace approval process
- Bug reports from non-technical users

**Mitigation**: Start minimal (wrapper around CLI), add features incrementally.

#### 2. **Platform Lock-In**
- Only works in VS Code (not JetBrains, Sublime, Vim, etc.)
- Users who prefer terminal-only workflows won't use it
- MCP server already works across multiple AI tools

**Mitigation**: Extension is **optional enhancement**, not replacement for CLI.

#### 3. **Discoverability Split**
- Users might find extension but not know about CLI tools
- Or vice versa: use CLI but miss extension features
- Documentation needs to cover both paths

**Mitigation**: Extension README links to main AI-DDTK repo. CLI README mentions extension.

#### 4. **Installation Complexity**
- Users need to install AI-DDTK (CLI) **AND** extension
- Extension needs to detect AI-DDTK installation path
- What if user installs extension but not AI-DDTK?

**Mitigation**: Extension auto-detects `~/bin/ai-ddtk`, offers to install if missing.

---

## 🎯 Recommendation: **YES, but Phased Approach**

### Phase 1: MVP Extension (2-3 days) - **High ROI**

**Core Features**:
1. **WPCC Scan Button** - Runs `wpcc --paths . --format json`, displays results in sidebar
2. **Issue List View** - Clickable issues that jump to file/line
3. **Auto-Load AGENTS.md** - Adds to AI agent context automatically
4. **Status Bar Widget** - Shows issue count, click to open sidebar

**Why this first?**
- ✅ Solves biggest pain point: "I don't want to read JSON"
- ✅ Minimal code: Wrapper around existing CLI tools
- ✅ Immediate value for beginners
- ✅ Doesn't require maintaining complex logic (CLI does the work)

**Example User Flow**:
```
1. User installs extension
2. Extension detects ~/bin/ai-ddtk
3. User opens WordPress plugin folder
4. Clicks "Scan with WPCC" button in sidebar
5. Results appear in sidebar: "3 security issues, 2 performance issues"
6. User clicks issue → jumps to line 42 in plugin.php
7. User asks AI agent to fix → AI already has AGENTS.md context
```

---

### Phase 2: Enhanced Features (1-2 weeks) - **Medium ROI**

**Add**:
1. **Inline Annotations** - Squiggly lines under problematic code
2. **Quick Fixes** - CodeLens "Fix this issue" buttons
3. **Temp Folder Sidebar** - Visual file browser for `/temp`
4. **Scan History** - View past scans, compare before/after
5. **Settings Panel** - Configure WPCC options, exclusions

**Why later?**
- Requires more VS Code API knowledge (Diagnostics, CodeLens, TreeView)
- Nice-to-have, not essential for core workflow
- Can gather user feedback from Phase 1 first

---

### Phase 3: Advanced Features (Future) - **Lower ROI**

**Add**:
1. **AI-Assisted Fixes** - Extension calls AI agent to generate fix, shows diff
2. **Performance Profiling UI** - Visual timeline for WP Performance Timer data
3. **PHPStan Integration** - Run PHPStan from extension, show type errors inline
4. **Playwright Test Runner** - Run tests from sidebar, show results
5. **Multi-Project Dashboard** - Scan multiple projects, aggregate metrics

**Why much later?**
- Complex features that overlap with existing tools (PHPStan extension, Playwright extension)
- Risk of feature bloat
- Better to do one thing well (WPCC integration) than many things poorly

---

## 📊 Comparison: Extension vs. Current Setup

| Feature | Current (CLI + MCP) | With Extension |
|---------|---------------------|----------------|
| **Scan WordPress code** | ✅ `wpcc --paths .` | ✅ Click "Scan" button |
| **View results** | ❌ Read JSON file | ✅ Sidebar with clickable issues |
| **Jump to issue** | ❌ Manual (search file) | ✅ One click |
| **AI agent context** | ❌ Copy/paste AGENTS.md | ✅ Auto-loaded |
| **Status visibility** | ❌ Run command to check | ✅ Status bar always visible |
| **Works outside VS Code** | ✅ Terminal, CI/CD | ❌ VS Code only |
| **Works with any AI tool** | ✅ MCP server | ⚠️ VS Code AI extensions only |
| **Maintenance burden** | ✅ Low (CLI stable) | ⚠️ Medium (VS Code API changes) |

**Verdict**: Extension **complements** CLI, doesn't replace it.

---

## 🏗️ Architecture Recommendation

### Extension as Thin Wrapper

```
VS Code Extension (UI Layer)
    ↓
Calls CLI tools (wpcc, local-wp)
    ↓
Parses JSON output
    ↓
Displays in VS Code UI (sidebar, inline, status bar)
```

**Benefits**:
- ✅ Extension is simple (just UI)
- ✅ CLI tools remain source of truth
- ✅ Easy to maintain (no duplicate logic)
- ✅ Works even if extension breaks (CLI still functional)

**Example Code** (extension):
```typescript
// extension.ts
import * as vscode from 'vscode';
import { exec } from 'child_process';

async function runWPCC(path: string): Promise<WPCCResult> {
  return new Promise((resolve, reject) => {
    exec(`wpcc --paths ${path} --format json`, (error, stdout) => {
      if (error) reject(error);
      resolve(JSON.parse(stdout));
    });
  });
}

// Display results in sidebar
function showResults(results: WPCCResult) {
  const treeView = new WPCCTreeView(results);
  vscode.window.registerTreeDataProvider('wpccResults', treeView);
}
```

---

## 🎯 My Recommendation: **Build Phase 1 MVP**

### Why?

1. **High Impact, Low Effort**
   - 2-3 days to build MVP
   - Solves biggest pain point (JSON → Visual UI)
   - Immediate value for beginners

2. **Validates Demand**
   - See if users actually want VS Code integration
   - Gather feedback before investing in Phase 2/3
   - Can always deprecate if adoption is low

3. **Complements Existing Tools**
   - Doesn't replace CLI (still works for CI/CD, terminal users)
   - Doesn't replace MCP server (still works for Claude Desktop)
   - Just adds visual layer for VS Code users

4. **Low Risk**
   - Extension is thin wrapper (no complex logic)
   - If it breaks, users fall back to CLI
   - Easy to maintain (calls existing tools)

### What NOT to Build (Yet)

- ❌ Custom WPCC scanner in TypeScript (duplicate effort)
- ❌ AI agent integration (MCP server already does this)
- ❌ Complex UI (keep it simple: sidebar + status bar)
- ❌ Settings panel (use CLI flags for now)

---

## 📋 Phase 1 MVP Spec

### Features (Priority Order)

1. **Scan Button** - Sidebar button "Scan with WPCC"
2. **Results Tree View** - Expandable list of issues by severity
3. **Click to Jump** - Click issue → opens file at line number
4. **Status Bar** - Shows issue count, click to open sidebar
5. **Auto-Detect AI-DDTK** - Checks `~/bin/ai-ddtk`, shows warning if missing
6. **Auto-Load AGENTS.md** - Adds to workspace context for AI agents

### Non-Features (Explicitly Out of Scope)

- ❌ Inline annotations (Phase 2)
- ❌ Quick fixes (Phase 2)
- ❌ Temp folder UI (Phase 2)
- ❌ Settings panel (use CLI flags)
- ❌ Custom scanner (use CLI)

### Success Metrics

- **Adoption**: 50+ installs in first month
- **Usage**: 10+ scans per user per week
- **Feedback**: 4+ star rating on marketplace
- **Retention**: 70%+ users still active after 30 days

---

## 🚀 Next Steps (If You Want to Build It)

### 1. Create Extension Scaffold (30 min)
```bash
npm install -g yo generator-code
yo code  # Choose "New Extension (TypeScript)"
```

### 2. Implement Core Features (2 days)
- Scan button → calls `wpcc --paths . --format json`
- Parse JSON → build tree view
- Click handler → open file at line
- Status bar widget

### 3. Test with Real Projects (1 day)
- Scan actual WordPress plugins
- Verify results match CLI output
- Test on macOS, Windows, Linux

### 4. Publish to Marketplace (1 day)
- Create publisher account
- Write README with screenshots
- Submit for review
- Announce on GitHub, Twitter, etc.

---

## 🎬 Final Verdict

**YES, build a VS Code extension, BUT:**

1. **Start with Phase 1 MVP** (2-3 days)
2. **Keep it simple** (wrapper around CLI)
3. **Validate demand** (50+ installs, 4+ stars)
4. **Then decide** on Phase 2/3 based on feedback

**The extension should be:**
- ✅ **Optional enhancement** (not required)
- ✅ **Thin wrapper** (CLI does the work)
- ✅ **Beginner-friendly** (visual UI for JSON results)
- ✅ **Complementary** (works alongside CLI, MCP server)

**Don't build it if:**
- ❌ You don't have 2-3 days to invest
- ❌ You're not willing to maintain it long-term
- ❌ Current CLI + MCP setup is "good enough"

**My gut feeling**: **Build it.** The visual UI for WPCC results alone is worth it, and auto-loading AGENTS.md into AI agent context is a killer feature for beginners.

Would you like me to create a detailed spec for the Phase 1 MVP, or start scaffolding the extension?
