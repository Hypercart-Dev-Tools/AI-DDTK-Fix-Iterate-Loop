# GitHub Actions Workflows

## ⚠️ IMPORTANT: Single Workflow Policy

**This repository uses a SINGLE consolidated workflow file: `ci.yml`**

### DO NOT Create Additional Workflow Files

❌ **Do NOT create:**
- Separate workflows for Slack notifications
- Separate workflows for performance audits
- Separate workflows for different branches
- Duplicate workflows with slight variations

✅ **Instead:**
- Edit `ci.yml` to add new functionality
- Use conditional logic for different behaviors
- Use job dependencies for complex workflows
- Use reusable workflows only for external consumption

## Why Single Workflow?

**Problem we had (Dec 2025):**
- 3 separate workflows running simultaneously
- Each PR/push triggered 3+ workflow runs
- Wasted CI resources and created confusion
- Duplicate Slack notifications
- Harder to maintain consistency

**Solution:**
- Consolidated into single `ci.yml` workflow
- Conditional Slack notifications based on event type
- All CI logic in one place
- Easier to maintain and debug

## Current Workflow Structure

### `ci.yml` - Consolidated CI Workflow

**Triggers:**
- `pull_request` to main/development branches (PRIMARY)
- `workflow_dispatch` for manual runs
- Does NOT trigger on `push` to reduce CI noise

**Jobs:**

1. **performance-checks**
   - Runs performance audit in JSON mode
   - Slack notifications:
     - Only sends to Slack when PR audit fails
     - Reduces notification noise while maintaining visibility
   - Uploads audit results as artifacts
   - Handles missing SLACK_WEBHOOK_URL gracefully

2. **validate-test-fixtures**
   - Runs automated fixture validation tests
   - Tests antipattern detection
   - Validates clean code passes checks

### `wp-performance.yml` - Reusable Workflow

**Purpose:** External consumption only (workflow_call)
- Used by other repositories to run performance checks
- NOT triggered by events in this repository
- This is OK to keep as it's not causing duplicate runs

### `example-caller.yml` - Template/Example File

**Purpose:** Documentation and example for plugin developers
- Shows how to use the reusable workflow in other repos
- **DISABLED in this repo** - only triggers on `workflow_dispatch` (manual)
- When copying to your plugin, uncomment the real triggers
- This is OK to keep as it won't run automatically

## How to Modify CI Behavior

### Adding a New Check

```yaml
# Add to ci.yml under the appropriate job
- name: Your new check
  run: |
    echo "Running new check..."
    ./your-script.sh
```

### Changing Slack Notification Logic

```yaml
# Edit the conditional in ci.yml
- name: Post to Slack
  if: your-condition-here
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
  run: |
    ./dist/bin/post-to-slack.sh audit-results.json
```

### Adding a New Job

```yaml
# Add to ci.yml at the jobs level
jobs:
  your-new-job:
    name: Your New Job
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      # ... your steps
```

## Checklist Before Creating a New Workflow

- [ ] Can this be added to `ci.yml` instead?
- [ ] Is this for external consumption (workflow_call)?
- [ ] Have I checked if similar functionality already exists?
- [ ] Will this cause duplicate runs with existing workflows?
- [ ] Have I documented why a separate workflow is necessary?

## Questions?

If you're unsure whether to create a new workflow or modify `ci.yml`, ask yourself:

1. **Does this need to run on the same triggers?** → Add to `ci.yml`
2. **Is this a variation of existing checks?** → Add conditional logic to `ci.yml`
3. **Is this for other repos to consume?** → Create reusable workflow with `workflow_call`
4. **Is this completely unrelated to CI?** → Maybe OK, but document why

For WP Code Check's responsible disclosure and report publication policy, see `../../DISCLOSURE-POLICY.md`.

## History

- **2025-12-31**: Consolidated 3 workflows into 1
  - Removed: `performance-audit-slack.yml`
  - Removed: `performance-audit-slack-on-failure.yml`
  - Enhanced: `ci.yml` with all functionality
  - Created: This README to prevent future duplication

---

**Remember: One workflow to rule them all! 💍**

