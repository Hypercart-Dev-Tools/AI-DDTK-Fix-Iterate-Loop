import { access, readFile, readdir, stat } from "node:fs/promises";
import { constants } from "node:fs";
import { homedir } from "node:os";
import path from "node:path";
import { assertAllowedWpCliCommand } from "../security/allowlist.js";
import type { SiteState } from "../state.js";
import { ExecFileTextError, execFileText, type ExecFileText } from "../utils/exec.js";

const DEFAULT_TIMEOUT_MS = 60_000;

export type SiteSummary = Record<string, unknown> & {
  name: string;
  path: string;
  hasWordPress: true;
};

export type ConnectivityResult = Record<string, unknown> & {
  site: string;
  status: "ok" | "error";
  checks: {
    dir: boolean;
    wpConfig: boolean;
    mysql: boolean;
    wpCli: boolean;
  };
};

export type SiteInfoResult = Record<string, unknown> & {
  site: string;
  wpVersion: string | null;
  phpVersion: string | null;
  activeTheme: string | null;
  plugins: Array<{ name: string; status: string; version: string | null }>;
  siteUrl: string | null;
};

export type RunCommandResult = Record<string, unknown> & {
  site: string;
  command: string;
  stdout: string;
  stderr: string;
  exitCode: number;
};

export interface LocalWpHandlerDeps {
  state: SiteState;
  repoRoot: string;
  homeDir?: string;
  timeoutMs?: number;
  execRunner?: ExecFileText;
}

interface ResolvedSite {
  name: string;
  path: string;
  wpConfigPath: string;
  mysqlSocketPath: string | null;
}

function getLocalSitesDir(homeDir: string): string {
  return path.join(homeDir, "Local Sites");
}

function getLocalRunDir(homeDir: string): string {
  return path.join(homeDir, "Library", "Application Support", "Local", "run");
}

async function pathExists(targetPath: string): Promise<boolean> {
  try {
    await access(targetPath, constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

async function isSocket(targetPath: string): Promise<boolean> {
  try {
    return (await stat(targetPath)).isSocket();
  } catch {
    return false;
  }
}

async function findMatchingSiteIds(localRunDir: string, siteName: string): Promise<string[]> {
  if (!(await pathExists(localRunDir))) {
    return [];
  }

  const entries = await readdir(localRunDir, { withFileTypes: true });
  const matches: string[] = [];

  for (const entry of entries) {
    if (!entry.isDirectory()) {
      continue;
    }

    const siteId = entry.name;
    const confDir = path.join(localRunDir, siteId, "conf");

    if (!(await pathExists(confDir))) {
      continue;
    }

    const confEntries = await readdir(confDir, { withFileTypes: true });

    for (const confEntry of confEntries) {
      if (!confEntry.isFile()) {
        continue;
      }

      const confContents = await readFile(path.join(confDir, confEntry.name), "utf8");
      const lines = confContents.split(/\r?\n/).map((line) => line.trim()).filter(Boolean);

      if (lines.includes(siteName)) {
        matches.push(siteId);
        break;
      }
    }
  }

  return matches.sort();
}

function parseCliInfo(stdout: string): Record<string, string> {
  const parsed: Record<string, string> = {};

  for (const line of stdout.split(/\r?\n/)) {
    const match = line.match(/^([^:]+):\s*(.*)$/);

    if (match) {
      parsed[match[1].trim()] = match[2].trim();
    }
  }

  return parsed;
}

function parseJsonArray<T>(stdout: string): T[] {
  if (!stdout.trim()) {
    return [];
  }

  const parsed = JSON.parse(stdout);
  return Array.isArray(parsed) ? parsed : [];
}

function buildTextCommand(commandParts: string[]): string {
  return commandParts.join(" ");
}

export function createLocalWpHandlers(deps: LocalWpHandlerDeps) {
  const homeDir = deps.homeDir ?? homedir();
  const timeoutMs = deps.timeoutMs ?? DEFAULT_TIMEOUT_MS;
  const runExec = deps.execRunner ?? execFileText;
  const localWpBin = path.join(deps.repoRoot, "bin", "local-wp");

  async function resolveSite(siteName: string): Promise<ResolvedSite> {
    const sitePath = path.join(getLocalSitesDir(homeDir), siteName, "app", "public");
    const wpConfigPath = path.join(sitePath, "wp-config.php");

    if (!(await pathExists(sitePath)) || !(await pathExists(wpConfigPath))) {
      throw new Error(`Local site not found or missing wp-config.php: ${siteName}`);
    }

    const matchedSiteIds = await findMatchingSiteIds(getLocalRunDir(homeDir), siteName);

    if (matchedSiteIds.length === 0) {
      throw new Error(`Could not resolve Local run configuration for site: ${siteName}`);
    }

    if (matchedSiteIds.length > 1) {
      throw new Error(`Multiple Local run configurations matched site name exactly: ${siteName}`);
    }

    return {
      name: siteName,
      path: sitePath,
      wpConfigPath,
      mysqlSocketPath: path.join(getLocalRunDir(homeDir), matchedSiteIds[0], "mysql", "mysqld.sock"),
    };
  }

  async function resolveReadOnlySite(site?: string): Promise<ResolvedSite> {
    if (site) {
      return resolveSite(site);
    }

    const activeSite = deps.state.getActiveSite();

    if (!activeSite) {
      throw new Error("No site provided and no active site is currently selected.");
    }

    return resolveSite(activeSite.name);
  }

  return {
    async listSites(): Promise<{ site: null; sites: SiteSummary[] }> {
      const localSitesDir = getLocalSitesDir(homeDir);

      if (!(await pathExists(localSitesDir))) {
        return { site: null, sites: [] };
      }

      const entries = await readdir(localSitesDir, { withFileTypes: true });
      const sites: SiteSummary[] = [];

      for (const entry of entries) {
        if (!entry.isDirectory()) {
          continue;
        }

        const sitePath = path.join(localSitesDir, entry.name, "app", "public");
        const hasWordPress = await pathExists(path.join(sitePath, "wp-config.php"));

        if (!hasWordPress) {
          continue;
        }

        sites.push({
          name: entry.name,
          path: sitePath,
          hasWordPress: true,
        });
      }

      sites.sort((a, b) => a.name.localeCompare(b.name));

      return {
        site: null,
        sites,
      };
    },

    async selectSite(site: string): Promise<{ site: string; activeSite: string; path: string }> {
      const resolvedSite = await resolveSite(site);
      deps.state.setActiveSite({ name: resolvedSite.name, path: resolvedSite.path });

      return {
        site: resolvedSite.name,
        activeSite: resolvedSite.name,
        path: resolvedSite.path,
      };
    },

    async getActiveSite(): Promise<{ site: string | null; activeSite: string | null; path: string | null }> {
      const activeSite = deps.state.getActiveSite();

      return {
        site: activeSite?.name ?? null,
        activeSite: activeSite?.name ?? null,
        path: activeSite?.path ?? null,
      };
    },

    async testConnectivity(site?: string): Promise<ConnectivityResult> {
      const resolvedSite = await resolveReadOnlySite(site);
      const checks = {
        dir: await pathExists(resolvedSite.path),
        wpConfig: await pathExists(resolvedSite.wpConfigPath),
        mysql: resolvedSite.mysqlSocketPath ? await isSocket(resolvedSite.mysqlSocketPath) : false,
        wpCli: false,
      };

      if (checks.dir && checks.wpConfig && checks.mysql) {
        try {
          await runExec(localWpBin, [resolvedSite.name, "cli", "info"], { timeoutMs });
          checks.wpCli = true;
        } catch {
          checks.wpCli = false;
        }
      }

      return {
        site: resolvedSite.name,
        status: Object.values(checks).every(Boolean) ? "ok" : "error",
        checks,
      };
    },

    async getSiteInfo(site?: string): Promise<SiteInfoResult> {
      const resolvedSite = await resolveReadOnlySite(site);

      const [cliInfoResult, wpVersionResult, themesResult, pluginsResult, siteUrlResult] = await Promise.all([
        runExec(localWpBin, [resolvedSite.name, "cli", "info"], { timeoutMs }),
        runExec(localWpBin, [resolvedSite.name, "core", "version"], { timeoutMs }),
        runExec(localWpBin, [resolvedSite.name, "theme", "list", "--format=json"], { timeoutMs }),
        runExec(localWpBin, [resolvedSite.name, "plugin", "list", "--format=json", "--fields=name,status,version"], {
          timeoutMs,
        }),
        runExec(localWpBin, [resolvedSite.name, "option", "get", "siteurl"], { timeoutMs }),
      ]);

      const cliInfo = parseCliInfo(cliInfoResult.stdout);
      const themes = parseJsonArray<Array<{ name?: string; status?: string }>[number]>(themesResult.stdout);
      const plugins = parseJsonArray<Array<{ name?: string; status?: string; version?: string | null }>[number]>(
        pluginsResult.stdout,
      );
      const activeTheme = themes.find((theme) => theme.status === "active")?.name ?? null;

      return {
        site: resolvedSite.name,
        wpVersion: wpVersionResult.stdout.trim() || null,
        phpVersion: cliInfo["PHP version"] ?? null,
        activeTheme,
        plugins: plugins.map((plugin) => ({
          name: plugin.name ?? "unknown",
          status: plugin.status ?? "unknown",
          version: plugin.version ?? null,
        })),
        siteUrl: siteUrlResult.stdout.trim() || null,
      };
    },

    async runCommand(site: string, command: string, args: string[] = []): Promise<RunCommandResult> {
      if (!site) {
        throw new Error("local_wp_run requires an explicit site.");
      }

      await resolveSite(site);

      const normalizedCommand = assertAllowedWpCliCommand(command, args);
      const commandText = buildTextCommand(normalizedCommand);

      try {
        const result = await runExec(localWpBin, [site, ...normalizedCommand, ...args], { timeoutMs });

        return {
          site,
          command: commandText,
          stdout: result.stdout,
          stderr: result.stderr,
          exitCode: result.exitCode,
        };
      } catch (error) {
        if (error instanceof ExecFileTextError) {
          return {
            site,
            command: commandText,
            stdout: error.stdout,
            stderr: error.stderr,
            exitCode: error.exitCode,
          };
        }

        throw error;
      }
    },
  };
}