# GitHub Issues

This directory contains generated GitHub issue bodies that were not automatically created.

## Purpose

When you run `create-github-issue.sh` without specifying a GitHub repository (via `--repo` flag or `GITHUB_REPO` in template), the issue body is saved here for manual use.

## File Naming Convention

```
GH-issue-{SCAN_ID}.md
```

Example: `GH-issue-2026-01-13-031719-UTC.md`

This matches the naming pattern of:
- JSON logs: `dist/logs/2026-01-13-031719-UTC.json`
- HTML reports: `dist/reports/2026-01-13-031719-UTC.html`

## Usage

### Manual GitHub Issue Creation

1. Open the `.md` file in this directory
2. Copy the entire contents
3. Go to your GitHub repository
4. Click "Issues" → "New Issue"
5. Paste the contents into the issue body
6. Add a title (suggested in the file)
7. Submit the issue

### Project Management Apps

You can also copy/paste these issue bodies into:
- Jira
- Linear
- Asana
- Trello
- Monday.com
- Or any other project management tool

## Automatic Cleanup

These files are **not** tracked by Git (see `.gitignore`). They are local artifacts for your convenience.

You can safely delete old issue files once you've created the issues manually.

## Automatic Issue Creation

To automatically create GitHub issues instead of saving to this directory, use:

```bash
# Specify repo via flag
./dist/bin/create-github-issue.sh --scan-id SCAN_ID --repo owner/repo

# Or add to template
GITHUB_REPO='owner/repo'
```

See the main [README.md](../../README.md) for more details.

