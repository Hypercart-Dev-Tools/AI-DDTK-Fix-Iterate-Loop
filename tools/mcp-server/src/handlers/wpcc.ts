import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { ExecFileTextError, execFileText, type ExecFileText, type ExecResult } from "../utils/exec.js";

const DEFAULT_TIMEOUT_MS = 300_000;
const DEFAULT_MAX_BUFFER = 25 * 1024 * 1024;
const DEFAULT_SCAN_RESOURCE_LIMIT = 10;
const JSON_MIME_TYPE = "application/json";
const HTML_MIME_TYPE = "text/html";

export const WPCC_LATEST_SCAN_URI = "wpcc://latest-scan";
export const WPCC_LATEST_REPORT_URI = "wpcc://latest-report";
export const WPCC_SCAN_URI_TEMPLATE = "wpcc://scan/{id}";

export type WpccFeatureSection = Record<string, unknown> & {
  title: string;
  lines: string[];
};

export type WpccFeaturesResult = Record<string, unknown> & {
  rawText: string;
  sections: WpccFeatureSection[];
  stdout: string;
  stderr: string;
  exitCode: number;
};

export type WpccScanResult = Record<string, unknown> & {
  paths: string;
  format: "json" | "text";
  verbose: boolean;
  stdout: string;
  stderr: string;
  exitCode: number;
  logPath: string | null;
  reportPath: string | null;
  scan: Record<string, unknown> | null;
};

export type WpccResource = {
  uri: string;
  name: string;
  description: string;
  mimeType: typeof JSON_MIME_TYPE | typeof HTML_MIME_TYPE;
};

export type WpccReadResourceResult = {
  contents: Array<{
    uri: string;
    mimeType: string;
    text: string;
  }>;
};

export interface WpccHandlerDeps {
  repoRoot: string;
  timeoutMs?: number;
  execRunner?: ExecFileText;
}

/** Strip ANSI escape sequences (colors, cursor movement) from CLI output. */
function stripAnsi(text: string): string {
  return text.replace(/\u001B\[[0-9;]*[A-Za-z]/g, "");
}

function parseFeatureSections(text: string): WpccFeatureSection[] {
  const sections: WpccFeatureSection[] = [];
  let current: WpccFeatureSection | null = null;

  for (const rawLine of stripAnsi(text).split(/\r?\n/)) {
    const line = rawLine.replace(/\s+$/, "");
    const trimmed = line.trim();

    if (!trimmed || /^[╔╗╚╝║─]+$/.test(trimmed) || trimmed.includes("AI-DDTK WordPress Code Check - Features")) {
      continue;
    }

    if (!/^[ \t]/.test(line)) {
      current = { title: trimmed, lines: [] };
      sections.push(current);
      continue;
    }

    if (current) {
      current.lines.push(trimmed);
    }
  }

  return sections;
}

/**
 * Recover an artifact path printed by WPCC from stdout or stderr.
 *
 * When the CLI reports the generated JSON log or HTML report explicitly, that
 * path is preferred over directory diffing because it is resilient to preexisting
 * files in the dist output directories.
 */
function extractArtifactPath(output: string, artifactDirName: "logs" | "reports", extension: ".json" | ".html"): string | null {
  for (const line of stripAnsi(output).split(/\r?\n/)) {
    const match = line.match(new RegExp(`(/.*dist/${artifactDirName}/.*\\${extension})`));

    if (match?.[1]) {
      return match[1].trim();
    }
  }

  return null;
}

async function listArtifacts(directory: string, extension: ".json" | ".html"): Promise<string[]> {
  try {
    const entries = await readdir(directory, { withFileTypes: true });
    return entries
      .filter((entry) => entry.isFile() && entry.name.endsWith(extension))
      .map((entry) => entry.name)
      .sort()
      .reverse();
  } catch {
    return [];
  }
}

function resolveArtifactFallback(directory: string, before: string[], after: string[]): string | null {
  const added = after.filter((name) => !before.includes(name));
  const selected = added[0] ?? after[0];
  return selected ? path.join(directory, selected) : null;
}

function removeExtension(fileName: string, extension: ".json" | ".html"): string {
  return fileName.endsWith(extension) ? fileName.slice(0, -extension.length) : fileName;
}

function buildScanUri(scanId: string): string {
  return `wpcc://scan/${scanId}`;
}

function buildReadResourceResult(uri: string, mimeType: string, text: string): WpccReadResourceResult {
  return {
    contents: [{ uri, mimeType, text }],
  };
}

function normalizeScanPaths(pathsToScan: string): string {
  const entries = pathsToScan.split(",").map((entry) => entry.trim());

  if (entries.some((entry) => entry.length === 0)) {
    throw new Error("WPCC scan paths must not contain empty entries.");
  }

  const invalidEntry = entries.find((entry) => entry.startsWith("-"));

  if (invalidEntry) {
    throw new Error(`WPCC scan path entries must not start with '-': ${invalidEntry}`);
  }

  return entries.join(",");
}

export function createWpccHandlers(deps: WpccHandlerDeps) {
  const runExec = deps.execRunner ?? execFileText;
  const timeoutMs = deps.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const wpccBin = path.join(deps.repoRoot, "bin", "wpcc");
  const logsDir = path.join(deps.repoRoot, "tools", "wp-code-check", "dist", "logs");
  const reportsDir = path.join(deps.repoRoot, "tools", "wp-code-check", "dist", "reports");

  /**
   * Execute WPCC and preserve captured output even when the process exits non-zero.
   *
   * A failed scan is still useful to MCP callers because stdout/stderr can contain
   * partial findings, artifact paths, or remediation guidance.
   */
  async function executeWpcc(args: string[]): Promise<ExecResult> {
    try {
      return await runExec(wpccBin, args, { timeoutMs, maxBuffer: DEFAULT_MAX_BUFFER });
    } catch (error) {
      if (error instanceof ExecFileTextError) {
        return { stdout: error.stdout, stderr: error.stderr, exitCode: error.exitCode };
      }

      const message = error instanceof Error ? error.message : String(error);
      return { stdout: "", stderr: message, exitCode: 1 };
    }
  }

  async function resolveLatestArtifactPath(directory: string, extension: ".json" | ".html"): Promise<string | null> {
    const artifacts = await listArtifacts(directory, extension);
    const latestArtifact = artifacts[0];
    return latestArtifact ? path.join(directory, latestArtifact) : null;
  }

  async function resolveScanPathById(scanId: string): Promise<string | null> {
    const artifacts = await listArtifacts(logsDir, ".json");
    const scanFileName = `${scanId}.json`;
    return artifacts.includes(scanFileName) ? path.join(logsDir, scanFileName) : null;
  }

  async function readResourceText(filePath: string): Promise<string> {
    return readFile(filePath, "utf8");
  }

  return {
    async listFeatures(): Promise<WpccFeaturesResult> {
      const result = await executeWpcc(["--features"]);
      const rawText = stripAnsi(result.stdout).trim();

      return {
        rawText,
        sections: parseFeatureSections(result.stdout),
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      };
    },

    async runScan(pathsToScan: string, format: "json" | "text" = "json", verbose = false): Promise<WpccScanResult> {
      const normalizedPaths = normalizeScanPaths(pathsToScan);
      const args = ["--paths", normalizedPaths, ...(format === "json" ? ["--format", "json"] : []), ...(verbose ? ["--verbose"] : [])];
      const logsBefore = format === "json" ? await listArtifacts(logsDir, ".json") : [];
      const reportsBefore = format === "json" ? await listArtifacts(reportsDir, ".html") : [];
      const result = await executeWpcc(args);
      const combinedOutput = [result.stdout, result.stderr].filter(Boolean).join("\n");

      if (format === "text") {
        return {
          paths: normalizedPaths,
          format,
          verbose,
          stdout: result.stdout,
          stderr: result.stderr,
          exitCode: result.exitCode,
          logPath: null,
          reportPath: null,
          scan: null,
        };
      }

      const logsAfter = await listArtifacts(logsDir, ".json");
      const reportsAfter = await listArtifacts(reportsDir, ".html");
      const logPath = extractArtifactPath(combinedOutput, "logs", ".json") ?? resolveArtifactFallback(logsDir, logsBefore, logsAfter);
      const reportPath =
        extractArtifactPath(combinedOutput, "reports", ".html") ?? resolveArtifactFallback(reportsDir, reportsBefore, reportsAfter);

      let scan: Record<string, unknown> | null = null;

      if (logPath) {
        scan = JSON.parse(await readFile(logPath, "utf8")) as Record<string, unknown>;
      } else if (result.exitCode === 0) {
        throw new Error("WPCC scan completed but no JSON log file could be determined.");
      }

      return {
        paths: normalizedPaths,
        format,
        verbose,
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
        logPath,
        reportPath,
        scan,
      };
    },

    async listScanResources(limit = DEFAULT_SCAN_RESOURCE_LIMIT): Promise<WpccResource[]> {
      const artifacts = (await listArtifacts(logsDir, ".json")).slice(0, limit);

      return artifacts.map((fileName) => {
        const scanId = removeExtension(fileName, ".json");

        return {
          uri: buildScanUri(scanId),
          name: `Scan: ${scanId}`,
          description: `WordPress code scan from ${scanId}`,
          mimeType: JSON_MIME_TYPE,
        };
      });
    },

    async readLatestScanResource(): Promise<WpccReadResourceResult> {
      const latestScanPath = await resolveLatestArtifactPath(logsDir, ".json");

      if (!latestScanPath) {
        throw new Error("No WPCC JSON scans found. Run `wpcc_run_scan` or `bin/wpcc --paths <path> --format json` first.");
      }

      return buildReadResourceResult(WPCC_LATEST_SCAN_URI, JSON_MIME_TYPE, await readResourceText(latestScanPath));
    },

    async readLatestReportResource(): Promise<WpccReadResourceResult> {
      const latestReportPath = await resolveLatestArtifactPath(reportsDir, ".html");

      if (!latestReportPath) {
        throw new Error(
          "No WPCC HTML reports found. Run a JSON scan first or regenerate one with `tools/wp-code-check/dist/bin/json-to-html.py`."
        );
      }

      return buildReadResourceResult(WPCC_LATEST_REPORT_URI, HTML_MIME_TYPE, await readResourceText(latestReportPath));
    },

    async readScanResource(scanId: string): Promise<WpccReadResourceResult> {
      const scanPath = await resolveScanPathById(scanId);

      if (!scanPath) {
        throw new Error(`WPCC scan not found: ${scanId}`);
      }

      return buildReadResourceResult(buildScanUri(scanId), JSON_MIME_TYPE, await readResourceText(scanPath));
    },
  };
}