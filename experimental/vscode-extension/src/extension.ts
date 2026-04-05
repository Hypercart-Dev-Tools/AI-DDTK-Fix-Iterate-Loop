import * as vscode from 'vscode';
import { AiDdtkManager } from './manager';
import { StatusBarManager } from './statusBar';
import { CommandHandler } from './commands';
import { McpConfigProvider } from './mcpConfig';

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
  // Dynamically discovers and merges MCP server configs from:
  //   Layer 0: static AI-DDTK server (~/bin/ai-ddtk/tools/mcp-server/start.sh)
  //   Layer 1: workspace .mcp.json
  //   Layer 2: .vscode/mcp.json
  //   Layer 3: .mcp.local.json (gitignored local overrides)
  //   Layer 4: temp/mcp/local-snippets/*.json (individual snippet files)
  // File watchers trigger re-query when any config changes on disk.
  const mcpChangeEmitter = new vscode.EventEmitter<void>();
  context.subscriptions.push(mcpChangeEmitter);

  const mcpConfigProvider = new McpConfigProvider(manager, mcpChangeEmitter);
  context.subscriptions.push(mcpConfigProvider);

  context.subscriptions.push(
    vscode.lm.registerMcpServerDefinitionProvider('ai-ddtk', {
      onDidChangeMcpServerDefinitions: mcpChangeEmitter.event,
      provideMcpServerDefinitions: async () => mcpConfigProvider.getServerDefinitions(),
      resolveMcpServerDefinition: async (server) => server,
    })
  );

  mcpConfigProvider.setupFileWatchers(context);

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

