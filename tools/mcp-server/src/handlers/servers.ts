import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { homedir } from "node:os";

const REGISTRY_HEADER = "| Port | Service | Owner | Hostname | Notes |";
const REGISTRY_SEPARATOR = "|------|---------|-------|----------|-------|";
const MUTEX_PORTS = new Set([80, 443]);

export type PortStatus = "free" | "allocated" | "mutex";

export type RegistryEntry = {
  port: number;
  service: string;
  owner: string;
  hostname: string;
  notes: string;
};

export type ServersCheckPortResult = Record<string, unknown> & {
  port: number;
  status: PortStatus;
  entry: RegistryEntry | null;
  registryPath: string;
};

export type ServersListRegistryResult = Record<string, unknown> & {
  entries: RegistryEntry[];
  allocatedPorts: number[];
  mutexPorts: number[];
  registryPath: string;
};

export type ServersAddEntryResult = Record<string, unknown> & {
  added: boolean;
  entry: RegistryEntry;
  conflict: RegistryEntry | null;
  registryPath: string;
  message: string;
};

export interface ServersHandlerDeps {
  repoRoot: string;
  registryPath?: string;
}

function resolveRegistryPath(repoRoot: string, override?: string): string {
  if (override) {
    return override.startsWith("~") ? override.replace("~", homedir()) : override;
  }
  return path.join(repoRoot, "tools/servers.md");
}

/**
 * Parse the Port Allocation Registry table from servers.md.
 * Returns only rows that begin with a numeric port (skips mutex-only rows
 * that start with bold text like "**MUTEX**").
 */
function parseRegistry(content: string): RegistryEntry[] {
  const lines = content.split("\n");
  const tableStart = lines.findIndex((l) => l.includes(REGISTRY_HEADER));
  if (tableStart === -1) return [];

  const entries: RegistryEntry[] = [];

  for (let i = tableStart + 2; i < lines.length; i++) {
    const line = lines[i].trim();
    // Stop at blank line or non-table line
    if (!line.startsWith("|") || line === "") break;

    const cells = line
      .split("|")
      .map((c) => c.trim())
      .filter((_, idx, arr) => idx > 0 && idx < arr.length - 1);

    if (cells.length < 4) continue;

    const portNum = parseInt(cells[0] ?? "", 10);
    if (isNaN(portNum)) continue; // skip mutex header rows

    entries.push({
      port: portNum,
      service: cells[1] ?? "",
      owner: cells[2] ?? "",
      hostname: cells[3] ?? "",
      notes: cells[4] ?? "",
    });
  }

  return entries;
}

/**
 * Append a new row immediately before the blank line that follows the last
 * table row, preserving the existing table formatting.
 */
function appendRegistryRow(content: string, entry: RegistryEntry): string {
  const lines = content.split("\n");
  const tableStart = lines.findIndex((l) => l.includes(REGISTRY_HEADER));
  if (tableStart === -1) {
    throw new Error("Port Allocation Registry table not found in servers.md");
  }

  // Find the last table row (last line beginning with "|" after tableStart)
  let lastTableRow = tableStart + 1; // separator line
  for (let i = tableStart + 2; i < lines.length; i++) {
    if (lines[i].trim().startsWith("|")) {
      lastTableRow = i;
    } else {
      break;
    }
  }

  const newRow = `| ${entry.port} | ${entry.service} | ${entry.owner} | ${entry.hostname} | ${entry.notes} |`;
  lines.splice(lastTableRow + 1, 0, newRow);
  return lines.join("\n");
}

export function createServersHandlers(deps: ServersHandlerDeps) {
  const { repoRoot, registryPath: registryPathOverride } = deps;

  async function checkPort(port: number): Promise<ServersCheckPortResult> {
    const registryPath = resolveRegistryPath(repoRoot, registryPathOverride);
    const content = await readFile(registryPath, "utf8");
    const entries = parseRegistry(content);

    if (MUTEX_PORTS.has(port)) {
      return {
        port,
        status: "mutex",
        entry: null,
        registryPath,
      };
    }

    const match = entries.find((e) => e.port === port);
    return {
      port,
      status: match ? "allocated" : "free",
      entry: match ?? null,
      registryPath,
    };
  }

  async function listRegistry(): Promise<ServersListRegistryResult> {
    const registryPath = resolveRegistryPath(repoRoot, registryPathOverride);
    const content = await readFile(registryPath, "utf8");
    const entries = parseRegistry(content);

    return {
      entries,
      allocatedPorts: entries.map((e) => e.port),
      mutexPorts: [...MUTEX_PORTS],
      registryPath,
    };
  }

  async function addEntry(entry: RegistryEntry): Promise<ServersAddEntryResult> {
    const registryPath = resolveRegistryPath(repoRoot, registryPathOverride);
    const content = await readFile(registryPath, "utf8");
    const entries = parseRegistry(content);

    // Check for conflict
    const conflict = entries.find((e) => e.port === entry.port) ?? null;
    if (conflict) {
      return {
        added: false,
        entry,
        conflict,
        registryPath,
        message: `Port ${entry.port} is already allocated to "${conflict.service}" (${conflict.owner}). Choose a different port.`,
      };
    }

    if (MUTEX_PORTS.has(entry.port)) {
      return {
        added: false,
        entry,
        conflict: null,
        registryPath,
        message: `Port ${entry.port} is a mutex port shared by Dify, Valet, and Local WP. Do not register individual services on it.`,
      };
    }

    const updated = appendRegistryRow(content, entry);
    await writeFile(registryPath, updated, "utf8");

    return {
      added: true,
      entry,
      conflict: null,
      registryPath,
      message: `Port ${entry.port} registered for "${entry.service}" in ${registryPath}.`,
    };
  }

  return { checkPort, listRegistry, addEntry };
}
