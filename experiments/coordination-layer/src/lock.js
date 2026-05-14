'use strict';

const fs = require('fs');
const path = require('path');

// Claim-cycle atomicity (Run 2, P2).
//
// `tick claim` does project(read) -> cap-check -> appendEvent(write). That is a
// TOCTOU window: two concurrent `tick claim` processes for the SAME agent could
// both pass the cap check before either writes, busting the cap. (Cross-agent
// races don't exist — the cap is per-agent and each agent only writes its own
// events; concurrent same-task claims by different agents are handled by the
// projection tie-breaker, not the cap.)
//
// Fix: a per-clone O_EXCL lock serialises one agent's own claim calls. The
// lock lives under .git/ (never committed) so it leaves no trace in the tree.
//
// Known limitation: a hard process kill mid-claim leaves a stale lock. Recovery
// is `rm <repo>/.git/tick-claim.lock`. Stale-detection / `proper-lockfile` is a
// Phase 2 hardening if this proves to bite.

function lockPath(repoRoot) {
  const gitDir = path.join(repoRoot, '.git');
  if (fs.existsSync(gitDir) && fs.statSync(gitDir).isDirectory()) {
    return path.join(gitDir, 'tick-claim.lock');
  }
  // No .git dir (e.g. TICK_REPO_ROOT pointing at a plain dir) — fall back
  // inside .tick/ but outside the committed events dir.
  return path.join(repoRoot, '.tick', '.claim.lock');
}

// Run `fn` while holding the per-clone claim lock. `fs.openSync(.., 'wx')` is an
// atomic create-or-fail (O_EXCL): if the lock already exists it throws EEXIST.
function withClaimLock(repoRoot, fn) {
  const lp = lockPath(repoRoot);
  let fd;
  try {
    fd = fs.openSync(lp, 'wx');
  } catch (err) {
    if (err.code === 'EEXIST') {
      throw new Error(
        'another tick claim is in progress for this clone (lock held) — retry shortly, ' +
        `or remove ${path.relative(repoRoot, lp)} if a prior claim was killed`
      );
    }
    throw err;
  }
  try {
    fs.writeSync(fd, String(process.pid));
    return fn();
  } finally {
    fs.closeSync(fd);
    try { fs.unlinkSync(lp); } catch { /* best-effort */ }
  }
}

module.exports = { withClaimLock, lockPath };
