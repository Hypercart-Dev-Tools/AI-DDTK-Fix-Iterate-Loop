# Install Script Agent Notes

These notes were moved out of install.sh to keep executable logic easy to scan.

## Repository Structure

- AI-DDTK/
- install.sh: install and maintenance script
- bin/: executable wrappers added to PATH (`wpcc`, `wp-ajax-test`, `pw-auth`, `local-wp`, `aiddtk-tmux`)
- tools/: embedded packages and dependencies (`mcp-server`, `qm-bridge`, `wp-code-check`)
- temp/: sensitive data, logs, analysis files
- recipes/: workflow recipes
- AGENTS.md: AI agent guidelines

## WPCC Git Subtree Operations

WPCC subtree path: tools/wp-code-check/
Remote: https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git

Initial setup:
```bash
git subtree add --prefix=tools/wp-code-check \
  https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git main --squash
```

Pull latest:
```bash
git subtree pull --prefix=tools/wp-code-check \
  https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git main --squash
```

Pull specific version/tag:
```bash
git subtree pull --prefix=tools/wp-code-check \
  https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git v1.2.0 --squash
```

Push local subtree changes back:
```bash
git subtree push --prefix=tools/wp-code-check \
  https://github.com/Hypercart-Dev-Tools/WP-Code-Check.git feature-branch
```

## GitHub CLI Helpers

Check latest WPCC commit:
```bash
gh api repos/Hypercart-Dev-Tools/WP-Code-Check/commits/main --jq '.sha'
```

View recent commits:
```bash
gh api repos/Hypercart-Dev-Tools/WP-Code-Check/commits --jq '.[0:5] | .[] | "\(.sha[0:7]) \(.commit.message | split("\n")[0])"'
```

List releases:
```bash
gh release list --repo Hypercart-Dev-Tools/WP-Code-Check
```

List issues:
```bash
gh issue list --repo Hypercart-Dev-Tools/WP-Code-Check
```

Create PR:
```bash
gh pr create --repo Hypercart-Dev-Tools/WP-Code-Check --title "..." --body "..."
```

Compare local vs remote SHA:
```bash
LOCAL_SHA=$(git log -1 --format="%H" -- tools/wp-code-check)
REMOTE_SHA=$(gh api repos/Hypercart-Dev-Tools/WP-Code-Check/commits/main --jq '.sha')
[ "$LOCAL_SHA" = "$REMOTE_SHA" ] && echo "Up to date" || echo "Updates available"
```

## Maintenance Notes

- Script is idempotent and safe to run repeatedly.
- Script modifies shell config (~/.zshrc or ~/.bashrc) and does not require sudo.
- PATH entry format: export PATH="$HOME/bin/ai-ddtk/bin:$PATH"
- MCP clients should prefer tools/mcp-server/start.sh so fresh clones auto-build dist/.
- If WPCC is merged into AI-DDTK later, update bin/wpcc wrapper.
- Tools are intended to be callable from any directory.

## Future Tools

- Remove the repo-root local-wp compatibility shim after deprecation.
- Add playwright wrapper if needed.
- Add pixelmatch wrapper if needed.
