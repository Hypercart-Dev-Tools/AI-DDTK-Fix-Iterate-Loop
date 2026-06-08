'use strict';

// Spawn one agent process from a driver spawn-spec, feed the prompt on stdin,
// and tee stdout+stderr both to a capture buffer and (optionally) to a log
// stream. Resolves with { code, signal, output, ms }. Never rejects — a
// non-zero exit is data, not an exception, for a trial.

const { spawn } = require('child_process');

function runProc({ cmd, args, input, cwd, env, logStream, timeoutMs }) {
  return new Promise((resolve) => {
    const started = Date.now();
    const child = spawn(cmd, args, { cwd, env, stdio: ['pipe', 'pipe', 'pipe'] });
    let output = '';
    let timedOut = false;

    const onData = (buf) => {
      const s = buf.toString();
      output += s;
      if (logStream) logStream.write(s);
    };
    child.stdout.on('data', onData);
    child.stderr.on('data', onData);

    let timer = null;
    if (timeoutMs) {
      timer = setTimeout(() => { timedOut = true; child.kill('SIGKILL'); }, timeoutMs);
    }

    child.on('error', (err) => {
      output += `\n[spawn error] ${err.message}\n`;
      if (logStream) logStream.write(`\n[spawn error] ${err.message}\n`);
      if (timer) clearTimeout(timer);
      resolve({ code: -1, signal: null, output, ms: Date.now() - started, spawnError: err.message });
    });

    child.on('close', (code, signal) => {
      if (timer) clearTimeout(timer);
      resolve({ code, signal, output, ms: Date.now() - started, timedOut });
    });

    if (input != null) {
      child.stdin.write(input);
    }
    child.stdin.end();
  });
}

module.exports = { runProc };
