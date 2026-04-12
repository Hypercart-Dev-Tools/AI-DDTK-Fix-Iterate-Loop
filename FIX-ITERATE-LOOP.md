# Fix-Iterate Loop

> Closed-loop autonomous testing for AI coding agents

## Why This Exists

AI agents are good at writing code. They're bad at knowing when it actually works. Without a feedback loop, agents generate code, declare victory, and move on — leaving you to discover the breakage later.

The Fix-Iterate Loop solves this by giving agents a structured pattern: **make a change, verify it programmatically, and iterate until it actually passes** — without human intervention for routine fixes, but with hard guardrails to prevent runaway sessions.

This pattern works with any AI coding agent (Claude Code, Augment, Codex, Cursor, etc.) and any tech stack.

---

## Core Workflow

```
┌─────────────┐
│ 1. Generate  │ Create test data (JSON, SQL, API payload, etc.)
│    Test Data │
└──────┬──────┘
       ▼
┌─────────────┐
│ 2. Execute   │ Submit/import data into the target system
│              │
└──────┬──────┘
       ▼
┌─────────────┐
│ 3. Verify    │ Programmatically check if it worked (curl, CLI, assertions)
│              │
└──────┬──────┘
       ▼
   ┌───────┐    ┌──────────────┐
   │ Pass? │─NO─▶ 4. Analyze   │──┐
   └───┬───┘    │    & Adjust  │  │
       │        └──────────────┘  │
      YES                         │
       ▼                          │
┌─────────────┐          (loop back to 1)
│   ✅ Done    │
└─────────────┘
```

1. **Generate Test Data**: Create structured input for the test case
2. **Execute**: Run the submission/import/API call
3. **Verify**: Use curl, CLI, or assertions to check the result programmatically
4. **Analyze & Adjust**: If verification fails, examine output, adjust approach, repeat

---

## Guardrails

### Hard Stops
- **5 failed iterations**: STOP and report findings to the human
- **10 total iterations**: STOP regardless of status and request guidance
- **Before destructive operations**: Always confirm with human first (database drops, bulk deletes, production changes)

### Simplification Checkpoints

If you find yourself:
- Writing overly complex verification logic → **PAUSE**: Ask human if a simpler approach exists
- Creating multi-step workarounds → **PAUSE**: Suggest refactoring the underlying system
- Repeating the same verification pattern 3+ times → **PAUSE**: Propose extracting it into a reusable function
- Unable to verify programmatically → **PAUSE**: Ask human for manual verification

---

## Iteration Template

For each cycle, the agent should follow this structure:

```
ITERATION N:
1. What I'm testing: [describe goal]
2. Test data: [show input]
3. Command: [show exact command]
4. Expected result: [what should happen]
5. Actual result: [what happened]
6. Verification output: [show raw output]
7. Status: ✅ PASS / ❌ FAIL
8. Next action: [if fail, what to adjust]
```

---

## Meta-Reflection

After each iteration, the agent should add a brief self-assessment. This prevents wasted iterations by surfacing blind spots early.

```
META-REFLECTION (Iteration N):
Confidence: [1-10]
Assumptions Verified:
  ✓ Schema matches expected format
  ✓ Database connection is valid
  ✗ Cache cleared after update (NOT VERIFIED)
Uncertainty:
  - Not sure if config requires restart to take effect
Risk: [LOW / MEDIUM / HIGH]
Continue? [YES / NO / ASK_HUMAN]
```

**Why this matters:**
- Confidence trending downward = wrong direction, stop and rethink
- Confidence trending upward = making progress, keep going
- Unchecked assumptions become the next thing to verify, not ignore

---

## Examples

### WordPress / WooCommerce

```bash
# 1. Generate test data
cat > test-product.json << 'EOF'
{"name": "Test Product", "price": "29.99", "status": "publish"}
EOF

# 2. Submit to system
cat test-product.json | local-wp mysite eval-file import-product.php

# 3. Verify result
PRODUCT_URL=$(local-wp mysite post url $PRODUCT_ID)
curl -s "$PRODUCT_URL" | grep "29.99" && echo "✅ Pass" || echo "❌ Fail"

# 4. If fail → analyze HTML response, adjust JSON, repeat
```

### API Endpoint

```bash
# 1. Generate & submit
curl -X POST https://api.example.com/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User", "email": "test@example.com"}'

# 2. Verify
RESPONSE=$(curl -s https://api.example.com/users/last)
echo "$RESPONSE" | jq -e '.name == "Test User"' && echo "✅ Pass" || echo "❌ Fail"

# 3. If fail → check status code, examine error body, adjust payload, repeat
```

### Database Migration

```bash
# 1. Apply migration
psql -f migrations/001_add_users_table.sql

# 2. Verify schema
psql -c "\d users" | grep "id.*integer.*primary key" && echo "✅ Pass" || echo "❌ Fail"

# 3. If fail → analyze schema, adjust SQL, rollback, repeat
```

### Visual / CSS Debugging

For page builders or design systems that embed CSS in JSON:

```bash
# 1. Extract CSS from JSON into standalone HTML
node extract-css-from-json.js layout.json > test-render.html

# 2. Automated validation
grep -E 'color.*[^#0-9a-fA-F]' test-render.html && echo "❌ Invalid colors"
node validate-css-values.js layout.json  # Check ranges, units, contrast

# 3. Visual inspection
open test-render.html  # macOS

# 4. If issues found → adjust JSON values, regenerate, re-verify
```

---

## When to Stop and Ask for Help

**Stop immediately if:**
- You've tried 5 different approaches and all failed
- Verification returns results you can't explain
- You need to modify production data or systems
- The application itself seems broken (not just your test)
- You're creating increasingly complex workarounds instead of fixing the root issue

**Suggest simplification if:**
- Your verification script exceeds 50 lines
- You're parsing HTML with regex instead of proper tools
- You're chaining 4+ commands to verify one thing
- The same verification pattern appears in 3+ test cases

---

## Success Criteria

The task is complete when:
1. Test data is generated programmatically
2. Submission executes without errors
3. Verification confirms expected behavior
4. Process is repeatable (same results on re-run)
5. All verification commands are documented

---

## Principles

- **Iterate fast** — try the simplest approach first
- **Verify everything** — never assume it worked without checking
- **Document as you go** — each iteration should be traceable
- **Know when to stop** — 5 failed iterations = time to ask for help
- **Simplify when stuck** — complexity usually means wrong approach

---

## Extensions (Future)

Ideas for teams that want to go deeper:

| Extension | Description |
|-----------|-------------|
| **Visual regression** | Integrate Playwright + PixelMatch screenshot diffing into the verify step |
| **YAML iteration summaries** | Auto-generate structured logs per iteration for git history |
| **Performance regression** | Add `curl -w` timing checks to catch load time regressions |
| **Mutation testing** | Systematically mutate test data to explore edge cases |
| **State machine** | Model complex multi-step workflows as finite state machines |

---

## License & Attribution

**Fix-Iterate Loop** is part of [AI-DDTK](https://github.com/Hypercart-Dev-Tools/AI-DDTK) by **Hypercart (a DBA of Neochrome, Inc.)**

Licensed under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).

You are free to share, adapt, and build upon this work — including commercially — as long as you provide attribution:

> Fix-Iterate Loop by Hypercart / AI-DDTK
> https://github.com/Hypercart-Dev-Tools/AI-DDTK

Copyright 2025-2026 Hypercart (a DBA of Neochrome, Inc.)
