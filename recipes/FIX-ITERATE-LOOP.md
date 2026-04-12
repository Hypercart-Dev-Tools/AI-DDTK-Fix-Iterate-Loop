# Recipe: Fix-Iterate Loop

> Autonomous test-verify-fix workflow for AI coding agents

## When to Use

- Bug fixes that need verification
- Data imports / migrations
- API integrations
- Any task where you can programmatically confirm success

## Quick Reference

```
1. Generate test data
2. Execute (submit/import/call)
3. Verify programmatically (curl, CLI, assertions)
4. If fail → analyze, adjust, repeat
```

**Guardrails**: Stop after 5 failed iterations. Stop after 10 total. Confirm before destructive operations.

## Full Documentation

See the complete pattern with iteration templates, meta-reflection, and examples:

**[fix-iterate-loop.md](../fix-iterate-loop.md)**
