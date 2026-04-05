import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { AiDdtkManager } from './manager';

interface ServerEntry {
  command: string;
  args?: string[];
  env?: Record<string, string>;
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === 'object' && !Array.isArray(value);
}

function readJsonSafe(filePath: string): Record<string, unknown> | null {
  try {
    const raw = fs.readFileSync(filePath, 'utf8');
    const parsed: unknown = JSON.parse(raw);
    if (!isPlainObject(parsed)) {
      console.warn(`[AI-DDTK] Skipping ${filePath}: not a JSON object`);
      return null;
    }
    return parsed;
  } catch {
    // ENOENT (missing) is silent; parse errors get a warning
    if (fs.existsSync(filePath)) {
      console.warn(`[AI-DDTK] Skipping ${filePath}: malformed JSON`);
    }
    return null;
  }
}

function isValidServerEntry(entry: unknown): entry is ServerEntry {
  return isPlainObject(entry) && typeof entry.command === 'string' && entry.command.trim() !== '';
}

function normalizeSnippet(snippet: Record<string, unknown>, sourcePath: string): Record<string, ServerEntry> {
  const raw = Object.prototype.hasOwnProperty.call(snippet, 'mcpServers') && isPlainObject(snippet.mcpServers)
    ? snippet.mcpServers
    : snippet;

  const servers: Record<string, ServerEntry> = {};
  for (const [name, entry] of Object.entries(raw)) {
    if (isValidServerEntry(entry)) {
      servers[name] = entry;
    } else {
      console.warn(`[AI-DDTK] Skipping server "${name}" in ${sourcePath}: missing or invalid "command"`);
    }
  }
  return servers;
}

function loadSnippetsDir(dirPath: string): Record<string, ServerEntry> {
  if (!fs.existsSync(dirPath)) {
    return {};
  }
  const merged: Record<string, ServerEntry> = {};
  const files = fs.readdirSync(dirPath)
    .filter((f) => f.endsWith('.json'))
    .sort((a, b) => a.localeCompare(b));

  for (const file of files) {
    const filePath = path.join(dirPath, file);
    const json = readJsonSafe(filePath);
    if (json) {
      Object.assign(merged, normalizeSnippet(json, filePath));
    }
  }
  return merged;
}

function entryToDefinition(name: string, entry: ServerEntry): vscode.McpStdioServerDefinition {
  return new vscode.McpStdioServerDefinition(
    name,
    entry.command,
    entry.args || [],
    entry.env,
  );
}

export class McpConfigProvider implements vscode.Disposable {
  private manager: AiDdtkManager;
  private changeEmitter: vscode.EventEmitter<void>;
  private watchers: vscode.FileSystemWatcher[] = [];

  constructor(manager: AiDdtkManager, changeEmitter: vscode.EventEmitter<void>) {
    this.manager = manager;
    this.changeEmitter = changeEmitter;
  }

  getServerDefinitions(): vscode.McpStdioServerDefinition[] {
    const config = vscode.workspace.getConfiguration('ai-ddtk');
    if (!config.get('enableMcpServer', true)) {
      return [];
    }

    // Layer 0: static fallback — the core AI-DDTK MCP server
    const servers = new Map<string, ServerEntry>();
    const aiDdtkPath = this.manager.getAiDdtkPath();
    const startScript = path.join(aiDdtkPath, 'tools', 'mcp-server', 'start.sh');
    if (fs.existsSync(aiDdtkPath) && fs.existsSync(startScript)) {
      servers.set('ai-ddtk', { command: 'bash', args: [startScript] });
    }

    const workspaceRoot = this.manager.getWorkspaceRoot();
    if (workspaceRoot) {
      // Layer 1: workspace .mcp.json
      const workspaceMcp = readJsonSafe(path.join(workspaceRoot, '.mcp.json'));
      if (workspaceMcp) {
        for (const [name, entry] of Object.entries(normalizeSnippet(workspaceMcp, '.mcp.json'))) {
          servers.set(name, entry);
        }
      }

      // Layer 2: .vscode/mcp.json (overrides workspace .mcp.json)
      const vscodeMcp = readJsonSafe(path.join(workspaceRoot, '.vscode', 'mcp.json'));
      if (vscodeMcp) {
        for (const [name, entry] of Object.entries(normalizeSnippet(vscodeMcp, '.vscode/mcp.json'))) {
          servers.set(name, entry);
        }
      }

      // Layer 3: .mcp.local.json (gitignored local overrides)
      const localMcp = readJsonSafe(path.join(workspaceRoot, '.mcp.local.json'));
      if (localMcp) {
        for (const [name, entry] of Object.entries(normalizeSnippet(localMcp, '.mcp.local.json'))) {
          servers.set(name, entry);
        }
      }

      // Layer 4: temp/mcp/local-snippets/*.json (individual snippet files)
      const snippetsDir = path.join(workspaceRoot, 'temp', 'mcp', 'local-snippets');
      for (const [name, entry] of Object.entries(loadSnippetsDir(snippetsDir))) {
        servers.set(name, entry);
      }
    }

    return Array.from(servers.entries()).map(([name, entry]) => entryToDefinition(name, entry));
  }

  setupFileWatchers(context: vscode.ExtensionContext): void {
    this.disposeWatchers();

    const workspaceRoot = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceRoot) {
      return;
    }

    const patterns = [
      new vscode.RelativePattern(workspaceRoot, '.mcp.json'),
      new vscode.RelativePattern(workspaceRoot, '.vscode/mcp.json'),
      new vscode.RelativePattern(workspaceRoot, '.mcp.local.json'),
      new vscode.RelativePattern(workspaceRoot, 'temp/mcp/local-snippets/*.json'),
    ];

    for (const pattern of patterns) {
      const watcher = vscode.workspace.createFileSystemWatcher(pattern);
      watcher.onDidChange(() => this.changeEmitter.fire());
      watcher.onDidCreate(() => this.changeEmitter.fire());
      watcher.onDidDelete(() => this.changeEmitter.fire());
      this.watchers.push(watcher);
      context.subscriptions.push(watcher);
    }

    // Re-setup watchers when workspace folders change
    context.subscriptions.push(
      vscode.workspace.onDidChangeWorkspaceFolders(() => {
        this.setupFileWatchers(context);
        this.changeEmitter.fire();
      })
    );
  }

  private disposeWatchers(): void {
    for (const watcher of this.watchers) {
      watcher.dispose();
    }
    this.watchers = [];
  }

  dispose(): void {
    this.disposeWatchers();
  }
}
