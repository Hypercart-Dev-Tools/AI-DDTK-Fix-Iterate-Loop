import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs';
import { AiDdtkManager } from './manager';
import { StatusBarManager } from './statusBar';
import { CommandHandler } from './commands';

let manager: AiDdtkManager;
let statusBar: StatusBarManager;
let commandHandler: CommandHandler;

export async function activate(context: vscode.ExtensionContext) {
  console.log('AI-DDTK extension activating...');

  // Initialize managers
  manager = new AiDdtkManager();
  statusBar = new StatusBarManager();
  commandHandler = new CommandHandler(manager);

  // --- MCP server registration ---
  // Exposes the AI-DDTK MCP server to ALL VS Code MCP clients:
  // GitHub Copilot, Cline, Continue, and any future VS Code agent.
  // Claude Code discovers the server via .mcp.json (separate mechanism).
  const mcpChangeEmitter = new vscode.EventEmitter<void>();
  context.subscriptions.push(mcpChangeEmitter);

  context.subscriptions.push(
    vscode.lm.registerMcpServerDefinitionProvider('ai-ddtk', {
      onDidChangeMcpServerDefinitions: mcpChangeEmitter.event,
      provideMcpServerDefinitions: async () => {
        const aiDdtkPath = manager.getAiDdtkPath();
        const startScript = path.join(aiDdtkPath, 'tools', 'mcp-server', 'start.sh');
        if (!fs.existsSync(aiDdtkPath) || !fs.existsSync(startScript)) {
          return [];
        }
        // McpStdioServerDefinition(label, command, args?, env?, version?)
        return [
          new vscode.McpStdioServerDefinition('AI-DDTK', 'bash', [startScript], undefined, '1.0.0'),
        ];
      },
      resolveMcpServerDefinition: async (server) => server,
    })
  );
  // Fire when the user changes the aiDdtkPath setting so VS Code re-queries
  // (wired into the config-change handler below)

  // Register commands
  const commands = [
    vscode.commands.registerCommand('ai-ddtk.wireProject', () =>
      commandHandler.wireProject()
    ),
    vscode.commands.registerCommand('ai-ddtk.runPreflight', () =>
      commandHandler.runPreflight()
    ),
    vscode.commands.registerCommand('ai-ddtk.runWpcc', () =>
      commandHandler.runWpcc()
    ),
    vscode.commands.registerCommand('ai-ddtk.openDocs', () =>
      commandHandler.openDocs()
    ),
    vscode.commands.registerCommand('ai-ddtk.checkStatus', () =>
      commandHandler.checkStatus()
    ),
  ];

  context.subscriptions.push(...commands);

  // Initialize status bar
  statusBar.show();
  context.subscriptions.push(statusBar);

  // Check AI-DDTK status on activation
  const status = await manager.checkStatus();
  statusBar.update(status);

  // Watch for configuration changes; re-notify MCP clients if the path changes
  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration((e) => {
      if (e.affectsConfiguration('ai-ddtk')) {
        manager.reloadConfig();
        mcpChangeEmitter.fire(); // tell VS Code to re-query MCP server definitions
      }
    })
  );

  // Auto-wire on open if configured
  const config = vscode.workspace.getConfiguration('ai-ddtk');
  if (config.get('autoWireOnOpen') && vscode.workspace.workspaceFolders) {
    const isWordPressProject = await manager.isWordPressProject();
    if (isWordPressProject && !manager.isMcpConfigured()) {
      const choice = await vscode.window.showInformationMessage(
        'WordPress project detected. Wire for AI-DDTK?',
        'Wire Now',
        'Later',
        'Never'
      );

      if (choice === 'Wire Now') {
        await commandHandler.wireProject();
      } else if (choice === 'Never') {
        config.update('autoWireOnOpen', false, vscode.ConfigurationTarget.Workspace);
      }
    }
  }

  console.log('AI-DDTK extension activated successfully');
}

export function deactivate() {
  console.log('AI-DDTK extension deactivating...');
}

