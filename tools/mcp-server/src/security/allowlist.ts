import path from "node:path";

export interface AllowlistDecision {
  allowed: boolean;
  normalizedCommand: string[];
  reason?: string;
}

const TMUX_ALLOWED_COMMANDS = new Set(["wpcc"]);

const TMUX_ALLOWED_BIN_COMMANDS = new Set(["wpcc"]);

const TMUX_BLOCKED_COMMANDS = new Set(["rm", "sudo", "curl", "wget", "eval", "sh", "bash", "node", "python", "pip", "npm"]);

const TMUX_BLOCKED_OPERATOR_PATTERN = /&&|\|\||;|\||>|<|`|\$\(|\$\{|\r|\n/;

const ALLOWED_PREFIXES = [
  ["cli", "info"],
  ["core", "version"],
  ["plugin", "list"],
  ["theme", "list"],
  ["option", "get"],
  ["post", "list"],
  ["user", "list"],
  ["db", "query"],
  ["cache", "flush"],
  ["cron", "event", "list"],
  ["rewrite", "flush"],
  ["transient", "list"],
] as const;

const BLOCKED_PREFIXES = [
  ["eval"],
  ["eval-file"],
  ["shell"],
  ["db", "export"],
  ["db", "import"],
  ["db", "reset"],
  ["db", "drop"],
  ["config", "set"],
  ["config", "delete"],
  ["core", "update"],
  ["plugin", "install"],
  ["plugin", "delete"],
  ["theme", "install"],
  ["theme", "delete"],
  ["user", "create"],
  ["user", "delete"],
  ["package", "install"],
] as const;

const COMMAND_TOKEN_PATTERN = /^[A-Za-z0-9:_-]+$/;

function matchesPrefix(command: string[], prefix: readonly string[]): boolean {
  if (command.length < prefix.length) {
    return false;
  }

  return prefix.every((part, index) => command[index] === part);
}

function firstNonFlagArg(args: string[]): string | undefined {
  return args.find((arg) => !arg.startsWith("-"));
}

function isAllowedSelectQuery(sql: string): boolean {
  const normalizedSql = sql.trim();

  return normalizedSql.length > 0 && /^select\b/i.test(normalizedSql) && !normalizedSql.includes(";");
}

export function splitWpCliCommand(command: string): string[] {
  const normalized = command.trim();

  if (!normalized) {
    throw new Error("WP-CLI command is required.");
  }

  const parts = normalized.split(/\s+/);

  for (const part of parts) {
    if (!COMMAND_TOKEN_PATTERN.test(part)) {
      throw new Error(
        `Invalid WP-CLI command token \"${part}\". Pass subcommands only in command and use args for values.`,
      );
    }
  }

  return parts.map((part) => part.toLowerCase());
}

export function getWpCliAllowlistDecision(command: string | string[], args: string[] = []): AllowlistDecision {
  const normalizedCommand = Array.isArray(command)
    ? command.map((part) => part.toLowerCase())
    : splitWpCliCommand(command);

  for (const blockedPrefix of BLOCKED_PREFIXES) {
    if (matchesPrefix(normalizedCommand, blockedPrefix)) {
      return {
        allowed: false,
        normalizedCommand,
        reason: `Blocked WP-CLI command: ${blockedPrefix.join(" ")}`,
      };
    }
  }

  const isAllowed = ALLOWED_PREFIXES.some((allowedPrefix) => matchesPrefix(normalizedCommand, allowedPrefix));

  if (!isAllowed) {
    return {
      allowed: false,
      normalizedCommand,
      reason: `WP-CLI command is not on the Phase 1 allowlist: ${normalizedCommand.join(" ")}`,
    };
  }

  if (normalizedCommand[0] === "db" && normalizedCommand[1] === "query") {
    const sql = firstNonFlagArg(args);

    if (!sql || !isAllowedSelectQuery(sql)) {
      return {
        allowed: false,
        normalizedCommand,
        reason: "Blocked WP-CLI command: db query only allows single SELECT statements without semicolons in Phase 1.",
      };
    }
  }

  return {
    allowed: true,
    normalizedCommand,
  };
}

export function assertAllowedWpCliCommand(command: string | string[], args: string[] = []): string[] {
  const decision = getWpCliAllowlistDecision(command, args);

  if (!decision.allowed) {
    throw new Error(decision.reason);
  }

  return decision.normalizedCommand;
}

function normalizeTmuxBaseCommand(command: string): string {
  if (TMUX_ALLOWED_COMMANDS.has(command)) {
    return command;
  }

  const binMatch = command.match(/^(?:\.\/)?bin\/(wpcc)$/);

  if (binMatch?.[1] && TMUX_ALLOWED_BIN_COMMANDS.has(binMatch[1])) {
    return binMatch[1];
  }

  return command;
}

function isRepoRelativePath(repoRoot: string, candidate: string): boolean {
  const normalized = candidate.trim();

  if (!normalized || normalized.startsWith("-") || path.isAbsolute(normalized)) {
    return false;
  }

  const resolvedPath = path.resolve(repoRoot, normalized);
  const relativePath = path.relative(repoRoot, resolvedPath);

  return relativePath === "" || (!relativePath.startsWith("..") && !path.isAbsolute(relativePath));
}

function validateTmuxWpccCommand(tokens: string[], repoRoot: string): string | null {
  if (tokens.length === 2 && (tokens[1] === "--features" || tokens[1] === "--help")) {
    return null;
  }

  let pathsValue: string | undefined;

  for (let index = 1; index < tokens.length; index += 1) {
    const token = tokens[index];

    switch (token) {
      case "--paths": {
        const nextValue = tokens[index + 1];

        if (!nextValue) {
          return "tmux_send wpcc commands require a value after --paths.";
        }

        pathsValue = nextValue;
        index += 1;
        break;
      }
      case "--format": {
        const nextValue = tokens[index + 1];

        if (nextValue !== "json" && nextValue !== "text") {
          return "tmux_send wpcc --format only allows json or text.";
        }

        index += 1;
        break;
      }
      case "--verbose":
        break;
      default:
        return "tmux_send only allows validated wpcc invocations (--features or --paths <repo-relative paths> with optional --format/--verbose).";
    }
  }

  if (!pathsValue) {
    return "tmux_send only allows wpcc --features or wpcc --paths <repo-relative paths>.";
  }

  const pathEntries = pathsValue.split(",").map((entry) => entry.trim()).filter(Boolean);

  if (pathEntries.length === 0 || pathEntries.some((entry) => !isRepoRelativePath(repoRoot, entry))) {
    return "tmux_send wpcc --paths only allows repo-relative workspace paths.";
  }

  return null;
}

export function getTmuxCommandAllowlistDecision(command: string, repoRoot: string): AllowlistDecision {
  const normalized = command.trim();

  if (!normalized) {
    return {
      allowed: false,
      normalizedCommand: [],
      reason: "tmux_send requires a command.",
    };
  }

  if (TMUX_BLOCKED_OPERATOR_PATTERN.test(normalized)) {
    return {
      allowed: false,
      normalizedCommand: [],
      reason: "tmux_send rejects shell control operators and multi-command input.",
    };
  }

  const tokens = normalized.split(/\s+/).filter(Boolean);
  const firstToken = tokens[0] ?? "";
  const normalizedBaseCommand = normalizeTmuxBaseCommand(firstToken);
  const normalizedTokens = [normalizedBaseCommand, ...tokens.slice(1)];

  if (TMUX_BLOCKED_COMMANDS.has(normalizedBaseCommand)) {
    return {
      allowed: false,
      normalizedCommand: normalizedTokens,
      reason: `Blocked tmux command: ${normalizedBaseCommand}`,
    };
  }

  if (!TMUX_ALLOWED_COMMANDS.has(normalizedBaseCommand)) {
    return {
      allowed: false,
      normalizedCommand: normalizedTokens,
      reason: `tmux_send command is not on the Phase 4 allowlist: ${firstToken}`,
    };
  }

  if (normalizedBaseCommand === "wpcc") {
    const wpccValidationError = validateTmuxWpccCommand(normalizedTokens, repoRoot);

    if (wpccValidationError) {
      return {
        allowed: false,
        normalizedCommand: normalizedTokens,
        reason: wpccValidationError,
      };
    }
  }

  return {
    allowed: true,
    normalizedCommand: normalizedTokens,
  };
}

export function assertAllowedTmuxCommand(command: string, repoRoot: string): string[] {
  const decision = getTmuxCommandAllowlistDecision(command, repoRoot);

  if (!decision.allowed) {
    throw new Error(decision.reason);
  }

  return decision.normalizedCommand;
}