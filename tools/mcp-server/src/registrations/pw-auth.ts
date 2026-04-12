import { ResourceTemplate, type McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import * as z from "zod/v4";
import { AUTH_STATUS_URI_TEMPLATE, type createPwAuthHandlers } from "../handlers/pw-auth.js";
import { errorResult, successResult } from "./shared.js";

type PwAuthHandlers = ReturnType<typeof createPwAuthHandlers>;

const authStatusEntrySchema = z.object({
  user: z.string(),
  exists: z.boolean(),
  lastUpdated: z.string().nullable(),
  age: z.string().nullable(),
  ageHours: z.number().nullable(),
  fresh: z.boolean(),
  validationStatus: z.enum(["fresh", "stale", "missing"]),
  filePath: z.string().nullable(),
  sizeBytes: z.number().nullable(),
});

const pwAuthDoctorCheckSchema = z.object({
  name: z.string(),
  status: z.string(),
  summary: z.string(),
  detail: z.string().nullable(),
});

const pwAuthDoctorAuthSchema = z.object({
  exists: z.boolean(),
  filePath: z.string().nullable(),
  authStatus: z.string(),
});

const pwAuthCheckDomAssertionSchema = z.object({
  type: z.string(),
  passed: z.boolean(),
  message: z.string(),
});

const pwAuthCheckDomItemResultSchema = z.object({
  selector: z.string(),
  status: z.string(),
  match_count: z.number(),
  value: z.union([z.string(), z.boolean()]).nullable(),
  assertion: pwAuthCheckDomAssertionSchema.nullable(),
  screenshot_path: z.string().nullable(),
  errors: z.array(z.string()),
});

const pwAuthCheckDomArtifactsSchema = z.object({
  outputDir: z.string().nullable(),
  resultJson: z.string().nullable(),
  extractFile: z.string().nullable(),
  failureScreenshot: z.string().nullable(),
});

function getAuthStatusUser(uri: URL): string {
  const match = uri.href.match(/^auth:\/\/status\/(.+)$/);
  const user = match?.[1];

  if (!user) {
    throw new Error(`Invalid auth status resource URI: ${uri.href}`);
  }

  return decodeURIComponent(user);
}

export function registerPwAuthTools(server: McpServer, handlers: PwAuthHandlers): void {
  server.registerTool(
    "pw_auth_login",
    {
      description:
        "Authenticate Playwright against WordPress admin using bin/pw-auth with structured Local site input and metadata-only output.",
      inputSchema: {
        siteUrl: z.string().url().describe("Full WordPress site URL, for example http://my-site.local"),
        site: z.string().min(1).describe("Local site name used to construct the internal local-wp command prefix"),
        user: z.string().min(1).default("admin").describe("WordPress username/login to authenticate"),
        redirect: z.string().min(1).optional().describe("Optional wp-admin-relative redirect path after login"),
        force: z.boolean().default(false).describe("Force re-auth even if cached auth is still fresh"),
      },
      outputSchema: {
        site: z.string(),
        user: z.string(),
        siteUrl: z.string(),
        authFile: z.string(),
        cacheFreshUntil: z.string().nullable().describe("Best-effort cache freshness window derived from the auth file mtime, not the actual WordPress session expiry."),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
        retried: z.boolean(),
      },
    },
    async ({ siteUrl, site, user, redirect, force }) => {
      try {
        return successResult(await handlers.login(siteUrl, site, user ?? "admin", redirect, force ?? false));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "pw_auth_status",
    {
      description: "Return Playwright auth cache metadata from bin/pw-auth status without exposing raw storageState contents. Use users[] as the authoritative structured data; rawText/stdout are informational passthrough only.",
      outputSchema: {
        authDir: z.string(),
        users: z.array(authStatusEntrySchema).describe("Authoritative structured auth metadata derived from the auth directory."),
        rawText: z.string().describe("Informational plain-text passthrough from bin/pw-auth status; do not rely on this for program logic."),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number(),
      },
    },
    async () => {
      try {
        return successResult(await handlers.status());
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "pw_auth_clear",
    {
      description: "Clear cached Playwright auth for one explicit user only. Does not expose pw-auth clear-all semantics over MCP.",
      inputSchema: {
        user: z.string().min(1).describe("Explicit WordPress username/login whose cached auth file should be deleted"),
      },
      outputSchema: {
        user: z.string(),
        filePath: z.string(),
        existed: z.boolean(),
        cleared: z.boolean(),
      },
    },
    async ({ user }) => {
      try {
        return successResult(await handlers.clear(user));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "pw_auth_doctor",
    {
      description:
        "Run pw-auth doctor to check Playwright + WordPress readiness for a Local site before attempting login. Returns a structured pass/warn/fail checklist and remediation steps. Use this before pw_auth_login when troubleshooting.",
      inputSchema: {
        siteUrl: z.string().url().describe("Full WordPress site URL, for example http://my-site.local"),
        site: z.string().min(1).describe("Local site name used to construct the internal local-wp command prefix"),
        user: z.string().min(1).default("admin").describe("WordPress username to check auth state for"),
      },
      outputSchema: {
        status: z.string().describe("Overall readiness: ready, partial, or blocked"),
        siteUrl: z.string(),
        user: z.string(),
        checks: z.array(pwAuthDoctorCheckSchema).describe("Ordered list of readiness checks with pass/warn/fail/skip status"),
        auth: pwAuthDoctorAuthSchema.describe("Auth file presence and validity for the requested user"),
        remediations: z.array(z.string()).describe("Actionable steps to resolve any failing checks"),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number().describe("0=ready, 1=partial, 2=blocked"),
      },
    },
    async ({ siteUrl, site, user }) => {
      try {
        return successResult(await handlers.doctor(siteUrl, site, user ?? "admin"));
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerTool(
    "pw_auth_check_dom",
    {
      description:
        "Inspect a page's DOM using Playwright and optional cached auth. Supports single or multi-selector checks, content extraction (exists/text/html), assertions (visible/hidden/text-contains/attr-equals), and screenshots. Use for verifying WordPress admin UI state without writing custom Playwright scripts.",
      inputSchema: {
        url: z.string().url().describe("Page URL to open"),
        selector: z.string().min(1).optional().describe("Single CSS selector to inspect. Use this or selectors, not both"),
        selectors: z.string().min(1).optional().describe("Comma-separated CSS selectors to inspect in one run. Use this or selector, not both"),
        extract: z.enum(["exists", "text", "html"]).default("exists").describe("What to extract from matching element(s)"),
        assert: z.enum(["visible", "hidden", "text-contains", "attr-equals"]).optional().describe("Assertion to run on each matched element"),
        assertValue: z.string().optional().describe("Expected value for text-contains or attr-equals assertions"),
        assertAttr: z.string().optional().describe("Attribute name for attr-equals assertion"),
        screenshot: z.enum(["never", "on-failure", "always"]).default("never").describe("When to capture screenshots"),
        waitFor: z.string().optional().describe("Wait for this selector to appear before checking results — useful for AJAX-rendered content"),
        user: z.string().min(1).default("admin").describe("WordPress username whose cached auth state to use"),
        timeoutMs: z.number().int().positive().default(15_000).describe("Playwright navigation/selector timeout in milliseconds"),
      },
      outputSchema: {
        status: z.string().describe("ok | not_found | assertion_failed | auth_required | error"),
        url: z.string(),
        selector: z.string().nullable(),
        selectors: z.array(z.string()),
        extract: z.string(),
        waitFor: z.string().nullable(),
        assertion: z.record(z.string(), z.unknown()).nullable(),
        authUsed: z.boolean(),
        value: z.union([z.string(), z.boolean()]).nullable().describe("Extracted value for single-selector runs; null for multi-selector"),
        results: z.array(pwAuthCheckDomItemResultSchema).describe("Per-selector results including match count, value, and assertion outcome"),
        artifacts: pwAuthCheckDomArtifactsSchema.describe("Paths to result JSON, extracted content, and screenshots written under temp/playwright/checks/"),
        errors: z.array(z.string()),
        stdout: z.string(),
        stderr: z.string(),
        exitCode: z.number().describe("0=ok, 3=not_found, 4=auth_required, 5=error, 6=assertion_failed"),
      },
    },
    async ({ url, selector, selectors, extract, assert: assertMode, assertValue, assertAttr, screenshot, waitFor, user, timeoutMs }) => {
      try {
        return successResult(
          await handlers.checkDom(
            url,
            selector,
            selectors,
            extract ?? "exists",
            assertMode,
            assertValue,
            assertAttr,
            screenshot ?? "never",
            waitFor,
            user ?? "admin",
            timeoutMs ?? 15_000,
          ),
        );
      } catch (error) {
        return errorResult(error);
      }
    },
  );

  server.registerResource(
    "auth_status_by_user",
    new ResourceTemplate(AUTH_STATUS_URI_TEMPLATE, {
      list: async () => ({
        resources: await handlers.listStatusResources(),
      }),
    }),
    {
      description: "Metadata-only Playwright auth status by user. Never exposes raw storageState, cookies, or tokens, and avoids synthesizing missing-user file paths.",
      mimeType: "application/json",
    },
    async (uri) => handlers.readStatusResource(getAuthStatusUser(uri)),
  );
}
