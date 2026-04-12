import path from "node:path";
import { ExecFileTextError, execFileText, type ExecFileText, type ExecResult } from "../utils/exec.js";

const DEFAULT_TIMEOUT_MS = 30_000;

export type PostFlightMode = "report" | "commit" | "push";

export type PostFlightCheckResult = Record<string, unknown> & {
  check: string;
  status: "ok" | "missing" | "stale" | "dirty" | "error";
  message: string;
};

export type PostFlightResult = Record<string, unknown> & {
  mode: PostFlightMode;
  dryRun: boolean;
  force: boolean;
  checks: PostFlightCheckResult[];
  gitBranch: string;
  gitState: "clean" | "dirty";
  modifiedFiles: number;
  untrackedFiles: number;
  stdout: string;
  stderr: string;
  exitCode: number;
};

export interface PostFlightHandlerDeps {
  repoRoot: string;
  timeoutMs?: number;
  execRunner?: ExecFileText;
}

export function createPostFlightHandlers(deps: PostFlightHandlerDeps) {
  const { repoRoot, timeoutMs = DEFAULT_TIMEOUT_MS, execRunner = execFileText } = deps;
  const scriptPath = path.join(repoRoot, "bin/post-flight");

  async function runPostFlight(options: {
    mode?: PostFlightMode;
    dryRun?: boolean;
    force?: boolean;
    skipValidation?: boolean;
  }): Promise<PostFlightResult> {
    const { mode = "report", dryRun = false, force = false, skipValidation = false } = options;

    const args: string[] = [];

    if (mode === "commit") {
      args.push("--commit");
    } else if (mode === "push") {
      args.push("--push");
    }

    if (force) {
      args.push("--force");
    }

    if (dryRun) {
      args.push("--dry-run");
    }

    if (skipValidation) {
      args.push("--no-validate");
    }

    try {
      const result = await execRunner("bash", [scriptPath, ...args], {
        cwd: repoRoot,
        timeoutMs,
      });

      // Parse stdout for check results and git state
      const lines = result.stdout.split("\n");
      const checks: PostFlightCheckResult[] = [];
      let gitBranch = "unknown";
      let gitState: "clean" | "dirty" = "clean";
      let modifiedFiles = 0;
      let untrackedFiles = 0;

      for (const line of lines) {
        if (line.includes("4X4.md")) {
          checks.push({
            check: "4X4.md",
            status: line.includes("✓") ? "ok" : line.includes("⚠") ? "stale" : "error",
            message: line,
          });
        } else if (line.includes("CHANGELOG.md")) {
          checks.push({
            check: "CHANGELOG.md",
            status: line.includes("✓") ? "ok" : line.includes("⚠") ? "stale" : "error",
            message: line,
          });
        } else if (line.includes("Memory:")) {
          checks.push({
            check: "memory-duplicates",
            status: line.includes("✓") ? "ok" : line.includes("⚠") ? "stale" : "error",
            message: line,
          });
        } else if (line.includes("Build validation") || line.includes("syntax check") || line.includes("npm build") || line.includes("composer validate") || line.includes("No build validators")) {
          checks.push({
            check: "build",
            status: line.includes("✓") || line.includes("ℹ") ? "ok" : "error",
            message: line,
          });
        } else if (line.includes("Branch:")) {
          const match = line.match(/Branch:\s+(\S+)/);
          if (match) gitBranch = match[1];
        } else if (line.includes("Git state:")) {
          if (line.includes("clean")) {
            gitState = "clean";
          } else {
            gitState = "dirty";
            const modMatch = line.match(/(\d+)\s+modified/);
            const untMatch = line.match(/(\d+)\s+untracked/);
            if (modMatch) modifiedFiles = parseInt(modMatch[1], 10);
            if (untMatch) untrackedFiles = parseInt(untMatch[1], 10);
          }
        }
      }

      return {
        mode,
        dryRun,
        force,
        checks: checks.length > 0 ? checks : [{ check: "session", status: "ok", message: "Session check complete" }],
        gitBranch,
        gitState,
        modifiedFiles,
        untrackedFiles,
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      };
    } catch (error) {
      if (error instanceof ExecFileTextError) {
        return {
          mode,
          dryRun,
          force,
          checks: [
            {
              check: "script",
              status: "error",
              message: error.message,
            },
          ],
          gitBranch: "unknown",
          gitState: "clean",
          modifiedFiles: 0,
          untrackedFiles: 0,
          stdout: error.stdout || "",
          stderr: error.stderr || error.message,
          exitCode: error.exitCode || 2,
        };
      }
      throw error;
    }
  }

  return { runPostFlight };
}

