import { execFile } from "node:child_process";

export interface ExecFileTextOptions {
  cwd?: string;
  env?: NodeJS.ProcessEnv;
  timeoutMs?: number;
  maxBuffer?: number;
}

export interface ExecResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

export class ExecFileTextError extends Error {
  readonly stdout: string;
  readonly stderr: string;
  readonly exitCode: number;
  readonly timedOut: boolean;

  constructor(message: string, stdout: string, stderr: string, exitCode = 1, timedOut = false) {
    super(message);
    this.name = "ExecFileTextError";
    this.stdout = stdout;
    this.stderr = stderr;
    this.exitCode = exitCode;
    this.timedOut = timedOut;
  }
}

export type ExecFileText = (
  file: string,
  args: string[],
  options?: ExecFileTextOptions,
) => Promise<ExecResult>;

export const execFileText: ExecFileText = (file, args, options = {}) => {
  const timeoutMs = options.timeoutMs ?? 60_000;
  const maxBuffer = options.maxBuffer ?? 10 * 1024 * 1024;

  return new Promise((resolve, reject) => {
    execFile(
      file,
      args,
      {
        cwd: options.cwd,
        env: options.env,
        timeout: timeoutMs,
        maxBuffer,
      },
      (error, stdout, stderr) => {
        if (error) {
          const exitCode = typeof error.code === "number" ? error.code : 1;
          const timedOut = error.killed && error.signal === "SIGTERM";
          const message = timedOut
            ? `Command timed out after ${timeoutMs}ms: ${file}`
            : `Command failed: ${file}`;

          reject(new ExecFileTextError(message, stdout, stderr, exitCode, timedOut));
          return;
        }

        resolve({ stdout, stderr, exitCode: 0 });
      },
    );
  });
};