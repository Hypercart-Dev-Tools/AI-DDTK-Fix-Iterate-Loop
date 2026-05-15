'use strict';

const fs = require('fs');
const path = require('path');

// Claim-cycle atomicity (Run 2, P2).
//
// `tick claim` does project(read) -> cap-check -> appendEvent(write). That is a
// TOCTOU window: two concurrent `tick claim` processes for the SAME agent could
// both pass the cap check before either writes, busting the cap.
//
// Fix: a per-clone O_EXCL lock serialises one agent's own claim calls. The
// lock lives under .tick/locks/ (never committed; directory is in .gitignore)
// instead of .git/ so sandbox environments that restrict .git/ writes don't
// block normal tick operation.
//
// Known limitation: a hard process kill mid-claim leaves a stale lock. Recovery
// is `rm <repo>/.tick/locks/claim.lock`. Stale-detection is Phase 2.

function lockPath(repoRoot) {
  const locksDir = path.join(repoRoot, '.tick', 'locks');
  fs.mkdirSync(locksDir, { recursive: true });
  return path.join(locksDir, 'claim.lock');
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
