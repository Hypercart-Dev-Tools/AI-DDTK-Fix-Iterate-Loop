import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { execSync } from 'child_process';

export interface AiDdtkStatus {
  installed: boolean;
  path: string;
  wpccAvailable: boolean;
  mcpConfigured: boolean;
  wordPressProject: boolean;
  error?: string;
}

export class AiDdtkManager {
  private config: vscode.WorkspaceConfiguration;
  private aiDdtkPath: string;

  constructor() {
    this.config = vscode.workspace.getConfiguration('ai-ddtk');
    this.aiDdtkPath = this.expandPath(this.config.get('aiDdtkPath', '~/bin/ai-ddtk'));
  }

  reloadConfig() {
    this.config = vscode.workspace.getConfiguration('ai-ddtk');
    this.aiDdtkPath = this.expandPath(this.config.get('aiDdtkPath', '~/bin/ai-ddtk'));
  }

  private expandPath(filePath: string): string {
    if (filePath.startsWith('~')) {
      return filePath.replace('~', process.env.HOME || '');
    }
    return filePath;
  }

  async checkStatus(): Promise<AiDdtkStatus> {
    try {
      const installed = fs.existsSync(this.aiDdtkPath);
      const wpccAvailable = this.checkCommand('wpcc');
      const mcpConfigured = this.isMcpConfigured();
      const wordPressProject = await this.isWordPressProject();

      return {
        installed,
        path: this.aiDdtkPath,
        wpccAvailable,
        mcpConfigured,
        wordPressProject,
      };
    } catch (error) {
      return {
        installed: false,
        path: this.aiDdtkPath,
        wpccAvailable: false,
        mcpConfigured: false,
        wordPressProject: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  private checkCommand(command: string): boolean {
    try {
      execSync(`command -v ${command}`, { shell: '/bin/bash', stdio: 'pipe' });
      return true;
    } catch {
      return false;
    }
  }

  isMcpConfigured(): boolean {
    if (!vscode.workspace.workspaceFolders) {
      return false;
    }

    const workspaceRoot = vscode.workspace.workspaceFolders[0].uri.fsPath;
    return (
      fs.existsSync(path.join(workspaceRoot, '.mcp.local.json')) ||
      fs.existsSync(path.join(workspaceRoot, '.mcp.json')) ||
      fs.existsSync(path.join(workspaceRoot, '.vscode', 'mcp.json'))
    );
  }

  async isWordPressProject(): Promise<boolean> {
    if (!vscode.workspace.workspaceFolders) {
      return false;
    }

    const workspaceRoot = vscode.workspace.workspaceFolders[0].uri.fsPath;

    // Check for full WordPress installs
    const wpIndicators = [
      'wp-config.php',
      'wp-content/plugins',
      'wp-content/themes',
      'wp-includes',
    ];

    for (const indicator of wpIndicators) {
      if (fs.existsSync(path.join(workspaceRoot, indicator))) {
        return true;
      }
    }

    // Check for WordPress theme (style.css with Theme Name header)
    const styleCss = path.join(workspaceRoot, 'style.css');
    if (fs.existsSync(styleCss)) {
      try {
        const head = fs.readFileSync(styleCss, 'utf8').slice(0, 2048);
        if (/Theme Name:/i.test(head)) {
          return true;
        }
      } catch {
        // ignore read errors
      }
    }

    // Check for WordPress plugin (any root .php with Plugin Name header)
    try {
      const rootFiles = fs.readdirSync(workspaceRoot);
      for (const file of rootFiles) {
        if (file.endsWith('.php')) {
          const head = fs.readFileSync(path.join(workspaceRoot, file), 'utf8').slice(0, 2048);
          if (/Plugin Name:/i.test(head)) {
            return true;
          }
        }
      }
    } catch {
      // ignore read errors
    }

    return false;
  }

  getWorkspaceRoot(): string | null {
    return vscode.workspace.workspaceFolders?.[0].uri.fsPath || null;
  }

  getAiDdtkPath(): string {
    return this.aiDdtkPath;
  }

  getWireProjectScript(): string {
    return path.join(this.aiDdtkPath, 'experimental', 'wire-project');
  }
}

