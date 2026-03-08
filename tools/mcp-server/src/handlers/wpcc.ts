import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import { ExecFileTextError, execFileText, type ExecFileText, type ExecResult } from "../utils/exec.js";

const DEFAULT_TIMEOUT_MS = 300_000;
const DEFAULT_MAX_BUFFER = 25 * 1024 * 1024;

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

export interface WpccHandlerDeps {
  repoRoot: string;
  timeoutMs?: number;
  execRunner?: ExecFileText;
}

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

export function createWpccHandlers(deps: WpccHandlerDeps) {
  const runExec = deps.execRunner ?? execFileText;
  const timeoutMs = deps.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const wpccBin = path.join(deps.repoRoot, "bin", "wpcc");
  const logsDir = path.join(deps.repoRoot, "tools", "wp-code-check", "dist", "logs");
  const reportsDir = path.join(deps.repoRoot, "tools", "wp-code-check", "dist", "reports");

  async function executeWpcc(args: string[]): Promise<ExecResult> {
    try {
      return await runExec(wpccBin, args, { timeoutMs, maxBuffer: DEFAULT_MAX_BUFFER });
    } catch (error) {
      if (error instanceof ExecFileTextError) {
        return { stdout: error.stdout, stderr: error.stderr, exitCode: error.exitCode };
      }

      throw error;
    }
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
      const args = ["--paths", pathsToScan, ...(format === "json" ? ["--format", "json"] : []), ...(verbose ? ["--verbose"] : [])];
      const logsBefore = format === "json" ? await listArtifacts(logsDir, ".json") : [];
      const reportsBefore = format === "json" ? await listArtifacts(reportsDir, ".html") : [];
      const result = await executeWpcc(args);
      const combinedOutput = [result.stdout, result.stderr].filter(Boolean).join("\n");

      if (format === "text") {
        return {
          paths: pathsToScan,
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
        paths: pathsToScan,
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
  };
}