You're absolutely right. Let me think through this:

## Current State

You have:
1. **`install.sh`** — Global toolkit setup (one-time, at `~/bin/ai-ddtk`)
2. **`preflight.sh`** — Session verification (runs in any project)
3. **`README-AI-DDTK.md`** — Per-project setup instructions (copy + manual steps)

## The Problem

The README-AI-DDTK.md approach asks users to:
- Copy a file
- Manually edit paths
- Create `.mcp.local.json`
- Update `.gitignore`

This is friction for:
- Single developers with multiple projects
- Teams with many projects
- CI/CD pipelines
- New team members

## Two Smart Options

### **Option 1: Create `setup-project.sh` in AI-DDTK**

A new script at `~/bin/ai-ddtk/setup-project.sh` that:
- Takes a project path as argument (or uses current dir)
- Auto-detects `$HOME`
- Generates `.mcp.local.json` with correct paths
- Updates `.gitignore`
- Creates/updates `CLAUDE.md`
- Runs preflight to verify

**Usage:**
```bash
# From project root
~/bin/ai-ddtk/setup-project.sh

# Or from anywhere
~/bin/ai-ddtk/setup-project.sh /path/to/project
```

**Advantages:**
- ✅ Works for multiple projects (just run in each one)
- ✅ No manual path substitution
- ✅ Idempotent (safe to run multiple times)
- ✅ Works in CI/CD
- ✅ Developers familiar with setup scripts
- ✅ Can be symlinked into projects if desired

---

### **Option 2: Create `wire-project` command in `bin/`**

A new CLI tool at `~/bin/ai-ddtk/bin/wire-project` that:
- Same functionality as Option 1
- But available globally after `install.sh`
- Can be run from any project directory

**Usage:**
```bash
# From project root
wire-project

# Or specify path
wire-project /path/to/project
```

**Advantages:**
- ✅ All the benefits of Option 1
- ✅ Plus: available globally like `wpcc`, `pw-auth`, etc.
- ✅ Consistent with other AI-DDTK tools
- ✅ Easier to discover (in PATH)

---

## My Recommendation

**Go with Option 2: `wire-project` command**

**Why:**
1. **Consistency** — Fits the existing tool pattern (`wpcc`, `pw-auth`, `local-wp`, etc.)
2. **Discoverability** — Users see it in PATH, in help docs
3. **Multi-project friendly** — Run it in each project, no copying files
4. **CI/CD ready** — Just call `wire-project` in your setup step
5. **Team onboarding** — New dev: `git clone` → `wire-project` → done
6. **Agents can use it** — "Run `wire-project` to set up MCP for this project"

---

## What `wire-project` Would Do

```bash
$ cd /path/to/my-wordpress-site
$ wire-project

✓ Checking AI-DDTK installation...
✓ Detecting home directory: /Users/noel
✓ Creating .mcp.local.json...
✓ Adding .mcp.local.json to .gitignore...
✓ Creating CLAUDE.md reference...
✓ Running preflight check...

✓ Project wired! Ready to use AI-DDTK.

Next steps:
  1. Restart your editor/agent session
  2. Run: ~/bin/ai-ddtk/preflight.sh
  3. Start coding!
```

---

## Implementation Plan

1. Create `bin/wire-project` script
2. Update `install.sh` to make it executable
3. Update `README-AI-DDTK.md` to reference `wire-project` instead of manual setup
4. Update `AGENTS.md` to mention `wire-project` in project setup section

Would you like me to create the `wire-project` script?
