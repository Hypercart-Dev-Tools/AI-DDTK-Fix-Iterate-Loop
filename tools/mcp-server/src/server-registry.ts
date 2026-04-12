import { readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";
import * as z from "zod/v4";
import { parseJsonWithSchema } from "./utils/json-schema.js";

const GENERATED_START = "<!-- GENERATED:PORT_REGISTRY:START -->";
const GENERATED_END = "<!-- GENERATED:PORT_REGISTRY:END -->";

const registryEntrySchema = z.object({
  port: z.number().int().min(1).max(65535),
  service: z.string(),
  owner: z.string(),
  hostname: z.string(),
  notes: z.string(),
});

const mutexEntrySchema = registryEntrySchema;

const registryRangeSchema = z.object({
  label: z.string().min(1),
  service: z.string(),
  owner: z.string(),
  hostname: z.string(),
  notes: z.string(),
});

const serverRegistrySchema = z.object({
  version: z.literal(1),
  mutexEntries: z.array(mutexEntrySchema),
  entries: z.array(registryEntrySchema),
  ranges: z.array(registryRangeSchema).default([]),
});

export type RegistryEntry = z.infer<typeof registryEntrySchema>;
export type MutexEntry = z.infer<typeof mutexEntrySchema>;
export type RegistryRange = z.infer<typeof registryRangeSchema>;
export type ServerRegistry = z.infer<typeof serverRegistrySchema>;

function sortEntries(entries: RegistryEntry[]): RegistryEntry[] {
  return [...entries].sort((a, b) => a.port - b.port);
}

function normalizePath(filePath: string): string {
  return filePath.startsWith("~") ? path.join(homedir(), filePath.slice(1).replace(/^\/+/, "")) : filePath;
}

export function resolveRegistryDataPath(repoRoot: string, override?: string): string {
  return override ? normalizePath(override) : path.join(repoRoot, "tools", "servers.registry.json");
}

export function resolveRegistryMarkdownPath(repoRoot: string, override?: string): string {
  return override ? normalizePath(override) : path.join(repoRoot, "tools", "servers.md");
}

export function getMutexPorts(registry: ServerRegistry): number[] {
  return registry.mutexEntries.map((entry) => entry.port);
}

export async function readServerRegistry(dataPath: string): Promise<ServerRegistry> {
  const raw = await readFile(dataPath, "utf8");
  const parsed = parseJsonWithSchema(raw, serverRegistrySchema, "servers registry JSON");

  return {
    ...parsed,
    entries: sortEntries(parsed.entries),
  };
}

function renderRegistryRow(portCell: string, row: { service: string; owner: string; hostname: string; notes: string }): string {
  return `| ${portCell} | ${row.service} | ${row.owner} | ${row.hostname} | ${row.notes} |`;
}

export function renderRegistryMarkdown(registry: ServerRegistry): string {
  const lines = [
    "| Port | Service | Owner | Hostname | Notes |",
    "|------|---------|-------|----------|-------|",
    ...registry.mutexEntries.map((entry) => renderRegistryRow(`**${entry.port}**`, entry)),
    ...sortEntries(registry.entries).map((entry) => renderRegistryRow(String(entry.port), entry)),
    ...registry.ranges.map((range) => renderRegistryRow(range.label, range)),
  ];

  return lines.join("\n");
}

function escapeForRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export async function syncRegistryMarkdown(markdownPath: string, registry: ServerRegistry): Promise<void> {
  const content = await readFile(markdownPath, "utf8");
  const replacement = `${GENERATED_START}\n${renderRegistryMarkdown(registry)}\n${GENERATED_END}`;
  const pattern = new RegExp(`${escapeForRegExp(GENERATED_START)}[\\s\\S]*?${escapeForRegExp(GENERATED_END)}`);

  if (!pattern.test(content)) {
    throw new Error(`Generated registry markers not found in ${markdownPath}`);
  }

  await writeFile(markdownPath, content.replace(pattern, replacement), "utf8");
}

export async function writeServerRegistry(dataPath: string, markdownPath: string, registry: ServerRegistry): Promise<void> {
  const normalizedRegistry: ServerRegistry = {
    ...registry,
    entries: sortEntries(registry.entries),
  };

  await writeFile(dataPath, `${JSON.stringify(normalizedRegistry, null, 2)}\n`, "utf8");
  await syncRegistryMarkdown(markdownPath, normalizedRegistry);
}
