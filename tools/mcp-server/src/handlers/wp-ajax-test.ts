import path from "node:path";
import { ExecFileTextError, execFileText, type ExecFileText, type ExecResult } from "../utils/exec.js";

const DEFAULT_TIMEOUT_MS = 60_000;

type AjaxError = {
  code: string;
  message: string;
};

export type WpAjaxTestResult = Record<string, unknown> & {
  url: string;
  action: string;
  method: "GET" | "POST";
  nopriv: boolean;
  insecure: boolean;
  authProvided: boolean;
  success: boolean;
  statusCode: number | null;
  responseTimeMs: number | null;
  response: unknown;
  headers: Record<string, unknown> | null;
  error: AjaxError | null;
  suggestions: string[] | null;
  stdout: string;
  stderr: string;
  exitCode: number;
};

export interface WpAjaxTestHandlerDeps {
  repoRoot: string;
  workingDir?: string;
  timeoutMs?: number;
  execRunner?: ExecFileText;
}

function parseJsonObject(text: string): Record<string, unknown> | null {
  const trimmed = text.trim();

  if (!trimmed) {
    return null;
  }

  try {
    const parsed = JSON.parse(trimmed);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? (parsed as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

function toNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function toHeaders(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

function toError(value: unknown): AjaxError | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const errorValue = value as Record<string, unknown>;
  const code = typeof errorValue.code === "string" && errorValue.code.trim() ? errorValue.code : null;
  const message = typeof errorValue.message === "string" && errorValue.message.trim() ? errorValue.message : null;

  return code && message ? { code, message } : null;
}

function toSuggestions(value: unknown): string[] | null {
  if (!Array.isArray(value)) {
    return null;
  }

  const suggestions = value.filter((entry): entry is string => typeof entry === "string" && entry.trim().length > 0);
  return suggestions.length > 0 ? suggestions : null;
}

function normalizeAuthPath(authFile?: string): string | undefined {
  if (!authFile) {
    return undefined;
  }

  if (authFile.startsWith("-")) {
    throw new Error("wp_ajax_test auth file path must not start with '-'.");
  }

  return authFile;
}

function assertHttpUrl(url: string): void {
  let parsedUrl: URL;

  try {
    parsedUrl = new URL(url);
  } catch {
    throw new Error("wp_ajax_test requires a valid URL.");
  }

  if (parsedUrl.protocol !== "http:" && parsedUrl.protocol !== "https:") {
    throw new Error("wp_ajax_test only allows http:// or https:// URLs.");
  }
}

export function createWpAjaxTestHandlers(deps: WpAjaxTestHandlerDeps) {
  const runExec = deps.execRunner ?? execFileText;
  const timeoutMs = deps.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const workingDir = deps.workingDir ?? process.cwd();
  const wpAjaxTestBin = path.join(deps.repoRoot, "bin", "wp-ajax-test");

  async function executeWpAjaxTest(args: string[]): Promise<ExecResult> {
    try {
      return await runExec(wpAjaxTestBin, args, { cwd: workingDir, timeoutMs });
    } catch (error) {
      if (error instanceof ExecFileTextError) {
        return { stdout: error.stdout, stderr: error.stderr, exitCode: error.exitCode };
      }

      throw error;
    }
  }

  return {
    async runTest(
      url: string,
      action: string,
      data: Record<string, unknown> = {},
      authFile?: string,
      method: "GET" | "POST" = "POST",
      nopriv = false,
      insecure = false,
    ): Promise<WpAjaxTestResult> {
      assertHttpUrl(url);
      const normalizedAuthFile = normalizeAuthPath(authFile);
      const args = ["--url", url, "--action", action, "--data", JSON.stringify(data), "--format", "json", "--method", method];

      if (normalizedAuthFile) {
        args.push("--auth", normalizedAuthFile);
      }

      if (nopriv) {
        args.push("--nopriv");
      }

      if (insecure) {
        args.push("--insecure");
      }

      const result = await executeWpAjaxTest(args);

      if (result.exitCode === 0) {
        const parsed = parseJsonObject(result.stdout);

        if (!parsed) {
          throw new Error("wp_ajax_test expected JSON output on stdout from bin/wp-ajax-test.");
        }

        return {
          url,
          action,
          method,
          nopriv,
          insecure,
          authProvided: Boolean(normalizedAuthFile),
          success: parsed.success === true,
          statusCode: toNumber(parsed.status_code),
          responseTimeMs: toNumber(parsed.response_time_ms),
          response: parsed.response ?? null,
          headers: toHeaders(parsed.headers),
          error: null,
          suggestions: null,
          stdout: result.stdout,
          stderr: result.stderr,
          exitCode: result.exitCode,
        };
      }

      const parsedError = parseJsonObject(result.stderr) ?? parseJsonObject(result.stdout);
      const fallbackMessage = result.stderr.trim() || result.stdout.trim() || "wp-ajax-test failed.";

      return {
        url,
        action,
        method,
        nopriv,
        insecure,
        authProvided: Boolean(normalizedAuthFile),
        success: false,
        statusCode: null,
        responseTimeMs: null,
        response: null,
        headers: null,
        error: toError(parsedError?.error) ?? { code: "WP_AJAX_TEST_FAILED", message: fallbackMessage },
        suggestions: toSuggestions(parsedError?.suggestions),
        stdout: result.stdout,
        stderr: result.stderr,
        exitCode: result.exitCode,
      };
    },
  };
}