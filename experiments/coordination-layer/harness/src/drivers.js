'use strict';

// Driver abstraction: how to invoke each coding agent *headlessly* (no chat UI,
// no human in the loop) from a system CLI. This is the whole point of the
// harness — it replaces "Noel pastes a prompt into the VS Code chat panel and
// babysits" with a spawnable subprocess.
//
// Each driver returns a spawn spec: { cmd, args, input }. The prompt is fed on
// stdin (uniform across CLIs, avoids arg-length limits and quoting hell). The
// runner sets cwd + env (TICK_REPO_ROOT etc.) on the child.
//
// Real-CLI flags can be overridden with env vars (GEMINI_CMD/GEMINI_ARGS, etc.)
// so the binary/flags can be tuned without editing this file — CLIs move fast.

const { execSync } = require('child_process');
const path = require('path');

function which(bin) {
  try {
    execSync(`command -v ${bin}`, { stdio: ['ignore', 'pipe', 'ignore'] });
    return true;
  } catch {
    return false;
  }
}

function envArgs(name) {
  const v = process.env[name];
  return v ? v.split(' ').filter(Boolean) : null;
}

// --- gemini -----------------------------------------------------------------
// Headless: pipe the prompt on stdin. `--yolo` auto-approves tool calls so the
// agent can actually edit files unattended. Preflight needs no tools.
const gemini = {
  name: 'gemini',
  bin: process.env.GEMINI_CMD || 'gemini',
  available() { return which(this.bin); },
  spawnSpec({ mode, prompt }) {
    const args = envArgs('GEMINI_ARGS') || (mode === 'run' ? ['--yolo'] : []);
    return { cmd: this.bin, args, input: prompt };
  },
};

// --- codex ------------------------------------------------------------------
// `codex exec` is the non-interactive entrypoint. `--full-auto` lets it run
// commands/edits without prompting. In a throwaway trial workspace this is safe.
const codex = {
  name: 'codex',
  bin: process.env.CODEX_CMD || 'codex',
  available() { return which(this.bin); },
  spawnSpec({ mode, prompt }) {
    const base = envArgs('CODEX_ARGS') || (mode === 'run' ? ['exec', '--full-auto', '-'] : ['exec', '-']);
    return { cmd: this.bin, args: base, input: prompt };
  },
};

// --- claude (also useful as a real third driver / control) ------------------
const claude = {
  name: 'claude',
  bin: process.env.CLAUDE_CMD || 'claude',
  available() { return which(this.bin); },
  spawnSpec({ mode, prompt }) {
    const args = envArgs('CLAUDE_ARGS') ||
      (mode === 'run' ? ['-p', '--permission-mode', 'acceptEdits'] : ['-p']);
    return { cmd: this.bin, args, input: prompt };
  },
};

// --- mock -------------------------------------------------------------------
// A deterministic stand-in that exercises the FULL coordination protocol
// (tick take → work → tick done/break) without a real model or API key. Lets
// the entire battery run — and the harness be validated — in any environment.
// It reads the parsed spec JSON rather than the prose prompt.
const mock = {
  name: 'mock',
  available() { return true; },
  spawnSpec({ mode, agent, specPath, workdir, tickBin }) {
    return {
      cmd: process.execPath, // node
      args: [
        path.join(__dirname, 'mock-agent.js'),
        '--agent', agent,
        '--mode', mode,
        '--spec', specPath,
        '--workdir', workdir,
        '--tick', tickBin,
      ],
      input: null,
    };
  },
};

const DRIVERS = { gemini, codex, claude, mock };

function getDriver(name) {
  const d = DRIVERS[name];
  if (!d) throw new Error(`unknown driver: ${name} (known: ${Object.keys(DRIVERS).join(', ')})`);
  return d;
}

module.exports = { DRIVERS, getDriver, which };
