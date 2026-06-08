'use strict';

// Observability primitives for a trial run. Everything a trial does is recorded
// in three places so a run is fully reconstructable after the fact:
//
//   run.jsonl            — one structured JSON line per harness event (the spine)
//   logs/<agent>.log     — raw stdout+stderr transcript of each agent process
//   report/              — analyze.json / analyze.md / SUMMARY.md (written at end)
//
// No logging library — append-only JSONL + plain files, matching the rest of
// AI-DDTK's conventions.

const fs = require('fs');
const path = require('path');

class Recorder {
  constructor(runDir) {
    this.runDir = runDir;
    this.jsonlPath = path.join(runDir, 'run.jsonl');
    fs.mkdirSync(runDir, { recursive: true });
    fs.mkdirSync(path.join(runDir, 'logs'), { recursive: true });
    fs.mkdirSync(path.join(runDir, 'report'), { recursive: true });
  }

  // Append one structured event to the run spine and echo a terse line to the
  // console so a human watching the terminal sees progress live.
  event(type, data = {}) {
    const rec = { ts: new Date().toISOString(), type, ...data };
    fs.appendFileSync(this.jsonlPath, JSON.stringify(rec) + '\n');
    const detail = Object.entries(data)
      .filter(([k]) => k !== 'verbose')
      .map(([k, v]) => `${k}=${typeof v === 'string' ? v : JSON.stringify(v)}`)
      .join(' ');
    process.stdout.write(`  [${rec.ts}] ${type}${detail ? ' ' + detail : ''}\n`);
    return rec;
  }

  logStreamFor(agent) {
    return fs.createWriteStream(path.join(this.runDir, 'logs', `${agent}.log`), { flags: 'a' });
  }

  writeReportFile(name, contents) {
    const p = path.join(this.runDir, 'report', name);
    fs.writeFileSync(p, contents);
    return p;
  }

  read() {
    if (!fs.existsSync(this.jsonlPath)) return [];
    return fs.readFileSync(this.jsonlPath, 'utf8')
      .split('\n')
      .filter(Boolean)
      .map(l => JSON.parse(l));
  }
}

module.exports = { Recorder };
