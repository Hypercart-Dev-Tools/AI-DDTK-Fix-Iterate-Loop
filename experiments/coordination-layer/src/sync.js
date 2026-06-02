'use strict';

const { execFileSync } = require('child_process');

function git(repoRoot, args, opts = {}) {
  return execFileSync('git', args, {
    cwd: repoRoot,
    stdio: opts.capture ? ['ignore', 'pipe', 'pipe'] : ['ignore', 'inherit', 'inherit'],
    encoding: 'utf8',
  });
}

function gitTry(repoRoot, args) {
  try {
    git(repoRoot, args, { capture: true });
    return { ok: true };
  } catch (err) {
    return { ok: false, err };
  }
}

function hasRemote(repoRoot) {
  try {
    const out = execFileSync('git', ['remote'], { cwd: repoRoot, encoding: 'utf8' });
    return out.trim().length > 0;
  } catch {
    return false;
  }
}

function currentBranch(repoRoot) {
  return execFileSync('git', ['rev-parse', '--abbrev-ref', 'HEAD'], {
    cwd: repoRoot,
    encoding: 'utf8',
  }).trim();
}

// The clone's configured git identity. `tick analyze` attributes work commits
// by author name, and the integration prompt requires `git config user.name`
// to equal the agent ID — so this is the cross-check source for --agent.
function gitUserName(repoRoot) {
  try {
    const out = execFileSync('git', ['config', 'user.name'], {
      cwd: repoRoot,
      encoding: 'utf8',
    }).trim();
    return out || null;
  } catch {
    return null;
  }
}

function fetch(repoRoot) {
  if (!hasRemote(repoRoot)) return;
  gitTry(repoRoot, ['fetch', 'origin']);
}

function rebase(repoRoot) {
  if (!hasRemote(repoRoot)) return;
  const branch = currentBranch(repoRoot);
  // Best-effort rebase against origin/<branch>; ignore if remote branch doesn't exist yet.
  const r = gitTry(repoRoot, ['rebase', `origin/${branch}`]);
  if (!r.ok) {
    // Abort partial rebase if any so we don't leave the working tree wedged.
    gitTry(repoRoot, ['rebase', '--abort']);
  }
}

// Commit a single file path relative to repoRoot, then push.
// Returns { pushed: bool, retried: bool }.
function commitAndPush(repoRoot, filePath, message) {
  git(repoRoot, ['add', '--', filePath]);
  git(repoRoot, ['commit', '-m', message]);
  if (!hasRemote(repoRoot)) return { pushed: false, retried: false };

  const branch = currentBranch(repoRoot);
  let r = gitTry(repoRoot, ['push', 'origin', branch]);
  if (r.ok) return { pushed: true, retried: false };

  // One retry: fetch, rebase, push.
  fetch(repoRoot);
  rebase(repoRoot);
  r = gitTry(repoRoot, ['push', 'origin', branch]);
  if (r.ok) return { pushed: true, retried: true };

  throw new Error('push failed after one retry; aborting (caller should pick a different task or retry manually)');
}

module.exports = { git, gitTry, hasRemote, currentBranch, gitUserName, fetch, rebase, commitAndPush };
