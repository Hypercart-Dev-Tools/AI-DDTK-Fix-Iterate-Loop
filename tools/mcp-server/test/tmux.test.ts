import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createTmuxHandlers } from "../src/handlers/tmux.js";
import { getTmuxCommandAllowlistDecision } from "../src/security/allowlist.js";
import { ExecFileTextError, type ExecResult } from "../src/utils/exec.js";

async function createFixture() {
  const root = await mkdtemp(path.join(os.tmpdir(), "amcp-tmux-"));
  const repoRoot = path.join(root, "repo");
  const workingDir = path.join(root, "workspace");

  await mkdir(path.join(repoRoot, "bin"), { recursive: true });
  await mkdir(workingDir, { recursive: true });
  await writeFile(path.join(repoRoot, "bin", "aiddtk-tmux"), "#!/usr/bin/env bash\n");

  return {
    repoRoot,
    workingDir,
    async cleanup() {
      await rm(root, { recursive: true, force: true });
    },
  };
}

test("tmux command allowlist accepts safe prefixes and blocks dangerous shell patterns", () => {
  const repoRoot = "/repo";

  assert.equal(getTmuxCommandAllowlistDecision("wpcc --features", repoRoot).allowed, true);
  assert.equal(getTmuxCommandAllowlistDecision("wpcc --paths tools/mcp-server --format json --verbose", repoRoot).allowed, true);
  assert.equal(getTmuxCommandAllowlistDecision("wpcc --paths /etc/shadow", repoRoot).allowed, false);
  assert.equal(getTmuxCommandAllowlistDecision("cat README.md", repoRoot).allowed, false);
  assert.equal(getTmuxCommandAllowlistDecision("rm -rf temp", repoRoot).allowed, false);
  assert.equal(getTmuxCommandAllowlistDecision("wpcc --features && rm -rf temp", repoRoot).allowed, false);
  assert.equal(getTmuxCommandAllowlistDecision("wpcc --paths tools/mcp-server ${HOME}", repoRoot).allowed, false);
});

test("tmux handlers normalize sessions, use 10s timeouts, and parse wrapper output", async () => {
  const fixture = await createFixture();
  const calls: Array<{ args: string[]; timeoutMs?: number; cwd?: string }> = [];

  try {
    const handlers = createTmuxHandlers({
      repoRoot: fixture.repoRoot,
      workingDir: fixture.workingDir,
      execRunner: async (_file, args, options): Promise<ExecResult> => {
        calls.push({ args, timeoutMs: options?.timeoutMs, cwd: options?.cwd });

        switch (args[0]) {
          case "start":
            return {
              stdout:
                "Started session: aiddtk-phase-4-workspace\n" +
                `Working directory: ${path.join(fixture.workingDir, "tools", "mcp-server")}\n` +
                "Log file: /tmp/aiddtk-phase-4-workspace.log\n",
              stderr: "",
              exitCode: 0,
            };
          case "status":
            return {
              stdout:
                "Session: aiddtk-phase-4-workspace\n" +
                "tmux: tmux 3.5a\n" +
                `Path: ${path.join(fixture.workingDir, "tools", "mcp-server")}\n` +
                "Windows: 2\n" +
                "Log file: /tmp/aiddtk-phase-4-workspace.log\n",
              stderr: "",
              exitCode: 0,
            };
          case "list":
            return { stdout: "aiddtk-phase-4-workspace\t2\tdetached\n", stderr: "", exitCode: 0 };
          case "send":
            return { stdout: "Sent command to aiddtk-phase-4-workspace\n", stderr: "", exitCode: 0 };
          case "capture":
            return { stdout: "line 1\nline 2\n", stderr: "", exitCode: 0 };
          case "stop":
            return { stdout: "Stopped session: aiddtk-phase-4-workspace\n", stderr: "", exitCode: 0 };
          default:
            throw new Error(`Unexpected tmux command: ${args[0]}`);
        }
      },
    });

    const start = await handlers.start("tools/mcp-server", "Phase 4 Workspace");
    const status = await handlers.status("Phase 4 Workspace");
    const list = await handlers.list();
    const send = await handlers.send("wpcc --features", "Phase 4 Workspace");
    const capture = await handlers.capture(50, "Phase 4 Workspace");
    const stop = await handlers.stop("Phase 4 Workspace");

    assert.deepEqual(calls[0]?.args, [
      "start",
      "--session",
      "aiddtk-phase-4-workspace",
      "--cwd",
      path.join(fixture.workingDir, "tools", "mcp-server"),
    ]);
    assert.equal(calls.every((call) => call.timeoutMs === 10_000), true);
    assert.equal(calls.every((call) => call.cwd === fixture.workingDir), true);

    assert.equal(start.session, "aiddtk-phase-4-workspace");
    assert.equal(start.reused, false);
    assert.equal(start.logFile, "/tmp/aiddtk-phase-4-workspace.log");

    assert.equal(status.exists, true);
    assert.equal(status.windows, 2);
    assert.equal(status.tmuxVersion, "tmux 3.5a");

    assert.equal(list.sessions.length, 1);
    assert.deepEqual(list.sessions[0], {
      session: "aiddtk-phase-4-workspace",
      windows: 2,
      attached: false,
      state: "detached",
    });

    assert.equal(send.session, "aiddtk-phase-4-workspace");
    assert.equal(send.command, "wpcc --features");
    assert.equal(calls[3]?.args.at(-1), "wpcc --features");

    assert.equal(capture.tail, 50);
    assert.equal(capture.output, "line 1\nline 2\n");
    assert.equal(stop.stopped, true);
  } finally {
    await fixture.cleanup();
  }
});

test("tmux_send rejects blocked commands before execution and tmux_status preserves missing-session output", async () => {
  const fixture = await createFixture();
  let sendInvoked = false;

  try {
    const handlers = createTmuxHandlers({
      repoRoot: fixture.repoRoot,
      workingDir: fixture.workingDir,
      execRunner: async (_file, args): Promise<ExecResult> => {
        if (args[0] === "send") {
          sendInvoked = true;
        }

        throw new ExecFileTextError(
          "Command failed",
          "Session not found: aiddtk-missing\nStart one with: aiddtk-tmux start --session missing --cwd /tmp/demo\n",
          "",
          1,
          false,
        );
      },
    });

    await assert.rejects(() => handlers.send("bash -lc 'whoami'", "missing"), /Blocked tmux command: bash/);
    assert.equal(sendInvoked, false);

    const status = await handlers.status("missing");
    assert.equal(status.session, "aiddtk-missing");
    assert.equal(status.exists, false);
    assert.equal(status.exitCode, 1);
    assert.match(status.stdout, /Session not found/);
  } finally {
    await fixture.cleanup();
  }
});