# Development Server & Port Conflict Audit

**Purpose:** Capture a baseline snapshot of your local development environment — running services, ports, hostnames, and DNS config — so you can diff against it when something breaks unexpectedly.

**Why a snapshot matters:** Services like Local WP, Homebrew daemons, and macOS mDNS can change state without user action — auto-updates, OS patches, background service restarts, or router config reloads. A baseline lets you quickly identify what changed when you get a hostname conflict error or port collision out of nowhere.

---

## How to Use This Document

1. **Copy this template outside the repo** — Place it somewhere like `~/bin/servers-audit.md` so it lives independently of any project repository.

2. **Run the audit script** — Use `experimental/servers-audit.sh` to populate this document automatically:
   ```bash
   experimental/servers-audit.sh --output ~/bin/servers-audit.md
   ```
   Useful options:
   ```bash
   # prioritize hostname checks when Local domains vanish unexpectedly
   experimental/servers-audit.sh --output ~/bin/servers-audit.md --focus hostname

   # include your previous baseline path for easier manual diff context
   experimental/servers-audit.sh --output /tmp/servers-now.md --previous-snapshot ~/bin/servers-audit.md
   ```
   The script also writes machine-readable artifacts under `temp/servers-audit/<run-id>/`.
   Or ask an AI agent to run the script and review the results.

3. **Review and annotate** — The script captures raw data. Add your own notes to the "Detected Conflicts" section for issues that need context only you have.

4. **Re-run when things break** — When Local WP throws a hostname conflict or a port collision appears, re-run the script and diff against your last snapshot:
   ```bash
   experimental/servers-audit.sh --output /tmp/servers-now.md
   diff ~/bin/servers-audit.md /tmp/servers-now.md
   ```

5. **Keep it updated** — After resolving issues, re-run to capture the new baseline.

**Why outside the repo?** This audit document is environment-specific and should not be committed to version control.

---

## Machine Information

| Field | Value |
|-------|-------|
| **Machine Type** | _(populated by script)_ |
| **Machine Name** | _(populated by script)_ |
| **Primary User** | _(populated by script)_ |
| **OS Version** | _(populated by script)_ |
| **Snapshot Date** | _(populated by script)_ |
| **Previous Snapshot** | _(path to last known-good snapshot, if any)_ |

---

## Changelog

### YYYY-MM-DD
- **Change description**: Brief summary of what was changed and why.

_(Add entries as you make changes. Keep this updated for future reference.)_

---

## Listening Services

| Process | PID | IP:Port | Manager | Notes |
|---------|-----|---------|---------|-------|
| _(populated by script)_ | | | | |

_(Populated by `lsof -i -P -n`. Includes web servers, databases, mail services, and other network-bound processes.)_

---

## DNS Configuration

### /etc/hosts Entries (*.local, *.test)

```
(populated by script)
```

### DNS Resolver Config

```
(populated by script — scutil --dns on macOS, resolv.conf on Linux)
```

### mDNS Status

```
(populated by script)
```

---

## Service Managers

### Homebrew Services
```
(populated by script)
```

### Local WP Sites
```
(populated by script)
```

### launchd / systemd Services (web/db related)
```
(populated by script)
```

---

## Registry Locations

Where each tool keeps its config — useful for understanding why things conflict silently.

| Tool | Registry Location | Scope | Notes |
|------|-------------------|-------|-------|
| Local WP | `~/Library/Application Support/Local/sites.json` | `.local` domains, dynamic ports | Manages its own nginx/mysql per site |
| Homebrew | `brew services list` | System-wide daemons | Can auto-start on boot |
| Valet | `~/.config/valet/` | `.test` domains | Uses dnsmasq |
| /etc/hosts | `/etc/hosts` | Manual hostname overrides | Not cleaned up automatically |
| macOS mDNS | System-level | `.local` domain (RFC 6762) | Intercepts before /etc/hosts |

_(Update or remove rows that don't apply to your setup.)_

---

## Detected Conflicts

_(Populated by the audit script when it finds overlapping ports, stale hosts entries, or other issues. Add your own analysis and fixes below each detected issue.)_

### Conflict #1: _(auto-detected or manually added)_

**Severity:** Critical / High / Medium / Low

**What's happening:**
_(Description of the conflict)_

**Why it exists:**
_(Root cause — misconfiguration, competing service managers, OS-level change, etc.)_

**Fix:**
```bash
_(Commands or steps to resolve)_
```

**Verification:**
```bash
_(How to confirm the fix worked)_
```

---

## Troubleshooting

Known-issue patterns with diagnostic steps and confirmed fixes. Each entry was validated in a real debugging session.

---

### T-1: Local WP hostname mode -- 404 Not Found

**Symptom:** After switching Local WP from IP/localhost mode to "Site Domain" (hostname) mode, visiting `http://yoursite.local` returns 404 in the browser. Stopping and restarting the site in the Local WP UI does not fix it.

**Root cause:** Local WP runs two layers of nginx in hostname mode. Stopping/starting a site only restarts Layer 2 (site-specific). Layer 1 (the router on port 80) is managed by the Local app process itself and only restarts when the app restarts.

| Layer | Process | Port | Role |
|-------|---------|------|------|
| Layer 1 | Router nginx | `127.0.0.1:80` | Maps `Host:` header to upstream site port |
| Layer 2 | Site nginx | `127.0.0.1:10xxx` | Serves a single site (one per running site) |

**Diagnose:**
```bash
# Is anything listening on port 80?
lsof -iTCP:80 -sTCP:LISTEN -n -P

# Is the site nginx up on its own port?
lsof -iTCP:10149 -sTCP:LISTEN -n -P   # replace 10149 with your site's port

# Does nginx respond with the correct Host header?
curl -s -o /dev/null -w "%{http_code}" -H "Host: yoursite.local" http://127.0.0.1:10149/
```

**Fix:** Restart the Local WP application (Cmd+Q, reopen). This restores the router nginx on port 80.

> Stopping/starting a site in the Local UI only restarts Layer 2. Only a full app restart restores Layer 1.

---

### T-2: WordPress URL mismatch after switching routing modes

**Symptom:** Site loads but immediately 301-redirects to `http://localhost:10149/` (or another stale URL). The redirect loops or resolves to a broken address.

**Root cause:** Switching Local WP routing modes (IP/localhost to hostname, or vice versa) does NOT update the WordPress `siteurl` and `home` database options. WordPress continues to redirect to whichever URL it was installed with.

**Diagnose:**
```bash
# Check what WordPress thinks its URL is
local-wp your-site option get siteurl
local-wp your-site option get home
# If these show localhost:PORT instead of yoursite.local, that's the cause.

# Confirm the redirect destination
curl -s -D - -o /dev/null -H "Host: yoursite.local" http://127.0.0.1:10149/ | grep Location
```

**Fix:** Run a WP-CLI search-replace to update the URL across the entire database:
```bash
# Safety: export a backup first
local-wp your-site db export ./temp/your-site-pre-url-fix.sql

# Preview changes first
local-wp your-site search-replace 'http://localhost:10149' 'http://yoursite.local' \
  --skip-columns=guid --report-changed-only --dry-run

# Apply after reviewing dry-run output
local-wp your-site search-replace 'http://localhost:10149' 'http://yoursite.local' \
  --skip-columns=guid --report-changed-only
```
Replace `your-site` and `10149` with your Local site name/port. The `--skip-columns=guid` flag prevents rewriting post GUIDs (which should remain unchanged).

After running, verify:
```bash
local-wp your-site option get siteurl   # should return http://yoursite.local
local-wp your-site option get home      # should return http://yoursite.local
```

> **Note:** This also updates serialized values in `wp_postmeta` and `wp_posts`. Expect 100-200 replacements on a typical site. The command handles PHP-serialized data automatically.

---

### T-3: Stale `/etc/hosts` entries causing Local WP hostname conflict warnings

**Symptom:** Local WP shows a "hostname conflict" warning on launch or when starting sites, even though the flagged sites no longer exist.

**Root cause:** When a Local WP site is deleted, its `/etc/hosts` entry is not always removed. Local WP scans `/etc/hosts` on startup and warns on any `.local` entries that do not correspond to a site in `sites.json`.

**Diagnose:**
```bash
# Find all .local entries in /etc/hosts
grep '.local' /etc/hosts

# Compare against Local WP's known sites
cat ~/Library/Application\ Support/Local/sites.json | python3 -c \
  "import json,sys; sites=json.load(sys.stdin); [print(s['domain']) for s in sites.values()]"

# Any entry in /etc/hosts NOT in the sites.json list is orphaned
```

**Fix:** Remove each orphaned entry (requires sudo):
```bash
# Safety: back up hosts first
sudo cp /etc/hosts /etc/hosts.bak-$(date +%Y%m%d-%H%M%S)

# Remove orphaned domain entries
sudo sed -i '' '/orphaneddomain\.local/d' /etc/hosts
```
Run once per orphaned domain. Verify with `grep '.local' /etc/hosts` afterward.

---

### T-4: Valet and Local WP port 80 coexistence

**Symptom:** After starting Valet, Local WP sites stop responding on hostname mode. Or after starting Local WP, Valet sites go down.

**Root cause:** Both services want port 80. However, they use different loopback aliases and can coexist if both are configured correctly.

| Service | Loopback IP | Port |
|---------|------------|------|
| Local WP router nginx | `127.0.0.1` | `80` |
| Valet nginx | `127.0.0.2` | `80` |

**Diagnose:**
```bash
lsof -iTCP:80 -sTCP:LISTEN -n -P | awk '{print $1, $3, $9}'
# Should show two nginx entries on different IPs if both are running correctly
```

**Fix:** If only one is showing, restart whichever service dropped off:
```bash
valet restart          # restarts Valet nginx on 127.0.0.2
# For Local WP: restart the Local app (Cmd+Q, reopen)
```

If both are on `127.0.0.1:80`, there is a true conflict. Check Valet's loopback alias:
```bash
ifconfig lo0 | grep '127\.0\.0\.2'   # should be present if Valet configured it
```

---

## Priority Fixes

1. **[Fix #1]** — _(Brief description and impact)_
   ```bash
   _(Command)_
   ```

2. **[Fix #2]** — _(Brief description and impact)_

---

## AI Agent Instructions

When asked to perform a server/port audit using this template:

1. Run `experimental/servers-audit.sh` with appropriate flags, or execute the equivalent commands manually if the script is not available.
2. Review the output for conflicts — especially ports 80, 443, 3306, 8080, and any Local WP dynamic ports.
3. Cross-reference `/etc/hosts` entries against currently running Local WP sites — orphaned entries from deleted sites are a common source of hostname conflicts.
4. Check whether Homebrew services (mysql, nginx, httpd, dnsmasq) overlap with Local WP's managed services.
5. For each detected conflict, propose concrete command(s) to fix it (not just generic guidance), and include a risk note if the fix is disruptive.
6. Offer to execute fix commands for the user; request explicit permission before privileged or destructive actions (for example editing `/etc/hosts`, stopping services, or using `sudo`).
7. After each accepted fix, re-run the audit to verify whether the conflict is resolved (fix-iterate loop).
8. Diff the new snapshot against the previous snapshot and report only the delta tied to the fix.
9. If the user reports a specific error (e.g., "hostname conflict in Local WP"), focus investigation and fixes on that symptom first before full-environment cleanup.
10. Stop after 5 failed fix iterations (or 10 total loops) and clearly report the blocker.

---

## Resources

- **macOS DNS & mDNS:** https://developer.apple.com/library/archive/qa/qa1357/_index.html
- **RFC 6762 (mDNS):** https://tools.ietf.org/html/rfc6762
- **Local WP Documentation:** https://localwp.com/help-docs/
- **Laravel Valet:** https://laravel.com/docs/valet
- **Port audit command:** `lsof -i -P -n | grep LISTEN`
