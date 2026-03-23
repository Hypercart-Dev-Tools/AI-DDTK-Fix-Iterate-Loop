import { randomBytes } from "node:crypto";
import https from "node:https";
import http from "node:http";

const DEFAULT_TIMEOUT_MS = 30_000;
const PROFILE_RETRIEVE_DELAY_MS = 500;

export interface QmQuery {
  i: number;
  sql: string;
  time: number;
  stack: string[];
  result: number | string;
}

export interface QmDbQueries {
  total: number;
  time: number;
  queries: QmQuery[];
  dupes?: {
    total: number;
    queries: Record<string, number[]>;
  };
  errors?: {
    total: number;
    errors: Array<Record<string, unknown>>;
  };
}

export interface QmOverview {
  time_taken: number;
  time_limit: number;
  time_usage: number;
  memory: number;
  memory_limit: number;
  memory_usage: number;
}

export interface QmHttpRequest {
  url: string;
  method: string;
  response: string | Record<string, unknown>;
  time: number;
  stack: string[];
}

export interface QmProfileData {
  overview: QmOverview | null;
  db_queries: QmDbQueries | Record<string, never>;
  cache: { hit_percentage: number | null; hits: number | null; misses: number | null };
  http: { total?: number; time?: number; requests?: QmHttpRequest[] } | QmHttpRequest[];
  logger: Record<string, Array<{ message: string; stack: string[] }>> | unknown[];
  transients: unknown;
  conditionals: unknown;
  _meta: {
    nonce: string;
    url: string;
    method: string;
    status: number;
    timestamp: string;
    qm_version: string;
  };
}

export type QmProfilePageResult = Record<string, unknown> & {
  site: string;
  path: string;
  method: string;
  statusCode: number;
  overview: QmOverview | null;
  db_queries: QmDbQueries | Record<string, never>;
  cache: Record<string, unknown>;
  http: Record<string, unknown> | unknown[];
  logger: Record<string, unknown> | unknown[];
  transients: unknown;
  conditionals: unknown;
};

export type QmSlowQueriesResult = Record<string, unknown> & {
  site: string;
  path: string;
  total_queries: number;
  total_time: number;
  threshold_ms: number;
  slow_queries: Array<QmQuery & { time_ms: number }>;
};

export type QmDuplicateQueriesResult = Record<string, unknown> & {
  site: string;
  path: string;
  total_duplicates: number;
  duplicates: Array<{
    sql: string;
    count: number;
    query_indices: number[];
  }>;
};

export interface QmHandlerDeps {
  getCookiesForSite: (user: string, domain: string) => Promise<Array<{ name: string; value: string; domain: string }>>;
  timeoutMs?: number;
}

interface FetchOptions {
  url: string;
  method?: string;
  headers?: Record<string, string>;
  body?: string;
  timeoutMs?: number;
}

interface FetchResult {
  statusCode: number;
  headers: Record<string, string | string[] | undefined>;
  body: string;
}

/** Minimal HTTPS/HTTP fetch — avoids external dependencies. */
function fetchUrl(options: FetchOptions): Promise<FetchResult> {
  const { url, method = "GET", headers = {}, body, timeoutMs = DEFAULT_TIMEOUT_MS } = options;
  const parsed = new URL(url);
  const transport = parsed.protocol === "https:" ? https : http;

  return new Promise((resolve, reject) => {
    const req = transport.request(
      parsed,
      {
        method,
        headers,
        timeout: timeoutMs,
        rejectUnauthorized: false, // Local dev sites use self-signed certs
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on("data", (chunk: Buffer) => chunks.push(chunk));
        res.on("end", () => {
          resolve({
            statusCode: res.statusCode ?? 0,
            headers: res.headers as Record<string, string | string[] | undefined>,
            body: Buffer.concat(chunks).toString("utf8"),
          });
        });
      },
    );

    req.on("error", reject);
    req.on("timeout", () => {
      req.destroy();
      reject(new Error(`Request timed out after ${timeoutMs}ms: ${url}`));
    });

    if (body) {
      req.write(body);
    }

    req.end();
  });
}

function generateNonce(): string {
  return randomBytes(16).toString("hex");
}

function extractDomain(siteUrl: string): string {
  return new URL(siteUrl).hostname;
}

function buildCookieHeader(cookies: Array<{ name: string; value: string }>): string {
  return cookies.map((c) => `${c.name}=${c.value}`).join("; ");
}

/**
 * Derive the QM auth cookie from the logged_in cookie.
 *
 * QM's cookie name is `wp-query_monitor_<COOKIEHASH>` and its value is
 * the same as the `wordpress_logged_in_<COOKIEHASH>` cookie value.
 */
function deriveQmCookie(cookies: Array<{ name: string; value: string }>): { name: string; value: string } | null {
  const loggedIn = cookies.find((c) => c.name.startsWith("wordpress_logged_in_"));

  if (!loggedIn) {
    return null;
  }

  const hash = loggedIn.name.replace("wordpress_logged_in_", "");
  return { name: `wp-query_monitor_${hash}`, value: loggedIn.value };
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function createQmHandlers(deps: QmHandlerDeps) {
  const timeoutMs = deps.timeoutMs ?? DEFAULT_TIMEOUT_MS;

  async function getAuthCookies(siteUrl: string, user: string): Promise<Array<{ name: string; value: string }>> {
    const domain = extractDomain(siteUrl);
    const siteCookies = await deps.getCookiesForSite(user, domain);

    if (siteCookies.length === 0) {
      throw new Error(`No cookies found for "${domain}" and user "${user}". Run pw_auth_login first.`);
    }

    const qmCookie = deriveQmCookie(siteCookies);

    if (!qmCookie) {
      throw new Error(`No wordpress_logged_in_* cookie found for "${domain}". Run pw_auth_login first.`);
    }

    return [...siteCookies, qmCookie];
  }

  async function profilePage(
    siteUrl: string,
    pagePath: string,
    method: string,
    bodyData?: Record<string, unknown>,
    extraHeaders?: Record<string, string>,
    user = "admin",
  ): Promise<QmProfileData> {
    const cookies = await getAuthCookies(siteUrl, user);
    const nonce = generateNonce();

    const pageUrl = new URL(pagePath, siteUrl).href;
    const headers: Record<string, string> = {
      Cookie: buildCookieHeader(cookies),
      "X-AIDDTK-QM-NONCE": nonce,
      ...extraHeaders,
    };

    let body: string | undefined;

    if (bodyData && (method === "POST" || method === "PUT")) {
      if (!headers["Content-Type"]) {
        headers["Content-Type"] = "application/x-www-form-urlencoded";
      }

      if (headers["Content-Type"] === "application/json") {
        body = JSON.stringify(bodyData);
      } else {
        body = new URLSearchParams(bodyData as Record<string, string>).toString();
      }
    }

    // Step 1: Hit the page to trigger QM data capture.
    await fetchUrl({ url: pageUrl, method, headers, body, timeoutMs });

    // Step 2: Brief delay then retrieve the profile via REST.
    await sleep(PROFILE_RETRIEVE_DELAY_MS);

    const restBase = siteUrl.replace(/\/+$/, "");
    const profileUrl = `${restBase}/?rest_route=/ai-ddtk-qm/v1/profile/${nonce}`;

    const profileRes = await fetchUrl({
      url: profileUrl,
      method: "GET",
      headers: { Cookie: buildCookieHeader(cookies) },
      timeoutMs,
    });

    if (profileRes.statusCode === 404) {
      throw new Error(
        "QM profile data not found. Ensure the ai-ddtk-qm-bridge mu-plugin is installed and Query Monitor is active.",
      );
    }

    if (profileRes.statusCode !== 200) {
      throw new Error(`Failed to retrieve QM profile (HTTP ${profileRes.statusCode}): ${profileRes.body.slice(0, 200)}`);
    }

    return JSON.parse(profileRes.body) as QmProfileData;
  }

  return {
    async profilePage(
      siteUrl: string,
      pagePath: string,
      method = "GET",
      bodyData?: Record<string, unknown>,
      extraHeaders?: Record<string, string>,
      user = "admin",
    ): Promise<QmProfilePageResult> {
      const profile = await profilePage(siteUrl, pagePath, method, bodyData, extraHeaders, user);
      const domain = extractDomain(siteUrl);

      return {
        site: domain,
        path: pagePath,
        method: profile._meta.method,
        statusCode: profile._meta.status,
        overview: profile.overview,
        db_queries: profile.db_queries,
        cache: profile.cache,
        http: profile.http,
        logger: profile.logger,
        transients: profile.transients,
        conditionals: profile.conditionals,
      };
    },

    async slowQueries(
      siteUrl: string,
      pagePath: string,
      thresholdMs = 50,
      method = "GET",
      bodyData?: Record<string, unknown>,
      user = "admin",
    ): Promise<QmSlowQueriesResult> {
      const profile = await profilePage(siteUrl, pagePath, method, bodyData, undefined, user);
      const domain = extractDomain(siteUrl);
      const dbQueries = profile.db_queries as QmDbQueries;

      if (!dbQueries.queries) {
        return {
          site: domain,
          path: pagePath,
          total_queries: 0,
          total_time: 0,
          threshold_ms: thresholdMs,
          slow_queries: [],
        };
      }

      const thresholdSec = thresholdMs / 1000;
      const slow = dbQueries.queries
        .filter((q) => q.time >= thresholdSec)
        .sort((a, b) => b.time - a.time)
        .map((q) => ({ ...q, time_ms: Math.round(q.time * 10000) / 10 }));

      return {
        site: domain,
        path: pagePath,
        total_queries: dbQueries.total,
        total_time: dbQueries.time,
        threshold_ms: thresholdMs,
        slow_queries: slow,
      };
    },

    async duplicateQueries(
      siteUrl: string,
      pagePath: string,
      method = "GET",
      bodyData?: Record<string, unknown>,
      user = "admin",
    ): Promise<QmDuplicateQueriesResult> {
      const profile = await profilePage(siteUrl, pagePath, method, bodyData, undefined, user);
      const domain = extractDomain(siteUrl);
      const dbQueries = profile.db_queries as QmDbQueries;

      if (!dbQueries.dupes || dbQueries.dupes.total === 0) {
        return {
          site: domain,
          path: pagePath,
          total_duplicates: 0,
          duplicates: [],
        };
      }

      const duplicates = Object.entries(dbQueries.dupes.queries).map(([sql, indices]) => ({
        sql,
        count: indices.length,
        query_indices: indices,
      }));

      duplicates.sort((a, b) => b.count - a.count);

      return {
        site: domain,
        path: pagePath,
        total_duplicates: dbQueries.dupes.total,
        duplicates,
      };
    },
  };
}
