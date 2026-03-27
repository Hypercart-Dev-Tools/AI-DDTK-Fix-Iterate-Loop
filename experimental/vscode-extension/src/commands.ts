import * as vscode from 'vscode';
import * as path from 'path';
import { AiDdtkManager } from './manager';

export class CommandHandler {
  constructor(private manager: AiDdtkManager) {}

  async wireProject() {
    const workspaceRoot = this.manager.getWorkspaceRoot();
    if (!workspaceRoot) {
      vscode.window.showErrorMessage('No workspace folder open');
      return;
    }

    const isWordPress = await this.manager.isWordPressProject();
    if (!isWordPress) {
      const choice = await vscode.window.showWarningMessage(
        'This does not appear to be a WordPress project. Continue anyway?',
        'Yes',
        'No'
      );
      if (choice !== 'Yes') {
        return;
      }
    }

    const terminal = vscode.window.createTerminal('AI-DDTK: Wire Project');
    terminal.show();

    // Use the wire-project script from experimental folder
    const wireProjectScript = this.manager.getWireProjectScript();
    terminal.sendText(`bash "${wireProjectScript}" "${workspaceRoot}"`);
    terminal.sendText('echo "Wire project complete. Restart your editor to activate MCP."');
  }

  async runPreflight() {
    const aiDdtkPath = this.manager.getAiDdtkPath();
    const preflightScript = path.join(aiDdtkPath, 'preflight.sh');

    const terminal = vscode.window.createTerminal('AI-DDTK: Preflight');
    terminal.show();
    terminal.sendText(`bash "${preflightScript}"`);
  }

  async runWpcc() {
    const workspaceRoot = this.manager.getWorkspaceRoot();
    if (!workspaceRoot) {
      vscode.window.showErrorMessage('No workspace folder open');
      return;
    }

    const choice = await vscode.window.showQuickPick(
      ['Current file', 'Entire project', 'Custom path'],
      { placeHolder: 'What would you like to scan?' }
    );

    if (!choice) {
      return;
    }

    let scanPath = workspaceRoot;

    if (choice === 'Current file') {
      const editor = vscode.window.activeTextEditor;
      if (!editor) {
        vscode.window.showErrorMessage('No file open');
        return;
      }
      scanPath = editor.document.uri.fsPath;
    } else if (choice === 'Custom path') {
      const customPath = await vscode.window.showInputBox({
        prompt: 'Enter path to scan (relative to workspace)',
        value: '.',
      });
      if (!customPath) {
        return;
      }
      scanPath = path.join(workspaceRoot, customPath);
    }

    const terminal = vscode.window.createTerminal('AI-DDTK: WPCC Scan');
    terminal.show();
    terminal.sendText(`wpcc --paths "${scanPath}" --format json`);
  }

  async openDocs() {
    const choice = await vscode.window.showQuickPick(
      [
        'README',
        'AGENTS.md',
        'README-AI-DDTK.md',
        'GitHub Repository',
      ],
      { placeHolder: 'Which documentation would you like to open?' }
    );

    if (!choice) {
      return;
    }

    const aiDdtkPath = this.manager.getAiDdtkPath();

    switch (choice) {
      case 'README':
        await vscode.commands.executeCommand(
          'vscode.open',
          vscode.Uri.file(path.join(aiDdtkPath, 'README.md'))
        );
        break;
      case 'AGENTS.md':
        await vscode.commands.executeCommand(
          'vscode.open',
          vscode.Uri.file(path.join(aiDdtkPath, 'AGENTS.md'))
        );
        break;
      case 'README-AI-DDTK.md':
        await vscode.commands.executeCommand(
          'vscode.open',
          vscode.Uri.file(path.join(aiDdtkPath, 'README-AI-DDTK.md'))
        );
        break;
      case 'GitHub Repository':
        vscode.env.openExternal(
          vscode.Uri.parse('https://github.com/Hypercart-Dev-Tools/AI-DDTK')
        );
        break;
    }
  }

  async checkStatus() {
    const status = await this.manager.checkStatus();

    let message = '';
    if (!status.installed) {
      message = `❌ AI-DDTK not installed at ${status.path}\n\nRun: ~/bin/ai-ddtk/install.sh`;
    } else {
      message = `✅ AI-DDTK installed at ${status.path}\n\n`;
      message += `WPCC: ${status.wpccAvailable ? '✅' : '❌'}\n`;
      message += `WordPress Project: ${status.wordPressProject ? '✅' : '❌'}\n`;
      message += `MCP Configured: ${status.mcpConfigured ? '✅' : '❌'}`;
    }

    vscode.window.showInformationMessage(message, 'Open Docs', 'Close');
  }
}

