# Development Server & Port Conflict Registry — Template

> **AI Agent Instructions — Read This First**
>
> This file is the **canonical template** for a machine's local development environment registry. `servers-audit.sh` uses it as its template source (see `DEFAULT_TEMPLATE` in the script).
>
> The Port Allocation Registry table below is generated from `tools/servers.registry.json`. Treat the JSON file as the editable source of truth.
>
> **This file is generic.** For a machine-specific snapshot, copy it to `~/bin/servers.md` (or another location outside the repo) and fill in the real values. See the example at the end of this file.
>
> Before adding any new tool, server, or daemon, agents should:
>
> 1. **Read this template** — understand the recommended coexistence architecture
> 2. **Read the machine-specific file** (`~/bin/servers.md`) — check the live Port Allocation Registry for conflicts
> 3. **Assign an unused port** — pick from unallocated ports above 8000; never reuse an existing entry
> 4. **Add a registry entry** to the machine-specific file *before* installing
> 5. **Run the audit** after install: `~/bin/ai-ddtk/tools/servers-audit.sh --output /tmp/servers-now.md`
> 6. **Verify no new conflicts** — check `servers-monitor.sh` for alerts
>
> **Port 80 / 443 coexistence (recommended architecture):**
> - Local WP router nginx: `127.0.0.1:80` (serves `*.local`)
> - Valet nginx: `127.0.0.2:80` (serves `*.test`, proxies Docker services)
> - Docker services use dedicated high ports and are proxied through Valet
>
> **NEVER bind `0.0.0.0:80` or `0.0.0.0:443`** — this shadows both listeners and breaks coexistence.

---

## Port Allocation Registry (Template)

Example structure — replace with real assignments in the machine-specific copy. Fixed assignments. Never reuse a port.

<!-- GENERATED:PORT_REGISTRY:START -->
| Port | Service | Owner | Hostname | Notes |
|------|---------|-------|----------|-------|
| **80** | Local WP (`127.0.0.1`) + Valet (`127.0.0.2`) | Local WP + Valet | `*.local` / `*.test` | Coexist on separate IPs — never bind `0.0.0.0:80` |
| **443** | Local WP (`127.0.0.1`) + Valet (`127.0.0.2`) | Local WP + Valet | `*.local` / `*.test` | Same coexistence as port 80 |
| 3306 | MySQL | Homebrew | localhost | _(add database name)_ |
| 5432 | PostgreSQL | Homebrew | localhost | Do NOT expose Docker Postgres here — use a unique high port |
| 11434 | Ollama | Homebrew | localhost | Local LLM server |
| 8000–9999 | _(reserved range for user services)_ | — | — | Pick from here for new services |
<!-- GENERATED:PORT_REGISTRY:END -->

**Rules for adding a new service:**
1. Pick an unallocated port **above 8000**
2. Docker services: bind to `127.0.0.1:<port>` — never `0.0.0.0:<port>` unless cross-compose access is required
3. Never bind `0.0.0.0:80` or `0.0.0.0:443`
4. Add a Valet proxy for a clean hostname: `valet proxy <name> http://127.0.0.1:<port>`
5. Add a row to the machine-specific registry table before installing
6. Run `servers-monitor.sh` after install to verify no new conflicts

---

## How to Use This Template

1. **Copy to a machine-specific location outside the repo:**
   ```bash
   cp ~/bin/ai-ddtk/tools/servers.md ~/bin/servers.md
   ```

2. **Run the audit script** to populate machine-specific sections:
   ```bash
   ~/bin/ai-ddtk/tools/servers-audit.sh --output ~/bin/servers.md
   ```

3. **Set up continuous monitoring:**
   - Configure `~/Documents/GH Repos/AI-DDTK/experimental/servers-monitor.sh`
   - Install the LaunchAgent at `~/Library/LaunchAgents/com.neochro.servers-monitor.plist`
   - Alerts email via Resend.com when the conflict baseline changes

4. **Keep it updated** — after resolving issues, re-run the audit to capture the new baseline.

**Why outside the repo?** The machine-specific snapshot contains hostnames, usernames, site IDs, and environment details that are not appropriate to commit to version control.

---

## Machine Information (populated per-machine)

| Field | Value |
|-------|-------|
| **Machine Type** | _(e.g., MacBook Pro, Mac Studio)_ |
| **Machine Name** | _(hostname)_ |
| **Primary User** | _(username)_ |
| **OS Version** | _(e.g., macOS 15.6.1)_ |
| **Last Updated** | _(YYYY-MM-DD)_ |
| **Architecture** | _(e.g., "Coexistence — Local WP + Valet + Docker")_ |
| **Monitoring** | _(LaunchAgent label + interval)_ |

---

## Listening Services (populated by script)

| Process | IP:Port | Manager | Notes |
|---------|---------|---------|-------|
| _(populated by `lsof -i -P -n | grep LISTEN`)_ | | | |

---

## DNS Configuration (populated per-machine)

### `/etc/hosts` entries
- `*.local` entries managed by Local WP
- `*.test` entries should be zero (dnsmasq handles all `.test` resolution)
- Manual entries should be rare — flag them for review

### Resolver config (macOS)
```
/etc/resolver/test:
  nameserver 127.0.0.2

Valet dnsmasq (~/.config/valet/dnsmasq.d/tld-test.conf):
  address=/.test/127.0.0.2
  listen-address=127.0.0.2
```

**Verify:** `dig @127.0.0.2 <site>.test +short` should return `127.0.0.2`.

### mDNS
macOS `mDNSResponder` can intercept `.local` queries. Flush with:
```bash
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
```

---

## Service Managers (populated per-machine)

### Homebrew Services
```
(brew services list)
```

### Valet Proxies
```
(valet proxies)
```

### Local WP Sites
```
(from ~/Library/Application Support/Local/sites.json)
```

### Docker Containers
```
(docker ps)
```

---

## Detected Conflicts

_(Populated by the audit script or added manually. If `servers-monitor.sh` is running, this section should usually be empty — it surfaces conflicts proactively via email.)_

### Conflict #1: _(auto-detected or manually added)_

**Severity:** Critical / High / Medium / Low / FYI

**What's happening:** _(description)_

**Why it exists:** _(root cause)_

**Fix:**
```bash
_(commands)_
```

**Verification:**
```bash
_(how to confirm the fix worked)_
```

---

## Troubleshooting

Quick symptom → fix table. For step-by-step diagnostics, see the **Decision Tree** below.

| Symptom | Likely Cause | Quick Fix |
|---------|--------------|-----------|
| `ERR_CONNECTION_REFUSED` on `*.test` | Valet nginx not running, or dnsmasq cache stale | `valet restart` then `valet restart dnsmasq` |
| `*.test` resolves to wrong IP | dnsmasq cache or manual `/etc/hosts` override | `valet restart dnsmasq`; check `grep <site> /etc/hosts` |
| `502 Bad Gateway` on Docker-proxied site | Backend nginx booted before API was ready | `docker exec <container-nginx> nginx -s reload` |
| `503` or connection refused on Docker-proxied site | Container down or port mapping changed | `docker ps`, verify container Up and mapping correct |
| Local WP site won't start | Something bound `0.0.0.0:80` (Docker or Homebrew nginx) | Check monitor alerts; stop offending service |
| `*.local` resolves to wrong IP | macOS mDNS intercepting | `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder` |
| Monitor alert "port conflict" for nginx port 80 | nginx master/worker false positive | Ensure monitor dedupes by **command name**, not PID (nginx has many workers on one socket) |
| Monitor alert "stale /etc/hosts" for `www.<site>` | Local WP writes `www.` aliases but only stores bare domain in `sites.json` | Strip `www.` prefix before comparing (`${host#www.}`) |
| After `valet install` / `composer global update`, port 80 conflict returns | Valet regenerated nginx configs from un-patched stubs | Re-patch stubs in `~/.composer/vendor/laravel/valet/cli/stubs/` |
| Postgres connection hits wrong DB | Something bound `0.0.0.0:5432` shadowing Homebrew's `127.0.0.1:5432` | Check `lsof -i :5432`; if Docker, change `EXPOSE_POSTGRES_PORT` to a unique high port |
| `*.test` site loads old content | Browser or macOS DNS cached old IP | `dscacheutil -flushcache`; hard-reload browser |

---

## Decision Tree for LLM Agents

Depth-first diagnostic flow. Follow the branches in order. Each command reveals which branch to take next.

### 1. Can't reach `http://<something>.test` in browser

**Step 1.1 — DNS resolution:**
```bash
dig @127.0.0.2 <site>.test +short
```
- **Empty or timeout** → dnsmasq is down or not listening on `127.0.0.2`. Run `valet restart dnsmasq`. Also check `ps aux | grep dnsmasq`.
- **Returns old/wrong IP (e.g., `127.0.0.1`)** → dnsmasq is serving a cached `/etc/hosts` entry. Remove any manual entry: `grep <site>.test /etc/hosts` then `sudo sed -i.bak '/<site>\.test/d' /etc/hosts`. Then `valet restart dnsmasq`.
- **Returns `127.0.0.2`** → DNS is correct. Go to Step 1.2.

**Step 1.2 — Valet nginx listening on 127.0.0.2:80?**
```bash
lsof -i :80 -P -n | grep LISTEN | grep 127.0.0.2
```
- **Empty** → Valet nginx is down. Run `valet restart`. If it still doesn't bind, inspect `/opt/homebrew/etc/nginx/valet/valet.conf` for a `listen 127.0.0.2:80` directive.
- **Returns nginx workers** → Valet is up. Go to Step 1.3.

**Step 1.3 — Proxy registered (for Docker-backed sites)?**
```bash
valet proxies
```
- **Site not listed** → Register it: `valet proxy <name> http://127.0.0.1:<backend-port>`
- **Listed** → Go to Step 1.4.

**Step 1.4 — Backend reachable?**
```bash
curl -sSI http://127.0.0.1:<backend-port>/
```
- **Connection refused** → Backend not running. For Docker: `docker ps | grep <container>`; start the container if missing.
- **502/503** → Backend booted before a dependency was ready. For Docker: `docker exec <container-nginx> nginx -s reload`.
- **200/307/301** → Backend is fine. The problem is between Valet and the backend. Check `~/.config/valet/Nginx/<site>.test` for correct `proxy_pass` line.

### 2. Can't reach `http://<site>.local` (Local WP)

**Step 2.1 — Is the site started in Local WP?**
Open the Local WP GUI and verify the green dot. If stopped, start it.

**Step 2.2 — Is `127.0.0.1:80` bound?**
```bash
lsof -i :80 -P -n | grep 127.0.0.1
```
- **Empty** → Local WP router didn't start. **Restart the entire Local WP app** (`Cmd+Q`, reopen). The router only binds on app launch — starting/stopping individual sites doesn't affect it.
- **Shows a process other than Local WP** (e.g., Homebrew nginx, Docker) → that process is squatting `127.0.0.1:80`. Stop it:
  - Homebrew: `sudo brew services stop nginx`
  - Docker: find the container via `docker ps --format '{{.Names}} {{.Ports}}' | grep ':80->'` and fix the compose mapping

**Step 2.3 — Is something binding `0.0.0.0:80`?**
```bash
lsof -i :80 -P -n | grep LISTEN | grep "\*:"
```
- **Non-empty** → This wildcard bind shadows both `127.0.0.1` and `127.0.0.2`. Go to section 3.

**Step 2.4 — mDNS interference?**
```bash
dscacheutil -q host -a name <site>.local
```
- **Wrong IP** → `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder`

### 3. Something is binding `0.0.0.0:80` or `0.0.0.0:443`

**This always breaks coexistence.** Every local service should bind a specific loopback IP, never the wildcard.

**Step 3.1 — Identify:**
```bash
lsof -i :80 -P -n | grep LISTEN | grep "\*:"
```

**Step 3.2 — By process type:**
- **`com.docker.backend`** → A Docker container is mapping `80` to the host. Find it:
  ```bash
  docker ps --format '{{.Names}} {{.Ports}}' | grep ':80->'
  ```
  **Fix:** edit the container's compose file (or `.env`) to use a dedicated high port (e.g., `8741:80`). Restart the container. Then add a Valet proxy for a clean hostname: `valet proxy <name> http://127.0.0.1:<new-port>`.
- **`nginx` (Homebrew-managed)** → Homebrew nginx conflicts with Valet. Stop it: `sudo brew services stop nginx`. Valet manages its own nginx — you don't want both.
- **Other process** → Stop it, then audit why it needed port 80. Most services can bind a high port instead.

### 4. Monitor alert: "port conflict" that looks wrong

The `servers-monitor.sh` check must dedupe carefully to avoid three common false-positive patterns.

**Step 4.1 — Is it actually a conflict?**
```bash
lsof -i :<port> -P -n | grep LISTEN | awk '{print $1}' | sort -u
```
- **1 unique command** → false positive. One process (with workers or IPv4+IPv6 dual-stack) was counted as multiple listeners. The monitor should dedupe by command name, not PID.
- **2+ unique commands** → real conflict. Stop or reconfigure one of them.

**Step 4.2 — Known false-positive patterns:**
- **nginx worker model:** 10+ worker PIDs share one listening socket — all same command, same user. Valid. Not a conflict.
- **IPv4 + IPv6 dual-stack:** e.g., Postgres binds both `127.0.0.1:5432` and `[::1]:5432` as one process. Two `lsof` rows, one process. Not a conflict.
- **macOS system services:** ControlCenter (AirPlay) on 5000 + 7000, rapportd on 64343. Classify as FYI, not conflict.

### 5. Database connection going to the wrong DB

**Step 5.1 — Who owns the port?**
```bash
lsof -i :<port> -P -n | grep LISTEN
```

**Step 5.2 — Look at bind addresses:**
- `127.0.0.1:<port>` → local process (Homebrew, typically fine)
- `0.0.0.0:<port>` (shown as `*:<port>`) → **Docker is shadowing**. Clients connecting to `localhost:<port>` may land on either DB non-deterministically depending on the client library.

**Step 5.3 — Fix Docker shadowing:**
1. Edit the Docker `.env` for that stack (e.g., Dify: `~/Documents/GH Repos/dify/docker/.env`)
2. Change `EXPOSE_<DB>_PORT=<old>` to a unique high port (e.g., `5433` for Postgres, `3307` for MySQL)
3. Restart the stack: `docker compose down && docker compose up -d`
4. Verify: `lsof -i :<old-port>` now shows only the Homebrew process

### 6. Valet nginx reverts to binding `127.0.0.1:80` after restart

**Symptom:** After `valet install`, `valet restart`, or `composer global update laravel/valet`, the monitor re-alerts about Valet binding `127.0.0.1:80`.

**Cause:** Valet regenerates its nginx configs from stubs at `~/.composer/vendor/laravel/valet/cli/stubs/*.conf`. If you only patch the deployed config (`/opt/homebrew/etc/nginx/valet/valet.conf`), `valet restart` will regenerate it from the un-patched stub.

**Fix:** Patch BOTH the stubs AND the deployed configs:

1. **Stubs** (7 files use `listen 127.0.0.1:80`):
   ```bash
   cd ~/.composer/vendor/laravel/valet/cli/stubs/
   for stub in proxy.valet.conf secure.proxy.valet-legacy.conf secure.proxy.valet.conf \
               secure.valet-legacy.conf secure.valet.conf site.valet.conf; do
     sed -i.bak 's|    listen 127.0.0.1:80;|    # listen 127.0.0.1:80; # DISABLED — reserved for Local WP|' "$stub"
     rm -f "${stub}.bak"
   done
   # valet.conf is special (it has default_server)
   sed -i.bak 's|    listen 127.0.0.1:80 default_server;|    # listen 127.0.0.1:80 default_server; # DISABLED|' valet.conf
   rm -f valet.conf.bak
   ```

2. **Deployed config:** `/opt/homebrew/etc/nginx/valet/valet.conf` — same substitution.

3. **Per-site configs:** `~/.config/valet/Nginx/*.test` — same substitution on each file.

After a `composer global update`, the stubs reset — re-run step 1.

### 7. "Stale /etc/hosts entry" alerts for `www.<site>`

**Cause:** Local WP writes both `<site>.local` and `www.<site>.local` to `/etc/hosts`, but its `sites.json` only stores the bare domain. A naive comparison flags all the `www.` entries as stale.

**Fix:** The check in `servers-monitor.sh` must strip `www.` from each hosts entry before comparing to `sites.json`:
```bash
local bare_host="${host#www.}"
if ! echo "$wp_domains" | grep -qxF "$bare_host"; then
    # truly stale
fi
```

If the monitor still reports `www.<valid-site>`, the check has regressed — verify the shell expansion is present.

### 8. DNS cache returning stale IP after `/etc/hosts` change

**Symptom:** You removed a `/etc/hosts` entry but `dscacheutil -q host` still returns the old IP.

**Fix:**
1. Flush the system cache: `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder`
2. Restart dnsmasq (it also caches `/etc/hosts` on startup): `valet restart dnsmasq`
3. Verify: `dig @127.0.0.2 <name> +short`

---

## AI Agent Instructions

When asked to perform a server/port audit:

1. Read the machine-specific file (`~/bin/servers.md` if present) before this template.
2. Run `tools/servers-audit.sh` with appropriate flags, or execute the equivalent commands manually.
3. Review output for conflicts — especially ports 80, 443, 3306, 5432, 8080, and Local WP dynamic ports.
4. Cross-reference `/etc/hosts` entries against currently running Local WP sites (strip `www.` first).
5. Check Homebrew services (mysql, nginx, httpd, dnsmasq) for overlap with Local WP or Valet.
6. For each detected conflict, propose concrete commands to fix (not generic guidance), with a risk note if disruptive.
7. Request explicit permission before privileged or destructive actions (`sudo`, editing `/etc/hosts`, stopping services).
8. After each fix, re-run the audit to verify (fix-iterate loop).
9. Diff new snapshot against previous and report only the delta.
10. If the user reports a specific error, focus on that symptom first before broad cleanup.
11. Stop after 5 failed iterations (or 10 total loops) and clearly report the blocker.

---

## Resources

- **macOS DNS & mDNS:** https://developer.apple.com/library/archive/qa/qa1357/_index.html
- **RFC 6762 (mDNS):** https://tools.ietf.org/html/rfc6762
- **Local WP:** https://localwp.com/help-docs/
- **Laravel Valet:** https://laravel.com/docs/valet
- **Port audit command:** `lsof -i -P -n | grep LISTEN`
- **Architecture plan template:** `~/bin/servers-conflict-free.md`
