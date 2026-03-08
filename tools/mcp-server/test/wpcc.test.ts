import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createWpccHandlers } from "../src/handlers/wpcc.js";
import { ExecFileTextError, type ExecResult } from "../src/utils/exec.js";

async function createWpccFixture() {
  const root = await mkdtemp(path.join(os.tmpdir(), "amcp wpcc-"));
  const logsDir = path.join(root, "tools", "wp-code-check", "dist", "logs");
  const reportsDir = path.join(root, "tools", "wp-code-check", "dist", "reports");

  await mkdir(path.join(root, "bin"), { recursive: true });
  await mkdir(logsDir, { recursive: true });
  await mkdir(reportsDir, { recursive: true });

  return {
    root,
    logsDir,
    reportsDir,
    async cleanup() {
      await rm(root, { recursive: true, force: true });
    },
  };
}

test("wpcc_list_features returns parsed sections from wrapper output", async () => {
  const fixture = await createWpccFixture();

  try {
    const handlers = createWpccHandlers({
      repoRoot: fixture.root,
      execRunner: async (_file, args): Promise<ExecResult> => {
        assert.deepEqual(args, ["--features"]);
        return {
          stdout:
            "\u001b[0;32mBASIC SCANNING\u001b[0m\n  wpcc --paths <path>\n\n\u001b[0;32mDOCUMENTATION\u001b[0m\n  Guide: /tmp/guide\n",
          stderr: "",
          exitCode: 0,
        };
      },
    });

    const result = await handlers.listFeatures();

    assert.equal(result.exitCode, 0);
    assert.equal(result.sections.length, 2);
    assert.equal(result.sections[0]?.title, "BASIC SCANNING");
    assert.deepEqual(result.sections[0]?.lines, ["wpcc --paths <path>"]);
    assert.equal(result.sections[1]?.title, "DOCUMENTATION");
    assert.match(result.rawText, /BASIC SCANNING/);
  } finally {
    await fixture.cleanup();
  }
});

test("wpcc_run_scan in json mode reads and parses the logged scan file", async () => {
  const fixture = await createWpccFixture();
  const logPath = path.join(fixture.logsDir, "2026-03-08-070000-UTC.json");
  const reportPath = path.join(fixture.reportsDir, "2026-03-08-070000-UTC.html");
  const scanData = { summary: { total_errors: 0 }, findings: [] };

  try {
    await writeFile(logPath, JSON.stringify(scanData, null, 2));
    await writeFile(reportPath, "<html></html>");

    const handlers = createWpccHandlers({
      repoRoot: fixture.root,
      execRunner: async (_file, args): Promise<ExecResult> => {
        assert.deepEqual(args, ["--paths", "templates", "--format", "json", "--verbose"]);
        return {
          stdout: `Log file: ${logPath}\nOutput: ${reportPath}\n`,
          stderr: "",
          exitCode: 0,
        };
      },
    });

    const result = await handlers.runScan("templates", "json", true);

    assert.equal(result.exitCode, 0);
    assert.equal(result.logPath, logPath);
    assert.equal(result.reportPath, reportPath);
    assert.deepEqual(result.scan, scanData);
  } finally {
    await fixture.cleanup();
  }
});

test("wpcc_run_scan in text mode returns raw command output without log parsing", async () => {
  const fixture = await createWpccFixture();

  try {
    const handlers = createWpccHandlers({
      repoRoot: fixture.root,
      execRunner: async (_file, args): Promise<ExecResult> => {
        assert.deepEqual(args, ["--paths", "templates"]);
        return { stdout: "plain text output", stderr: "", exitCode: 0 };
      },
    });

    const result = await handlers.runScan("templates", "text", false);

    assert.equal(result.format, "text");
    assert.equal(result.stdout, "plain text output");
    assert.equal(result.scan, null);
    assert.equal(result.logPath, null);
  } finally {
    await fixture.cleanup();
  }
});

test("wpcc_run_scan preserves exit code and output on command failure", async () => {
  const fixture = await createWpccFixture();

  try {
    const handlers = createWpccHandlers({
      repoRoot: fixture.root,
      execRunner: async (): Promise<ExecResult> => {
        throw new ExecFileTextError("Command failed", "scan stdout", "No PHP files found", 1, false);
      },
    });

    const result = await handlers.runScan("tools/mcp-server", "json", false);

    assert.equal(result.exitCode, 1);
    assert.equal(result.stdout, "scan stdout");
    assert.equal(result.stderr, "No PHP files found");
    assert.equal(result.scan, null);
  } finally {
    await fixture.cleanup();
  }
});

test("wpcc_run_scan falls back to newly created artifacts when stdout omits paths", async () => {
  const fixture = await createWpccFixture();
  const logFileName = "2026-03-08-070500-UTC.json";
  const reportFileName = "2026-03-08-070500-UTC.html";
  const logPath = path.join(fixture.logsDir, logFileName);
  const reportPath = path.join(fixture.reportsDir, reportFileName);
  const scanData = { summary: { total_errors: 1 }, findings: [{ id: "demo" }] };

  try {
    assert.match(fixture.root, /amcp wpcc-/);

    const handlers = createWpccHandlers({
      repoRoot: fixture.root,
      execRunner: async (_file, args): Promise<ExecResult> => {
        assert.deepEqual(args, ["--paths", "templates", "--format", "json"]);
        await writeFile(logPath, JSON.stringify(scanData, null, 2));
        await writeFile(reportPath, "<html></html>");
        return {
          stdout: "Scan complete without explicit artifact paths\n",
          stderr: "",
          exitCode: 0,
        };
      },
    });

    const result = await handlers.runScan("templates", "json", false);

    assert.equal(result.logPath, logPath);
    assert.equal(result.reportPath, reportPath);
    assert.deepEqual(result.scan, scanData);
  } finally {
    await fixture.cleanup();
  }
});