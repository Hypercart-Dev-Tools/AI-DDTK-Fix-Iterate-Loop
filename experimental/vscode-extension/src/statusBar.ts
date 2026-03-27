import * as vscode from 'vscode';
import { AiDdtkStatus } from './manager';

export class StatusBarManager implements vscode.Disposable {
  private statusBarItem: vscode.StatusBarItem;

  constructor() {
    this.statusBarItem = vscode.window.createStatusBarItem(
      vscode.StatusBarAlignment.Right,
      100
    );
    this.statusBarItem.command = 'ai-ddtk.checkStatus';
    this.statusBarItem.tooltip = 'Click to check AI-DDTK status';
  }

  show() {
    this.statusBarItem.show();
  }

  update(status: AiDdtkStatus) {
    if (!status.installed) {
      this.statusBarItem.text = '$(error) AI-DDTK';
      this.statusBarItem.backgroundColor = new vscode.ThemeColor(
        'statusBarItem.errorBackground'
      );
      this.statusBarItem.tooltip = 'AI-DDTK not installed. Click to learn more.';
      return;
    }

    if (status.wordPressProject) {
      if (status.mcpConfigured) {
        this.statusBarItem.text = '$(check) AI-DDTK Ready';
        this.statusBarItem.backgroundColor = undefined;
        this.statusBarItem.tooltip = 'AI-DDTK is configured for this project';
      } else {
        this.statusBarItem.text = '$(warning) AI-DDTK Setup';
        this.statusBarItem.backgroundColor = new vscode.ThemeColor(
          'statusBarItem.warningBackground'
        );
        this.statusBarItem.tooltip = 'WordPress project detected. Run "AI-DDTK: Wire Project" to set up.';
      }
    } else {
      this.statusBarItem.text = '$(info) AI-DDTK';
      this.statusBarItem.backgroundColor = undefined;
      this.statusBarItem.tooltip = 'AI-DDTK installed and ready';
    }
  }

  dispose() {
    this.statusBarItem.dispose();
  }
}

