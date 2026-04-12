import {
  type RegistryEntry,
  getMutexPorts,
  readServerRegistry,
  resolveRegistryDataPath,
  resolveRegistryMarkdownPath,
  writeServerRegistry,
} from "../server-registry.js";

export type PortStatus = "free" | "allocated" | "mutex";

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
  registryDataPath?: string;
  markdownPath?: string;
}

export function createServersHandlers(deps: ServersHandlerDeps) {
  const { repoRoot, registryDataPath: registryDataPathOverride, markdownPath: markdownPathOverride } = deps;
  const registryDataPath = resolveRegistryDataPath(repoRoot, registryDataPathOverride);
  const markdownPath = resolveRegistryMarkdownPath(repoRoot, markdownPathOverride);

  async function checkPort(port: number): Promise<ServersCheckPortResult> {
    const registry = await readServerRegistry(registryDataPath);
    const mutexPorts = new Set(getMutexPorts(registry));

    if (mutexPorts.has(port)) {
      return {
        port,
        status: "mutex",
        entry: null,
        registryPath: markdownPath,
      };
    }

    const match = registry.entries.find((e) => e.port === port);
    return {
      port,
      status: match ? "allocated" : "free",
      entry: match ?? null,
      registryPath: markdownPath,
    };
  }

  async function listRegistry(): Promise<ServersListRegistryResult> {
    const registry = await readServerRegistry(registryDataPath);

    return {
      entries: registry.entries,
      allocatedPorts: registry.entries.map((e) => e.port),
      mutexPorts: getMutexPorts(registry),
      registryPath: markdownPath,
    };
  }

  async function addEntry(entry: RegistryEntry): Promise<ServersAddEntryResult> {
    const registry = await readServerRegistry(registryDataPath);
    const mutexPorts = new Set(getMutexPorts(registry));

    // Check for conflict
    const conflict = registry.entries.find((e) => e.port === entry.port) ?? null;
    if (conflict) {
      return {
        added: false,
        entry,
        conflict,
        registryPath: markdownPath,
        message: `Port ${entry.port} is already allocated to "${conflict.service}" (${conflict.owner}). Choose a different port.`,
      };
    }

    if (mutexPorts.has(entry.port)) {
      return {
        added: false,
        entry,
        conflict: null,
        registryPath: markdownPath,
        message: `Port ${entry.port} is a mutex port shared by Dify, Valet, and Local WP. Do not register individual services on it.`,
      };
    }

    await writeServerRegistry(registryDataPath, markdownPath, {
      ...registry,
      entries: [...registry.entries, entry],
    });

    return {
      added: true,
      entry,
      conflict: null,
      registryPath: markdownPath,
      message: `Port ${entry.port} registered for "${entry.service}" in ${markdownPath}.`,
    };
  }

  return { checkPort, listRegistry, addEntry };
}
