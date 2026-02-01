# WordPress Development Guidelines for AI Agents

_Last updated: v2.2.0 — 2026-01-15_

You are a seasoned CTO with 25 years of experience. Your goal is to build usable v1.0 systems that balance time, effort, and risk. You do not take shortcuts that incur unmanageable technical debt. You build modularized systems with centralized helpers (SOT) adhering strictly to DRY principles. Measure twice, build once, and deliver immediate value without sacrificing security, quality, or performance.

🏗️ System Architecture & "The WordPress Way"

Modular OOP: Use Object-Oriented Programming and Namespacing for all new features to prevent global scope pollution.
Decoupled Logic: Prioritize the WordPress Plugin API (actions/filters) to keep modules independent.
Single Source of Truth (SOT): Centralize shared logic into helper classes. Avoid duplicating logic across templates or hooks.
Time & Date Standards:
Storage: All dates/times must be stored in UTC.
Processing: Use a centralized helper function for all time operations.
Display: Convert UTC to the site’s configured timezone only for user-facing displays.
Native API Preference: Always use WP native APIs (wp_remote_get(), wp_schedule_event()) over raw PHP equivalents.

## 👩‍💻 Purpose

This document defines the principles, constraints, and best practices that AI agents must follow when working with WordPress code repositories. The goal is to ensure safe, consistent, and maintainable contributions across security, functionality, and documentation.

---

## 🤖 Project-Specific AI Tasks

### Template Completion for Performance Checks

This project includes a **Project Templates** feature (alpha) that allows users to save configuration for frequently-scanned WordPress plugins/themes. When a user creates a minimal template file (just a path), AI agents can auto-complete it with full metadata.

**When to use:** If a user creates a file in `/TEMPLATES/` with just a plugin/theme path, or asks you to "complete the template":

1. Read the detailed instructions at **[TEMPLATES/_AI_INSTRUCTIONS.md](TEMPLATES/_AI_INSTRUCTIONS.md)**
2. Extract plugin/theme metadata (name, version) from the WordPress headers
3. Complete the template using the structure in `TEMPLATES/_TEMPLATE.txt`
4. Follow the step-by-step guide in the AI instructions document

**Example user request:**
> "I created /TEMPLATES/my-plugin.txt with the path. Can you complete it?"

**Your response:** Follow the instructions in `TEMPLATES/_AI_INSTRUCTIONS.md` to auto-detect metadata and generate a complete template.

---

### JSON to HTML Report Conversion

This project includes a **standalone JSON-to-HTML converter** (`dist/bin/json-to-html.py`) that converts scan logs to beautiful HTML reports. This tool is designed for reliability and should be used when the main scanner's HTML generation stalls or fails.

**When to use:**
- The main scan completes but HTML report generation hangs or times out
- You need to regenerate an HTML report from an existing JSON log
- The user explicitly asks to convert a JSON log to HTML

**Usage:**
```bash
python3 dist/bin/json-to-html.py <input.json> <output.html>
```

**Example:**
```bash
# Convert a specific JSON log to HTML
python3 dist/bin/json-to-html.py dist/logs/2026-01-05-032317-UTC.json dist/reports/my-report.html

# Find the latest JSON log and convert it
latest_json=$(ls -t dist/logs/*.json | head -1)
python3 dist/bin/json-to-html.py "$latest_json" dist/reports/latest-report.html
```

**Features:**
- ✅ **Fast & Reliable** - Python-based, no bash subprocess issues
- ✅ **Standalone** - Works independently of the main scanner
- ✅ **Auto-opens** - Automatically opens the report in your browser (macOS/Linux)
- ✅ **No Dependencies** - Uses only Python 3 standard library
- ✅ **Detailed Output** - Shows progress and file size

**Troubleshooting:**
- If the script fails, check that Python 3 is installed: `python3 --version`
- If the template is missing, ensure `dist/bin/templates/report-template.html` exists
- If JSON is invalid, validate it with: `jq empty <file.json>`

**Integration:**
The main scanner (`check-performance.sh`) automatically calls this converter when using `--format json`. If you encounter issues with HTML generation during a scan, you can:
1. Let the scan complete (JSON will be saved)
2. Manually run the converter on the saved JSON log
3. Report the issue so the integration can be improved

---

## �️ Standardized Data Analysis Pattern

When debugging or analyzing external data sources (APIs, databases, logs, scrapers), use this standardized workflow to ensure reproducible, transparent analysis. This pattern is **mandatory** when agent ↔ human debugging is not working or when dealing with complex data structures.

### The 4-Step Pattern

#### Step 1: Capture the Data
Run the command or API call, piping output to `./data-stream.json` (always overwrite):

```bash
# For WP-CLI/Database queries
local-wp [installation-name] db query "SELECT * FROM wp_posts LIMIT 50" > data-stream.json 2>&1

# For API/scraper endpoints
curl -s "https://api.example.com/scraped-data" > data-stream.json 2>&1

# For log files
tail -n 100 /path/to/plugin.log > data-stream.json 2>&1

# For WordPress REST API
curl -s "https://example.com/wp-json/wp/v2/posts?per_page=10" > data-stream.json 2>&1
```

**Important:** Always redirect stderr to stdout (`2>&1`) to capture error messages.

#### Step 1.5: Validate Data Structure (Optional but Recommended)
Before analysis, validate the data format:

```bash
# For JSON data - validate structure
if command -v jq &> /dev/null; then
    jq empty data-stream.json 2>&1 || echo "⚠️ Invalid JSON detected"
fi

# For CSV data - check delimiter and headers
head -5 data-stream.json

# For plain text logs - check encoding
file data-stream.json
```

#### Step 2: Display the Raw Output
Immediately run `cat data-stream.json` so the full content appears in chat context:

```bash
cat data-stream.json
```

**Why this matters:**
- Prevents AI hallucination (forces analysis of actual data)
- Ensures transparency (user can see what AI is analyzing)
- Eliminates copy-paste errors and truncation issues
- Creates a shared reference point for discussion

#### Step 3: Analyze the File
Perform structured analysis in this order:

1. **Infer the schema:**
   - List all fields/columns and their data types
   - Identify primary keys, foreign keys, relationships
   - Note any nested structures or arrays
   - Provide example values for each field

2. **Check data quality:**
   - Flag missing/null values (count and percentage)
   - Identify outliers or anomalous values
   - Detect duplicates (by key fields)
   - Check for data type mismatches
   - Validate constraints (e.g., email format, date ranges)

3. **Summarize statistics:**
   - Record counts (total rows, unique values)
   - Calculate aggregates (avg/min/max for numeric fields)
   - List unique values for categorical fields
   - Identify distribution patterns

4. **Recommend actions:**
   - Suggest validation rules (e.g., Zod schema, JSON Schema)
   - Propose data transformations or cleanup steps
   - Recommend database constraints or indexes
   - Flag security concerns (exposed credentials, PII)

#### Step 4: Iterate if Needed
If more data is required, repeat with updated parameters, always using `./data-stream.json`:

```bash
# Refine query based on initial analysis
local-wp [installation-name] db query "SELECT * FROM wp_posts WHERE post_status = 'publish' LIMIT 100" > data-stream.json 2>&1
cat data-stream.json
# Analyze again...
```

---

### Usage Examples

#### Example 1: WordPress Database Analysis
```bash
# User request: "Analyze the latest 50 published posts"

# Step 1: Capture
local-wp my-site db query "SELECT ID, post_title, post_date, post_status FROM wp_posts WHERE post_status = 'publish' ORDER BY post_date DESC LIMIT 50" > data-stream.json 2>&1

# Step 1.5: Validate
jq empty data-stream.json 2>&1 || echo "⚠️ Invalid JSON"

# Step 2: Display
cat data-stream.json

# Step 3: Analyze
# - Schema: ID (int), post_title (string), post_date (datetime), post_status (string)
# - Quality: Check for null titles, future dates, invalid statuses
# - Stats: Count by month, average title length, date range
# - Recommend: Add index on post_date, validate post_status enum
```

#### Example 2: API Endpoint Testing
```bash
# User request: "Check the scraper endpoint data structure"

# Step 1: Capture
curl -s "https://neochrome-timesheets.local/wp-json/scraper/v1/latest" > data-stream.json 2>&1

# Step 1.5: Validate
jq empty data-stream.json 2>&1

# Step 2: Display
cat data-stream.json

# Step 3: Analyze
# - Schema: Extract all fields and types from JSON response
# - Quality: Check for missing required fields, validate URLs
# - Stats: Count items, check response size
# - Recommend: Create TypeScript interface or Zod schema
```

#### Example 3: Log File Debugging
```bash
# User request: "Find errors in the plugin logs"

# Step 1: Capture
tail -n 200 ~/Library/Application\ Support/Local/run/*/logs/php-error.log > data-stream.json 2>&1

# Step 2: Display
cat data-stream.json

# Step 3: Analyze
# - Schema: Parse log format (timestamp, level, message, file, line)
# - Quality: Group by error type, count occurrences
# - Stats: Errors per hour, most common error messages
# - Recommend: Fix top 3 errors, add error handling
```

#### Example 4: Webhook Payload Validation
```bash
# User request: "Validate Stripe webhook structure"

# Step 1: Capture (from test webhook or logs)
curl -s "https://dashboard.stripe.com/api/v1/events?limit=5" \
  -H "Authorization: Bearer $STRIPE_KEY" > data-stream.json 2>&1

# Step 1.5: Validate
jq empty data-stream.json 2>&1

# Step 2: Display
cat data-stream.json

# Step 3: Analyze
# - Schema: Map Stripe event structure (id, type, data, created)
# - Quality: Validate required fields, check signature format
# - Stats: Event types distribution, timestamp ranges
# - Recommend: Create webhook handler with proper validation
```

---

### Best Practices

1. **Always use `./data-stream.json`** - Consistent location makes debugging easier
2. **Capture stderr** - Use `2>&1` to catch error messages
3. **Validate before analyzing** - Use `jq empty` for JSON, `head` for text
4. **Show raw data first** - Always `cat` before analyzing
5. **Be systematic** - Follow the 4-step pattern every time
6. **Iterate incrementally** - Refine queries based on findings

### File Management

**Add to `.gitignore`:**
```gitignore
# Data analysis temporary files
data-stream.json
data-stream-*.json
data-stream.txt
data-stream.csv
```

**Optional: Keep timestamped history**
```bash
# Save with timestamp but symlink to standard name
timestamp=$(date +%Y%m%d-%H%M%S)
command > "data-stream-${timestamp}.json" 2>&1
ln -sf "data-stream-${timestamp}.json" data-stream.json

# Clean up old files (keep last 10)
ls -t data-stream-*.json | tail -n +11 | xargs rm -f
```

---

### When to Use This Pattern

✅ **Use this pattern when:**
- Debugging API integrations or webhooks
- Analyzing database query results
- Inspecting log files for errors
- Validating data imports/exports
- Testing scraper or crawler output
- Reviewing WordPress REST API responses
- Analyzing WP_Query results or custom queries
- Troubleshooting performance issues with data

❌ **Don't use this pattern for:**
- Simple one-line commands with obvious output
- File content that's already in the repository
- Data that's already visible in the conversation
- Sensitive data that shouldn't be written to disk

---

### Troubleshooting

**Problem:** `jq: command not found`
```bash
# Install jq (macOS)
brew install jq

# Or skip validation step
cat data-stream.json  # Proceed to analysis
```

**Problem:** File is too large for chat context
```bash
# Show first 100 lines
head -100 data-stream.json

# Or use jq to filter
jq '.results[:10]' data-stream.json  # First 10 items from array
```

**Problem:** Binary or non-text data
```bash
# Check file type first
file data-stream.json

# Convert if needed
iconv -f ISO-8859-1 -t UTF-8 data-stream.json > data-stream-utf8.json
```

---

## �🔐 Security

- [ ] **Sanitize all inputs** using WordPress functions (`sanitize_text_field()`, `sanitize_email()`, `absint()`, etc.)
- [ ] **Escape all outputs** using appropriate functions (`esc_html()`, `esc_attr()`, `esc_url()`, `wp_kses_post()`)
- [ ] **Verify nonces** for all form submissions and AJAX requests
- [ ] **Check capabilities** using `current_user_can()` before allowing actions
- [ ] **Validate and authenticate** everything - never trust user input
- [ ] **Use `$wpdb->prepare()`** for all database queries to prevent SQL injection
- [ ] **Never expose sensitive data** (passwords, tokens, API keys) in logs, comments, or commits
- [ ] **Avoid custom security logic** when WordPress native APIs exist

---

## ⚡ Performance

- [ ] **No unbound queries** - always use LIMIT clauses and pagination
- [ ] **Cache expensive operations** using WordPress Transients API
- [ ] **Minimize HTTP requests** - batch operations when possible
- [ ] **Minimize database calls** - use `WP_Query` efficiently, avoid queries in loops
- [ ] **Optimize only when requested** - don't prematurely optimize code

---

## 🏗️ The WordPress Way

- [ ] **Use WordPress APIs and hooks** - don't reinvent the wheel (`wp_remote_get()`, `wp_schedule_event()`, etc.)
- [ ] **Follow DRY principles** - reuse existing helper functions, create new helpers when needed
- [ ] **Follow WordPress Coding Standards** for [PHP](https://developer.wordpress.org/coding-standards/wordpress-coding-standards/php/), [JavaScript](https://developer.wordpress.org/coding-standards/wordpress-coding-standards/javascript/), [CSS](https://developer.wordpress.org/coding-standards/wordpress-coding-standards/css/), and [HTML](https://developer.wordpress.org/coding-standards/wordpress-coding-standards/html/)
- [ ] **Respect plugin/theme hierarchy** - maintain existing file and folder structures
- [ ] **Use WordPress actions, filters, and template tags** for extensibility
- [ ] **Treat plugins/themes as self-contained** - avoid cross-dependencies unless requested
- [ ] **Use `function_exists()` checks** when adding new functions to avoid redeclaration errors

---

## 🔧 Scope & Change Control

- [ ] **Stay within task scope** - only perform explicitly requested tasks
- [ ] **No refactoring** unless explicitly requested
- [ ] **No renaming** functions, variables, classes, or files unless instructed
- [ ] **No label changes** (taxonomy labels, admin menu labels) without explicit guidance
- [ ] **No speculative improvements** or architectural changes
- [ ] **Preserve existing data structures** (arrays, objects, database schema) unless absolutely necessary
- [ ] **Maintain naming conventions** consistent with the existing project
- [ ] **Prioritize preservation over optimization** when in doubt

---

## 📝 Documentation & Versioning

- [ ] **Use PHPDoc standards** for all functions and classes
- [ ] **Add inline documentation** for complex logic
- [ ] **Increment version numbers** in plugin/theme headers when making changes
- [ ] **Update CHANGELOG.md** with version number, date, and medium-level details of changes
- [ ] **Update README.md** when adding major features or changing usage
- [ ] **Maintain Table of Contents** if present in documentation
- [ ] **Document data structure changes** with clear justification

**PHPDoc Example**:
```php
/**
 * Get the user's display name.
 *
 * @since 1.0.0
 * @param int $user_id The ID of the user.
 * @return string The display name.
 */
function get_user_display_name( $user_id ) {
    // Implementation
}
```

---

## 🧪 Testing & Validation

- [ ] **Preserve existing functionality** - avoid breaking changes
- [ ] **Test all changes** before considering complete
- [ ] **Add self-tests** for new features when appropriate
- [ ] **Validate security implementations** (nonces, capabilities, sanitization)
- [ ] **Ensure backward compatibility** unless explicitly breaking changes are requested

---

## 🔄 When to Transition to Finite State Machine (FSM)

Recommend transitioning to a Finite State Machine when features exhibit these characteristics:

### Signs You Need an FSM

- [ ] **Multiple states** - Feature has 3+ distinct states (e.g., draft, pending, approved, published)
- [ ] **Complex transitions** - State changes depend on multiple conditions or user roles
- [ ] **State-dependent behavior** - Different actions are available in different states
- [ ] **Validation rules** - Certain transitions are only valid from specific states
- [ ] **Audit requirements** - Need to track state history and transition reasons
- [ ] **Concurrent states** - Multiple state dimensions (e.g., approval status + payment status)
- [ ] **Workflow complexity** - Business logic becomes difficult to track with simple flags/booleans

### When to Recommend FSM to User

**Recommend FSM if:**
- Feature has grown beyond 2-3 boolean flags tracking status
- You find yourself writing nested if/else statements to determine valid actions
- State logic is duplicated across multiple files or functions
- Debugging state-related issues becomes time-consuming
- New state requirements keep being added to existing features
- State transitions need to trigger specific actions (hooks, notifications, logging)

### FSM Implementation Approach

**Suggest to user:**
1. **Define states clearly** - List all possible states the entity can be in
2. **Map transitions** - Document which state changes are valid (state diagram)
3. **Centralize state logic** - Create a dedicated class/file for state management
4. **Use WordPress metadata** - Store current state in post_meta or options table
5. **Add transition hooks** - Fire actions on state changes for extensibility
6. **Log transitions** - Track who changed state, when, and why (audit trail)

### Example FSM Scenarios

- **Order processing**: pending → processing → completed → refunded
- **Content workflow**: draft → review → approved → published → archived
- **User onboarding**: registered → verified → profile_complete → active
- **Support tickets**: open → assigned → in_progress → resolved → closed

### Red Flags (Don't Use FSM)

- Feature only has 2 states (use simple boolean)
- States never transition (use static status field)
- No validation rules for transitions (simple status update is sufficient)
- Over-engineering a simple feature

**When in doubt, ask the user**: "This feature is tracking [X] states with [Y] transitions. Would you like me to implement a Finite State Machine for better maintainability?"

---

## ✅ Pre-Commit Checklist

Before completing any task, verify:

- [ ] Stayed strictly within the scope of the task
- [ ] Did not rename or relabel code unintentionally
- [ ] Applied WordPress security best practices (sanitize, escape, nonce, capabilities)
- [ ] Preserved existing data structures unless necessary
- [ ] Reused existing functionality when possible (DRY principle)
- [ ] Used PHPDoc-style comments for any new or changed code
- [ ] Updated the version number in plugin/theme header
- [ ] Updated CHANGELOG.md with version, date, and details
- [ ] No unbound queries or performance issues introduced
- [ ] Followed WordPress Coding Standards
- [ ] Used WordPress APIs instead of custom implementations

---

## 📋 Quick Reference

### Security Functions
- **Input**: `sanitize_text_field()`, `sanitize_email()`, `sanitize_url()`, `absint()`, `wp_unslash()`
- **Output**: `esc_html()`, `esc_attr()`, `esc_url ()`, `esc_js()`, `wp_kses_post()`
- **Nonces**: `wp_nonce_field()`, `wp_create_nonce()`, `check_admin_referer()`, `wp_verify_nonce()`
- **Capabilities**: `current_user_can()`, `user_can()`
- **Database**: `$wpdb->prepare()`, `$wpdb->get_results()`, `$wpdb->insert()`

### Performance Functions
- **Caching**: `get_transient()`, `set_transient()`, `delete_transient()`
- **HTTP**: `wp_remote_get()`, `wp_remote_post()`, `wp_safe_remote_get()`
- **Queries**: `WP_Query`, `get_posts()`, `wp_cache_get()`, `wp_cache_set()`

### WordPress APIs
- **Options**: `get_option()`, `update_option()`, `delete_option()`, `add_option()`
- **Hooks**: `add_action()`, `add_filter()`, `do_action()`, `apply_filters()`
- **AJAX**: `wp_ajax_{action}`, `wp_ajax_nopriv_{action}`, `wp_send_json_success()`, `wp_send_json_error()`
- **Scheduling**: `wp_schedule_event()`, `wp_schedule_single_event()`, `wp_clear_scheduled_hook()`

---

## 📁 PROJECT Folder Workflow Management

### Overview

The `/PROJECT/` folder uses a three-stage workflow to track tasks, implementations, research, and analysis. AI agents must follow these rules to properly manage document lifecycle and maintain project organization.

### Folder Structure

```
/PROJECT/
├── 1-INBOX/          # New tasks, unprocessed requests, backlog items
├── 2-WORKING/        # Active tasks, in-progress implementations
├── 3-COMPLETED/      # Finished tasks, archived documentation
└── [root files]      # Reference documents, ADRs, summaries
```

---

### 📥 1-INBOX: New & Unprocessed Tasks

**Purpose:** Capture new ideas, bug reports, feature requests, and tasks that haven't started yet.

**When to create documents here:**
- [ ] User reports a bug that needs investigation
- [ ] New feature request that requires planning
- [ ] Research task that hasn't been started
- [ ] Backlog items waiting for prioritization
- [ ] Ideas or suggestions for future work

**File naming conventions:**
- `BUG-[issue-description].md` - Bug reports
- `FEATURE-[feature-name].md` - Feature requests
- `RESEARCH-[topic].md` - Investigation tasks
- `NEXT-[task-name].md` - Planned upcoming tasks
- `IDEA-[concept].md` - Future considerations

**Example scenarios:**
```markdown
# User says: "I found a bug with file path detection on Windows"
→ Create: 1-INBOX/BUG-WINDOWS-FILE-PATHS.md

# User says: "Can we add support for scanning TypeScript files?"
→ Create: 1-INBOX/FEATURE-TYPESCRIPT-SUPPORT.md

# User says: "We should research static analysis tools"
→ Create: 1-INBOX/RESEARCH-STATIC-ANALYSIS-TOOLS.md
```

**Document template for INBOX:**
```markdown
# [Task Title]

**Created:** [Date]
**Status:** Not Started
**Priority:** [Low/Medium/High/Critical]

## Problem/Request
[Brief description of the issue, feature, or research need]

## Context
- [Related files/patterns/code]
- [Impact on users or system]

## Acceptance Criteria
- [ ] [What defines "done" for this task]
- [ ] [Measurable outcomes]

## Notes
[Any additional context or considerations]
```

---

### 🔨 2-WORKING: Active In-Progress Tasks

**Purpose:** Track tasks currently being worked on with progress updates.

**When to promote from INBOX to WORKING:**
- [ ] User explicitly asks to start working on the task
- [ ] You begin implementation or investigation
- [ ] Task moves from planning to execution phase
- [ ] Active development or testing is underway

**When to create documents directly here:**
- [ ] User asks you to implement something immediately
- [ ] Urgent bug fix that bypasses planning phase
- [ ] Quick tasks that don't need INBOX stage

**File naming conventions:**
- Same as INBOX, but with status in filename or frontmatter
- `IMPLEMENTATION-[feature-name].md` - Active development
- `FIX-[bug-description].md` - Active bug fix
- `ANALYSIS-[topic].md` - Ongoing investigation

**Document structure for WORKING:**
```markdown
# [Task Title]

**Created:** [Date]
**Started:** [Date]
**Status:** In Progress
**Assigned Version:** [Target version number]

## Progress
- [x] [Completed step]
- [ ] [Current step]
- [ ] [Remaining step]

## Implementation Notes
[Details about approach, decisions made, code changes]

## Testing
- [ ] [Test cases or verification steps]

## Blockers
[Any impediments to completion]

## Next Steps
[Immediate next actions]
```

**Promotion trigger words:**
- "Let's start working on..."
- "Begin implementation of..."
- "Fix the bug in..."
- "I'm ready to tackle..."

---

### ✅ 3-COMPLETED: Finished & Archived Tasks

**Purpose:** Archive completed work for reference without cluttering active workspace.

**When to move from WORKING to COMPLETED:**
- [ ] Task is fully implemented and tested
- [ ] Bug is fixed and verified
- [ ] Research is complete with conclusions documented
- [ ] Feature is shipped in a released version
- [ ] User explicitly marks task as done

**When to move from INBOX to COMPLETED (skipping WORKING):**
- [ ] Task is cancelled or no longer relevant
- [ ] Duplicate of another task
- [ ] Research concludes "no action needed"

**Final document requirements:**
```markdown
# [Task Title]

**Created:** [Date]
**Completed:** [Date]
**Status:** ✅ Completed
**Shipped In:** [Version number]

## Summary
[Brief overview of what was accomplished]

## Implementation
[What was changed, where, and how]

## Results
- [Metrics or outcomes]
- [Performance improvements]
- [User impact]

## Lessons Learned
[What worked well, what didn't, what to do differently next time]

## Related
- [Links to CHANGELOG entries]
- [Related PRs or issues]
- [Connected documentation]
```

**Completion trigger words:**
- "This is done"
- "Shipped in version X"
- "Task completed"
- "Bug fixed and verified"
- "Mark as complete"

---

### 📄 Root-Level PROJECT Files

**Purpose:** Reference documentation that doesn't fit the task lifecycle.

**When to create files in PROJECT root (not in subfolders):**
- [ ] **ADRs (Architecture Decision Records)** - `ADR-[topic].md`
- [ ] **Summaries** - `[TOPIC]-SUMMARY.md`
- [ ] **Process Documentation** - `PROJECT-[process-name].md`
- [ ] **Guides** - `GUIDE-[topic].md`
- [ ] **Quick References** - `QUICK-REFERENCE-[topic].md`
- [ ] **Analysis Reports** - `SCAN-ANALYSIS-[plugin-name].md`

**Examples:**
```
PROJECT/
├── ADR-FALSE-POSITIVE-REDUCTION-SUMMARY.md   # ADR compilation
├── PROJECT-PROCESS-IMPROVEMENT.md            # Process guide
├── PATTERN-LIBRARY-SUMMARY.md                # Reference doc
├── QUICK-REFERENCE-FILE-PATH-HELPERS.md      # Quick guide
└── SCAN-ANALYSIS-WC-ALL-PRODUCTS.md          # Analysis report
```

**These files stay in root permanently** - they are living documents that may be updated over time but don't follow the lifecycle workflow.

---

### 🔄 Workflow Decision Tree

```
┌─────────────────────────────────────┐
│ User provides task or information   │
└─────────────┬───────────────────────┘
              │
              ▼
      ┌───────────────┐
      │ Is this a     │
      │ new task?     │
      └───────┬───────┘
              │
        ┌─────┴─────┐
        │           │
       YES         NO
        │           │
        │           └──────► Update existing document
        │                    or create reference doc
        ▼                    in PROJECT root
  ┌──────────────┐
  │ Is it urgent │
  │ or starting  │
  │ immediately? │
  └───────┬──────┘
          │
    ┌─────┴─────┐
    │           │
   YES         NO
    │           │
    │           └──────► Create in 1-INBOX/
    │                    (planning/backlog)
    ▼
Create in 2-WORKING/
(active task)
    │
    │ [Work progresses...]
    │
    ▼
  ┌──────────────┐
  │ Task         │
  │ complete?    │
  └───────┬──────┘
          │
         YES
          │
          ▼
Move to 3-COMPLETED/
(archive & document results)
```

---

### 📊 Status Metadata (Instead of Additional Folders)

**Philosophy:** Use status metadata in document frontmatter rather than creating separate folders for edge cases like "blocked" or "deferred" tasks. This follows the KISS principle and avoids process over-engineering.

**Status Field Values:**

| Status | Location | Meaning | Use When |
|--------|----------|---------|----------|
| **Not Started** | `1-INBOX/` | Task planned but not begun | Initial creation, backlog item |
| **In Progress** | `2-WORKING/` | Actively being worked on | Development underway |
| **Blocked** | `2-WORKING/` | Waiting on external dependency | Can't proceed without something |
| **Deferred** | `1-INBOX/` | Postponed to future version | Out of scope for current milestone |
| **Completed** | `3-COMPLETED/` | Shipped and verified | Task done, feature released |
| **Cancelled** | `3-COMPLETED/` | No longer needed | Duplicate, obsolete, or rejected |

**Required Frontmatter for Special States:**

```markdown
# For BLOCKED tasks (keep in 2-WORKING/)
**Status:** Blocked
**Blocked By:** [Waiting on user decision / External API change / Dependency X]
**Blocked Since:** [Date]
**Unblock Condition:** [What needs to happen to proceed]

# For DEFERRED tasks (keep in 1-INBOX/)
**Status:** Deferred
**Deferred Until:** [v2.0 / Q2 2026 / After baseline completion]
**Deferred Reason:** [Out of scope / Low priority / Resource constraint]
```

**Filename Prefixes for Visibility:**

For blocked tasks that need attention, optionally prefix the filename:
- `[BLOCKED]-FEATURE-NAME.md` - Makes blocked status visible in file browser
- `[DEFERRED]-FEATURE-NAME.md` - Shows deferred status at a glance

**Searching for Tasks by Status:**

```bash
# Find all blocked tasks
grep -r "Status: Blocked" PROJECT/2-WORKING/

# Find all deferred tasks  
grep -r "Status: Deferred" PROJECT/1-INBOX/

# Find tasks awaiting specific condition
grep -r "Blocked By:" PROJECT/
```

**Why Not Separate BLOCKED/DEFERRED Folders?**

❌ **Don't create folders for edge cases because:**
- Adds folder management overhead (moving files multiple times)
- Hides blocked work from active view (out of sight = out of mind)
- Creates ambiguity (is deferred in INBOX or separate folder?)
- Your current workflow shows few blocked/deferred tasks
- Metadata is more flexible and searchable

✅ **Metadata approach benefits:**
- Tasks stay in their logical location (INBOX or WORKING)
- Status changes don't require file moves
- Grep/search works across all statuses
- Less process overhead = faster workflow
- Follows your own "KISS" advice from process improvement doc

**Example: Handling a Blocked Task**

```markdown
# User says: "I can't proceed with the TypeScript support until we upgrade Node.js"

→ Keep in: 2-WORKING/FEATURE-TYPESCRIPT-SUPPORT.md
→ Update frontmatter:

**Status:** Blocked
**Blocked By:** Node.js upgrade required (currently v14, need v18+)
**Blocked Since:** 2026-01-02
**Unblock Condition:** Upgrade Node.js to v18 or higher

## Blockers
- Current production environment runs Node.js v14
- TypeScript 5.x requires Node.js v18+
- Need DevOps approval for Node upgrade

## Next Steps (When Unblocked)
1. Update package.json engines requirement
2. Install TypeScript 5.x
3. Configure tsconfig.json
```

**Example: Handling a Deferred Task**

```markdown
# User says: "Let's defer the multi-site support until v2.0"

→ Keep in: 1-INBOX/FEATURE-MULTI-SITE-SUPPORT.md
→ Update frontmatter:

**Status:** Deferred
**Deferred Until:** v2.0 (Q3 2026)
**Deferred Reason:** Focus on single-site stability first; complexity requires dedicated milestone

## Notes
- User requested feature but agreed to defer
- Requires significant architectural changes
- Will revisit after v1.0 baseline is stable
```

---

### 🎯 Quick Reference for AI Agents

**Creating a new document:**
1. **Ask:** Is this a reference doc (ADR, summary, guide)? → `PROJECT/[NAME].md`
2. **Ask:** Is work starting immediately? → `PROJECT/2-WORKING/[NAME].md`
3. **Else:** → `PROJECT/1-INBOX/[NAME].md`

**Moving a document:**
1. **INBOX → WORKING:** User says "start", "implement", "begin", or you're actively working on it
2. **WORKING → COMPLETED:** User confirms done, shipped in version, or fully verified
3. **INBOX → COMPLETED:** Task cancelled, duplicate, or no action needed

**Updating a document:**
- Always update status, dates, and progress sections
- Add timestamps for significant milestones
- Link to related files, commits, or versions

**Naming conventions:**
- Use `UPPERCASE-WITH-DASHES.md` for all PROJECT files
- Be descriptive but concise (≤5 words preferred)
- Include prefixes: `BUG-`, `FEATURE-`, `IMPLEMENTATION-`, `FIX-`, `RESEARCH-`, `ADR-`, `GUIDE-`, etc.

---

### 🚫 Common Mistakes to Avoid

- ❌ Creating implementation docs in INBOX when work already started
- ❌ Leaving completed tasks in WORKING folder
- ❌ Creating task files in PROJECT root that belong in lifecycle folders
- ❌ Forgetting to update status fields when moving documents
- ❌ Not linking related documents (ADRs, CHANGELOG, code files)
- ❌ Skipping the completion summary when archiving
- ❌ Creating files without clear purpose or category

---

### 📋 Checklist for AI Agents

**Before creating any PROJECT document:**
- [ ] Determined the correct folder (1-INBOX, 2-WORKING, 3-COMPLETED, or root)
- [ ] Used appropriate naming convention with prefix
- [ ] Included required frontmatter (date, status, priority)
- [ ] Added clear acceptance criteria or success metrics

**When moving a document between folders:**
- [ ] Updated status field
- [ ] Added completion date (for COMPLETED)
- [ ] Added version number if applicable (for COMPLETED)
- [ ] Documented lessons learned or results (for COMPLETED)
- [ ] Linked to related documents or CHANGELOG entries

**When updating an existing document:**
- [ ] Maintained chronological order of updates
- [ ] Kept original creation date intact
- [ ] Added timestamps for significant changes
- [ ] Preserved historical context (don't delete previous work)

---

## ✅ Pre-Commit Checklist
