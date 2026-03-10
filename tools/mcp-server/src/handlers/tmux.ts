import path from "node:path";
import { assertAllowedTmuxCommand } from "../security/allowlist.js";
import { ExecFileTextError, execFileText, type ExecFileText, type ExecResult } from "../utils/exec.js";

const DEFAULT_TIMEOUT_MS = 10_000;

export type TmuxSessionSummary = Record<string, unknown> & {
  session: string;
  windows: number;
  attached: boolean;
  state: "attached" | "detached";
};

export type TmuxStartResult = Record<string, unknown> & {
  session: string;
  cwd: string;
  logFile: string | null;
  reused: boolean;
  stdout: string;
  stderr: string;
  exitCode: number;
};

export type TmuxStatusResult = Record<string, unknown> & {
  session: string;
  exists: boolean;
  path: string | null;
  windows: number | null;
  logFile: string | null;
  tmuxVersion: string | null;
  rawText: string;
  stdout: string;
  stderr: string;
  exitCode: number;
};

export type TmuxSendResult = Record<string, unknown> & {
  session: string;
  command: string;
  stdout: string;
  stderr: string;
  exitCode: number;
};

export type TmuxCaptureResult = Record<string, unknown> & {
  session: string;
  tail: number;
  output: string;
  stdout: string;
  stderr: string;
  exitCode: number;
};

export type TmuxStopResult = Record<string, unknown> & {
  session: string;
  stopped: boolean;
  stdout: string;
  stderr: string;
  exitCode: number;
};

export type TmuxListResult = Record<string, unknown> & {
  sessions: TmuxSessionSummary[];
  rawText: string;
  stdout: string;
  stderr: string;
  exitCode: number;
};

export interface TmuxHandlerDeps {
  repoRoot: string;
  workingDir?: string;
  timeoutMs?: number;
  execRunner?: ExecFileText;
}

function sanitizeSessionName(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+/, "").replace(/-+$/, "").replace(/-+/g, "-");
}

function normalizeSessionName(value: string): string {
  const sanitized = sanitizeSessionName(value) || "workspace";
  return sanitized.startsWith("aiddtk-") ? sanitized : `aiddtk-${sanitized}`;
}

function resolveSessionName(session: string | undefined, cwd: string): string {
  return normalizeSessionName(session ?? path.basename(cwd));
}

function resolveCwd(workingDir: string, requestedCwd?: string): string {
  return requestedCwd ? path.resolve(workingDir, requestedCwd) : workingDir;
}

function extractField(text: string, label: string): string | null {
  const escapedLabel = label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

  for (const line of text.split(/\r?\n/)) {
    const match = line.match(new RegExp(`^${escapedLabel}:\\s*(.*)$`));

    if (match?.[1]) {
      return match[1].trim();
    }
  }

  return null;
}

function toNumber(value: string | null): number | null {
  if (!value) {
    return null;
  }

  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseListOutput(stdout: string): TmuxSessionSummary[] {
  const trimmed = stdout.trim();

  if (!trimmed || trimmed === "No AI-DDTK tmux sessions found.") {
    return [];
  }

  return trimmed
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .flatMap((line) => {
      const [session, windowsText, state] = line.split("\t");
      const windows = Number.parseInt(windowsText ?? "", 10);

      if (!session || !Number.isFinite(windows) || (state !== "attached" && state !== "detached")) {
        return [];
      }

      return [{ session, windows, attached: state === "attached", state } satisfies TmuxSessionSummary];
    });
}

export function createTmuxHandlers(deps: TmuxHandlerDeps) {
  const runExec = deps.execRunner ?? execFileText;
  const timeoutMs = deps.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const workingDir = deps.workingDir ?? process.cwd();
  const tmuxBin = path.join(deps.repoRoot, "bin", "aiddtk-tmux");

  async function executeTmux(args: string[]): Promise<ExecResult> {
    try {
      return await runExec(tmuxBin, args, { cwd: workingDir, timeoutMs });
    } catch (error) {
      if (error instanceof ExecFileTextError) {
        return { stdout: error.stdout, stderr: error.stderr, exitCode: error.exitCode };
      }

      throw error;
    }
  }

  return {
    async start(cwd?: string, session?: string): Promise<TmuxStartResult> {
      const resolvedCwd = resolveCwd(workingDir, cwd);
      const resolvedSession = resolveSessionName(session, resolvedCwd);
      const result = await executeTmux(["start", "--session", resolvedSession, "--cwd", resolvedCwd]);

      return {
        session: resolvedSession,
        cwd: extractField(result.stdout, "Working directory") ?? resolvedCwd,
        logFile: extractField(result.stdout, "Log file"),
        reused: result.stdout.includes("Session already running:"),
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      };
    },

    async status(session?: string): Promise<TmuxStatusResult> {
      const resolvedSession = resolveSessionName(session, workingDir);
      const result = await executeTmux(["status", "--session", resolvedSession]);

      return {
        session: extractField(result.stdout, "Session") ?? resolvedSession,
        exists: result.exitCode === 0,
        path: extractField(result.stdout, "Path"),
        windows: toNumber(extractField(result.stdout, "Windows")),
        logFile: extractField(result.stdout, "Log file"),
        tmuxVersion: extractField(result.stdout, "tmux"),
        rawText: result.stdout.trim(),
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      };
    },

    async list(): Promise<TmuxListResult> {
      const result = await executeTmux(["list"]);

      return {
        sessions: parseListOutput(result.stdout),
        rawText: result.stdout.trim(),
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      };
    },

    async send(command: string, session?: string): Promise<TmuxSendResult> {
      const resolvedSession = resolveSessionName(session, workingDir);
      assertAllowedTmuxCommand(command, deps.repoRoot);
      const result = await executeTmux(["send", "--session", resolvedSession, "--command", command]);

      return {
        session: resolvedSession,
        command,
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      };
    },

    async capture(tail = 200, session?: string): Promise<TmuxCaptureResult> {
      const resolvedSession = resolveSessionName(session, workingDir);
      const result = await executeTmux(["capture", "--session", resolvedSession, "--tail", String(tail)]);

      return {
        session: resolvedSession,
        tail,
        output: result.stdout,
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      };
    },

    async stop(session?: string): Promise<TmuxStopResult> {
      const resolvedSession = resolveSessionName(session, workingDir);
      const result = await executeTmux(["stop", "--session", resolvedSession]);

      return {
        session: resolvedSession,
        stopped: result.exitCode === 0,
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      };
    },
  };
}