export interface AllowlistDecision {
  allowed: boolean;
  normalizedCommand: string[];
  reason?: string;
}

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

    if (!sql || !/^\s*select\b/i.test(sql)) {
      return {
        allowed: false,
        normalizedCommand,
        reason: "Blocked WP-CLI command: db query only allows SELECT statements in Phase 1.",
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