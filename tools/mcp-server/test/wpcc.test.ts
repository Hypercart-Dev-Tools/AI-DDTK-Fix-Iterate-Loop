import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { WPCC_LATEST_REPORT_URI, WPCC_LATEST_SCAN_URI, createWpccHandlers } from "../src/handlers/wpcc.js";
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

test("wpcc resources resolve latest artifacts and list recent scans", async () => {
  const fixture = await createWpccFixture();
  const olderScanId = "2026-03-08-070600-UTC";
  const latestScanId = "2026-03-08-070700-UTC";
  const olderReportId = "2026-03-08-070600-UTC";
  const latestReportId = "2026-03-08-070800-UTC";

  try {
    await writeFile(path.join(fixture.logsDir, `${olderScanId}.json`), JSON.stringify({ summary: { total_errors: 1 } }, null, 2));
    await writeFile(path.join(fixture.logsDir, `${latestScanId}.json`), JSON.stringify({ summary: { total_errors: 0 } }, null, 2));
    await writeFile(path.join(fixture.reportsDir, `${olderReportId}.html`), "<html>older report</html>");
    await writeFile(path.join(fixture.reportsDir, `${latestReportId}.html`), "<html>latest report</html>");

    const handlers = createWpccHandlers({ repoRoot: fixture.root });
    const resources = await handlers.listScanResources();
    const latestScan = await handlers.readLatestScanResource();
    const latestReport = await handlers.readLatestReportResource();

    assert.equal(resources.length, 2);
    assert.equal(resources[0]?.uri, `wpcc://scan/${latestScanId}`);
    assert.equal(resources[1]?.uri, `wpcc://scan/${olderScanId}`);
    assert.equal(latestScan.contents[0]?.uri, WPCC_LATEST_SCAN_URI);
    assert.deepEqual(JSON.parse(latestScan.contents[0]?.text ?? "{}"), { summary: { total_errors: 0 } });
    assert.equal(latestReport.contents[0]?.uri, WPCC_LATEST_REPORT_URI);
    assert.equal(latestReport.contents[0]?.mimeType, "text/html");
    assert.match(latestReport.contents[0]?.text ?? "", /latest report/);
  } finally {
    await fixture.cleanup();
  }
});

test("wpcc scan resources are limited to the 10 most recent logs", async () => {
  const fixture = await createWpccFixture();

  try {
    for (let index = 0; index < 12; index += 1) {
      const scanId = `2026-03-08-07${String(index).padStart(2, "0")}00-UTC`;
      await writeFile(path.join(fixture.logsDir, `${scanId}.json`), JSON.stringify({ index }, null, 2));
    }

    const handlers = createWpccHandlers({ repoRoot: fixture.root });
    const resources = await handlers.listScanResources();

    assert.equal(resources.length, 10);
    assert.equal(resources[0]?.uri, "wpcc://scan/2026-03-08-071100-UTC");
    assert.equal(resources.at(-1)?.uri, "wpcc://scan/2026-03-08-070200-UTC");
  } finally {
    await fixture.cleanup();
  }
});

test("wpcc scan resource reads specific scans and rejects unknown ids", async () => {
  const fixture = await createWpccFixture();
  const scanId = "2026-03-08-071500-UTC";

  try {
    await writeFile(path.join(fixture.logsDir, `${scanId}.json`), JSON.stringify({ findings: [{ id: "spo-001" }] }, null, 2));

    const handlers = createWpccHandlers({ repoRoot: fixture.root });
    const resource = await handlers.readScanResource(scanId);

    assert.equal(resource.contents[0]?.uri, `wpcc://scan/${scanId}`);
    assert.deepEqual(JSON.parse(resource.contents[0]?.text ?? "{}"), { findings: [{ id: "spo-001" }] });

    await assert.rejects(() => handlers.readScanResource("../secret"), /WPCC scan not found: \.\.\/secret/);
  } finally {
    await fixture.cleanup();
  }
});

test("wpcc latest scan resource throws a friendly error when no scans exist", async () => {
  const fixture = await createWpccFixture();

  try {
    const handlers = createWpccHandlers({ repoRoot: fixture.root });

    await assert.rejects(
      () => handlers.readLatestScanResource(),
      /No WPCC JSON scans found\. Run `wpcc_run_scan` or `bin\/wpcc --paths <path> --format json` first\./,
    );
  } finally {
    await fixture.cleanup();
  }
});