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
    const mcpLocalPath = path.join(workspaceRoot, '.mcp.local.json');
    return fs.existsSync(mcpLocalPath);
  }

  async isWordPressProject(): Promise<boolean> {
    if (!vscode.workspace.workspaceFolders) {
      return false;
    }

    const workspaceRoot = vscode.workspace.workspaceFolders[0].uri.fsPath;
    const indicators = [
      'wp-config.php',
      'wp-content/plugins',
      'wp-content/themes',
      'wp-includes',
    ];

    for (const indicator of indicators) {
      const fullPath = path.join(workspaceRoot, indicator);
      if (fs.existsSync(fullPath)) {
        return true;
      }
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

