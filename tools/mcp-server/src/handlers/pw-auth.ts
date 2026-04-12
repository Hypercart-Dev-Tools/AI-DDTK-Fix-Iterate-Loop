import { readdir, readFile, rm, stat } from "node:fs/promises";
import path from "node:path";
import * as z from "zod/v4";
import { ExecFileTextError, execFileText, type ExecFileText, type ExecResult } from "../utils/exec.js";
import { parseJsonWithSchema } from "../utils/json-schema.js";

const DEFAULT_TIMEOUT_MS = 120_000;
const DEFAULT_MAX_AGE_HOURS = 12;
const JSON_MIME_TYPE = "application/json";

const pwAuthDoctorJsonSchema = z.object({
  status: z.string().optional(),
  site_url: z.string().optional(),
  user: z.string().optional(),
  checks: z.array(z.object({
    name: z.string(),
    status: z.string(),
    summary: z.string(),
    detail: z.string().nullable().optional(),
  }).passthrough()).optional(),
  auth: z.object({
    exists: z.boolean().optional(),
    file_path: z.string().nullable().optional(),
    status: z.string().optional(),
  }).optional(),
  remediations: z.array(z.string()).optional(),
}).passthrough();

const pwAuthCheckDomJsonSchema = z.object({
  status: z.string().optional(),
  url: z.string().optional(),
  selector: z.string().nullable().optional(),
  selectors: z.array(z.string()).optional(),
  extract: z.string().optional(),
  wait_for: z.string().nullable().optional(),
  assertion: z.record(z.string(), z.unknown()).nullable().optional(),
  auth_used: z.boolean().optional(),
  value: z.union([z.string(), z.boolean()]).nullable().optional(),
  results: z.array(z.object({
    selector: z.string(),
    status: z.string(),
    match_count: z.number(),
    value: z.union([z.string(), z.boolean()]).nullable(),
    assertion: z.object({
      type: z.string(),
      passed: z.boolean(),
      message: z.string(),
    }).nullable(),
    screenshot_path: z.string().nullable(),
    errors: z.array(z.string()),
  }).passthrough()).optional(),
  artifacts: z.object({
    output_dir: z.string().nullable().optional(),
    result_json: z.string().nullable().optional(),
    extract_file: z.string().nullable().optional(),
    failure_screenshot: z.string().nullable().optional(),
  }).optional(),
  errors: z.array(z.string()).optional(),
}).passthrough();

const playwrightStorageStateSchema = z.object({
  cookies: z.array(z.object({
    name: z.string(),
    value: z.string(),
    domain: z.string(),
  }).passthrough()).optional(),
}).passthrough();

export const AUTH_STATUS_URI_TEMPLATE = "auth://status/{user}";

export type PwAuthStatusEntry = Record<string, unknown> & {
  user: string;
  exists: boolean;
  lastUpdated: string | null;
  age: string | null;
  ageHours: number | null;
  fresh: boolean;
  validationStatus: "fresh" | "stale" | "missing";
  filePath: string | null;
  sizeBytes: number | null;
};

export type PwAuthLoginResult = Record<string, unknown> & {
  site: string;
  user: string;
  siteUrl: string;
  authFile: string;
  cacheFreshUntil: string | null;
  stdout: string;
  stderr: string;
  exitCode: number;
  retried: boolean;
};

export type PwAuthStatusResult = Record<string, unknown> & {
  authDir: string;
  users: PwAuthStatusEntry[];
  rawText: string;
  stdout: string;
  stderr: string;
  exitCode: number;
};

export type PwAuthClearResult = Record<string, unknown> & {
  user: string;
  filePath: string;
  existed: boolean;
  cleared: boolean;
};

export type PwAuthDoctorCheck = {
  name: string;
  status: string;
  summary: string;
  detail: string | null;
};

export type PwAuthDoctorAuth = {
  exists: boolean;
  filePath: string | null;
  authStatus: string;
};

export type PwAuthDoctorResult = Record<string, unknown> & {
  status: string;
  siteUrl: string;
  user: string;
  checks: PwAuthDoctorCheck[];
  auth: PwAuthDoctorAuth;
  remediations: string[];
  stdout: string;
  stderr: string;
  exitCode: number;
};

export type PwAuthCheckDomAssertion = {
  type: string;
  passed: boolean;
  message: string;
};

export type PwAuthCheckDomItemResult = {
  selector: string;
  status: string;
  match_count: number;
  value: string | boolean | null;
  assertion: PwAuthCheckDomAssertion | null;
  screenshot_path: string | null;
  errors: string[];
};

export type PwAuthCheckDomArtifacts = {
  outputDir: string | null;
  resultJson: string | null;
  extractFile: string | null;
  failureScreenshot: string | null;
};

export type PwAuthCheckDomResult = Record<string, unknown> & {
  status: string;
  url: string;
  selector: string | null;
  selectors: string[];
  extract: string;
  waitFor: string | null;
  assertion: Record<string, unknown> | null;
  authUsed: boolean;
  value: string | boolean | null;
  results: PwAuthCheckDomItemResult[];
  artifacts: PwAuthCheckDomArtifacts;
  errors: string[];
  stdout: string;
  stderr: string;
  exitCode: number;
};

export type PwAuthResource = {
  uri: string;
  name: string;
  description: string;
  mimeType: typeof JSON_MIME_TYPE;
};

export type PwAuthReadResourceResult = {
  contents: Array<{
    uri: string;
    mimeType: string;
    text: string;
  }>;
};

export interface PwAuthHandlerDeps {
  repoRoot: string;
  workingDir?: string;
  timeoutMs?: number;
  execRunner?: ExecFileText;
  now?: () => number;
}

type AuthStatusEntryOptions = {
  discloseMissingFilePath?: boolean;
};

function sanitizeAuthUser(user: string): string {
  return user.replace(/[^A-Za-z0-9_-]/g, "");
}

/**
 * Normalize a user identifier before using it in auth-state paths.
 *
 * The wrapper stores Playwright state as temp/playwright/.auth/<user>.json, so
 * this rejects path-like or empty values before any filesystem operation.
 */
function normalizeRequestedUser(user: string): string {
  const safeUser = sanitizeAuthUser(user);

  if (!safeUser) {
    throw new Error("pw_auth user must contain at least one alphanumeric, '-' or '_' character.");
  }

  return safeUser;
}

function getAuthDir(workingDir: string): string {
  return path.join(workingDir, "temp", "playwright", ".auth");
}

function getAuthFilePath(workingDir: string, safeUser: string): string {
  return path.join(getAuthDir(workingDir), `${safeUser}.json`);
}

function toDisplayPath(workingDir: string, targetPath: string): string {
  const relativePath = path.relative(workingDir, targetPath);
  return relativePath && !relativePath.startsWith("..") ? relativePath : targetPath;
}

function formatAge(ageMs: number): string {
  const totalMinutes = Math.max(0, Math.floor(ageMs / 60_000));
  const days = Math.floor(totalMinutes / (24 * 60));
  const hours = Math.floor((totalMinutes % (24 * 60)) / 60);
  const minutes = totalMinutes % 60;
  const parts: string[] = [];

  if (days > 0) {
    parts.push(`${days}d`);
  }

  if (hours > 0 || days > 0) {
    parts.push(`${hours}h`);
  }

  parts.push(`${minutes}m`);

  return parts.join(" ");
}

function buildStatusUri(user: string): string {
  return `auth://status/${encodeURIComponent(user)}`;
}

function buildReadResourceResult(uri: string, text: string): PwAuthReadResourceResult {
  return {
    contents: [{ uri, mimeType: JSON_MIME_TYPE, text }],
  };
}

function quoteCommandPrefixArg(arg: string): string {
  return /^[A-Za-z0-9_./:-]+$/.test(arg) ? arg : `'${arg.replace(/'/g, `'\\''`)}'`;
}

function buildWpCliPrefix(site: string): string {
  return ["local-wp", site].map(quoteCommandPrefixArg).join(" ");
}

/**
 * Derive structured auth metadata from the cached Playwright auth file.
 *
 * MCP responses use this instead of exposing raw auth-state content so callers
 * can reason about freshness and file presence without reading credentials.
 */
async function getAuthStatusEntry(
  workingDir: string,
  requestedUser: string,
  nowMs: number,
  options: AuthStatusEntryOptions = {},
): Promise<PwAuthStatusEntry> {
  const safeUser = normalizeRequestedUser(requestedUser);
  const authFilePath = getAuthFilePath(workingDir, safeUser);
  const displayPath = toDisplayPath(workingDir, authFilePath);

  try {
    const fileStats = await stat(authFilePath);

    if (!fileStats.isFile()) {
      throw new Error("Not a file");
    }

    const ageMs = Math.max(0, nowMs - fileStats.mtimeMs);
    const ageHours = Math.floor(ageMs / 3_600_000);
    const fresh = ageHours < DEFAULT_MAX_AGE_HOURS;

    return {
      user: requestedUser,
      exists: true,
      lastUpdated: new Date(fileStats.mtimeMs).toISOString(),
      age: formatAge(ageMs),
      ageHours,
      fresh,
      validationStatus: fresh ? "fresh" : "stale",
      filePath: displayPath,
      sizeBytes: fileStats.size,
    };
  } catch {
    return {
      user: requestedUser,
      exists: false,
      lastUpdated: null,
      age: null,
      ageHours: null,
      fresh: false,
      validationStatus: "missing",
      filePath: options.discloseMissingFilePath === false ? null : displayPath,
      sizeBytes: null,
    };
  }
}

async function listAuthUsers(authDir: string): Promise<string[]> {
  try {
    const entries = await readdir(authDir, { withFileTypes: true });

    return entries
      .filter((entry) => entry.isFile() && entry.name.endsWith(".json"))
      .map((entry) => entry.name.replace(/\.json$/, ""))
      .sort((a, b) => a.localeCompare(b));
  } catch {
    return [];
  }
}

export function createPwAuthHandlers(deps: PwAuthHandlerDeps) {
  const runExec = deps.execRunner ?? execFileText;
  const timeoutMs = deps.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const workingDir = deps.workingDir ?? process.cwd();
  const pwAuthBin = path.join(deps.repoRoot, "bin", "pw-auth");
  const authDir = getAuthDir(workingDir);
  const now = deps.now ?? (() => Date.now());

  return {
    async login(siteUrl: string, site: string, user = "admin", redirect?: string, force = false): Promise<PwAuthLoginResult> {
      const safeUser = normalizeRequestedUser(user);
      const authFilePath = getAuthFilePath(workingDir, safeUser);
      const args = ["login", "--site-url", siteUrl, "--wp-cli", buildWpCliPrefix(site), "--user", user];
      let retried = false;

      if (redirect) {
        args.push("--redirect", redirect);
      }

      if (force) {
        args.push("--force");
      }

      for (let attempt = 0; attempt < 2; attempt += 1) {
        try {
          const result = await runExec(pwAuthBin, args, { cwd: workingDir, timeoutMs });
          const metadata = await getAuthStatusEntry(workingDir, user, now());
          const cacheFreshUntil = metadata.exists && metadata.lastUpdated
            ? new Date(Date.parse(metadata.lastUpdated) + DEFAULT_MAX_AGE_HOURS * 3_600_000).toISOString()
            : null;

          return {
            site,
            user,
            siteUrl,
            authFile: metadata.filePath ?? toDisplayPath(workingDir, authFilePath),
            cacheFreshUntil,
            stdout: result.stdout,
            stderr: result.stderr,
            exitCode: result.exitCode,
            retried,
          };
        } catch (error) {
          if (error instanceof ExecFileTextError && error.timedOut && attempt === 0) {
            retried = true;
            continue;
          }

          if (error instanceof ExecFileTextError) {
            return {
              site,
              user,
              siteUrl,
              authFile: toDisplayPath(workingDir, authFilePath),
              cacheFreshUntil: null,
              stdout: error.stdout,
              stderr: error.stderr,
              exitCode: error.exitCode,
              retried,
            };
          }

          throw error;
        }
      }

      throw new Error("pw_auth_login exhausted retry attempts unexpectedly.");
    },

    async status(): Promise<PwAuthStatusResult> {
      try {
        const result = await runExec(pwAuthBin, ["status"], { cwd: workingDir, timeoutMs });
        const users = await Promise.all((await listAuthUsers(authDir)).map((user) => getAuthStatusEntry(workingDir, user, now())));

        return {
          authDir: toDisplayPath(workingDir, authDir),
          users,
          // Keep the wrapper's plain-text output for debugging, but treat the structured
          // users[] metadata derived from the auth directory as the authoritative MCP data.
          rawText: result.stdout.trim(),
          stdout: result.stdout,
          stderr: result.stderr,
          exitCode: result.exitCode,
        };
      } catch (error) {
        if (error instanceof ExecFileTextError) {
          return {
            authDir: toDisplayPath(workingDir, authDir),
            users: [],
            rawText: error.stdout.trim(),
            stdout: error.stdout,
            stderr: error.stderr,
            exitCode: error.exitCode,
          };
        }

        throw error;
      }
    },

    async clear(user: string): Promise<PwAuthClearResult> {
      const safeUser = normalizeRequestedUser(user);
      const authFilePath = getAuthFilePath(workingDir, safeUser);
      const existed = (await getAuthStatusEntry(workingDir, user, now())).exists;

      await rm(authFilePath, { force: true });

      return {
        user,
        filePath: toDisplayPath(workingDir, authFilePath),
        existed,
        cleared: existed,
      };
    },

    async doctor(siteUrl: string, site: string, user = "admin"): Promise<PwAuthDoctorResult> {
      const args = [
        "doctor",
        "--site-url", siteUrl,
        "--wp-cli", buildWpCliPrefix(site),
        "--user", user,
        "--format", "json",
      ];

      let stdout: string;
      let stderr: string;
      let exitCode: number;

      try {
        const result = await runExec(pwAuthBin, args, { cwd: workingDir, timeoutMs });
        stdout = result.stdout;
        stderr = result.stderr;
        exitCode = result.exitCode;
      } catch (error) {
        if (error instanceof ExecFileTextError && !error.timedOut) {
          // doctor exits 1 (partial) or 2 (blocked) — these are expected non-zero exits
          stdout = error.stdout;
          stderr = error.stderr;
          exitCode = error.exitCode;
        } else {
          throw error;
        }
      }

      let parsed: z.infer<typeof pwAuthDoctorJsonSchema>;
      try {
        parsed = parseJsonWithSchema(stdout.trim(), pwAuthDoctorJsonSchema, "pw-auth doctor");
      } catch {
        return {
          status: "blocked",
          siteUrl,
          user,
          checks: [],
          auth: { exists: false, filePath: null, authStatus: "missing" },
          remediations: [],
          stdout,
          stderr,
          exitCode,
        };
      }

      const rawAuth = parsed.auth;
      return {
        status: parsed.status ?? "blocked",
        siteUrl: parsed.site_url ?? siteUrl,
        user: parsed.user ?? user,
        checks: (parsed.checks as PwAuthDoctorCheck[] | undefined) ?? [],
        auth: {
          exists: rawAuth?.exists ?? false,
          filePath: rawAuth?.file_path ?? null,
          authStatus: rawAuth?.status ?? "missing",
        },
        remediations: parsed.remediations ?? [],
        stdout,
        stderr,
        exitCode,
      };
    },

    async checkDom(
      url: string,
      selector: string | undefined,
      selectors: string | undefined,
      extract = "exists",
      assert?: string,
      assertValue?: string,
      assertAttr?: string,
      screenshot = "never",
      waitFor?: string,
      user = "admin",
      playwrightTimeoutMs = 15_000,
    ): Promise<PwAuthCheckDomResult> {
      const args = ["check", "dom", "--url", url];

      if (selector) {
        args.push("--selector", selector);
      } else if (selectors) {
        args.push("--selectors", selectors);
      }

      args.push("--extract", extract, "--format", "json", "--screenshot", screenshot, "--user", user, "--timeout-ms", String(playwrightTimeoutMs));

      if (assert) { args.push("--assert", assert); }
      if (assertValue) { args.push("--assert-value", assertValue); }
      if (assertAttr) { args.push("--assert-attr", assertAttr); }
      if (waitFor) { args.push("--wait-for", waitFor); }

      let stdout: string;
      let stderr: string;
      let exitCode: number;

      try {
        const result = await runExec(pwAuthBin, args, { cwd: workingDir, timeoutMs });
        stdout = result.stdout;
        stderr = result.stderr;
        exitCode = result.exitCode;
      } catch (error) {
        if (error instanceof ExecFileTextError && !error.timedOut) {
          // check dom exits non-zero for not_found(3), auth_required(4), error(5), assertion_failed(6)
          stdout = error.stdout;
          stderr = error.stderr;
          exitCode = error.exitCode;
        } else {
          throw error;
        }
      }

      let parsed: z.infer<typeof pwAuthCheckDomJsonSchema>;
      try {
        parsed = parseJsonWithSchema(stdout.trim(), pwAuthCheckDomJsonSchema, "pw-auth check dom");
      } catch {
        const fallbackSelectors = selector ? [selector] : (selectors ?? "").split(",").map((s) => s.trim()).filter(Boolean);
        return {
          status: "error",
          url,
          selector: selector ?? null,
          selectors: fallbackSelectors,
          extract,
          waitFor: waitFor ?? null,
          assertion: null,
          authUsed: false,
          value: null,
          results: [],
          artifacts: { outputDir: null, resultJson: null, extractFile: null, failureScreenshot: null },
          errors: ["Failed to parse pw-auth check dom JSON output"],
          stdout,
          stderr,
          exitCode,
        };
      }

      const rawArtifacts = parsed.artifacts;
      return {
        status: parsed.status ?? "error",
        url: parsed.url ?? url,
        selector: parsed.selector ?? null,
        selectors: parsed.selectors ?? [],
        extract: parsed.extract ?? extract,
        waitFor: parsed.wait_for ?? null,
        assertion: parsed.assertion ?? null,
        authUsed: parsed.auth_used ?? false,
        value: parsed.value ?? null,
        results: (parsed.results as PwAuthCheckDomItemResult[] | undefined) ?? [],
        artifacts: {
          outputDir: rawArtifacts?.output_dir ?? null,
          resultJson: rawArtifacts?.result_json ?? null,
          extractFile: rawArtifacts?.extract_file ?? null,
          failureScreenshot: rawArtifacts?.failure_screenshot ?? null,
        },
        errors: parsed.errors ?? [],
        stdout,
        stderr,
        exitCode,
      };
    },

    async listStatusResources(): Promise<PwAuthResource[]> {
      const users = await listAuthUsers(authDir);

      return users.map((user) => ({
        uri: buildStatusUri(user),
        name: `Auth status: ${user}`,
        description: `Playwright auth metadata for ${user}`,
        mimeType: JSON_MIME_TYPE,
      }));
    },

    async readStatusResource(user: string): Promise<PwAuthReadResourceResult> {
      const metadata = await getAuthStatusEntry(workingDir, user, now(), { discloseMissingFilePath: false });
      return buildReadResourceResult(buildStatusUri(user), JSON.stringify(metadata, null, 2));
    },

    /**
     * Extract WordPress cookies from a pw-auth storageState file for a given domain.
     *
     * Returns only cookies whose domain matches (exact or leading-dot), so the
     * caller never sees credentials for unrelated sites.
     */
    async getCookiesForSite(user: string, domain: string): Promise<Array<{ name: string; value: string; domain: string }>> {
      const safeUser = normalizeRequestedUser(user);
      const authFilePath = getAuthFilePath(workingDir, safeUser);

      let raw: string;
      try {
        raw = await readFile(authFilePath, "utf8");
      } catch {
        throw new Error(`No pw-auth state for user "${user}". Run pw_auth_login first.`);
      }

      const state = parseJsonWithSchema(raw, playwrightStorageStateSchema, "pw-auth storage state");
      const cookies = state.cookies ?? [];

      const normalizedDomain = domain.toLowerCase().replace(/^\./, "");

      return cookies.filter((c) => {
        const cookieDomain = c.domain.toLowerCase().replace(/^\./, "");
        return cookieDomain === normalizedDomain;
      }).map((c) => ({ name: c.name, value: c.value, domain: c.domain }));
    },
  };
}
