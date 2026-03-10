import { mkdir, readFile, writeFile } from "node:fs/promises";
import { randomBytes } from "node:crypto";
import path from "node:path";
import os from "node:os";

const TOKEN_DIR = path.join(os.homedir(), ".ai-ddtk");
const TOKEN_FILE = path.join(TOKEN_DIR, "mcp-token");

/**
 * Load or generate the bearer token for HTTP/SSE transport auth.
 * Token is stored in ~/.ai-ddtk/mcp-token and generated once on first run.
 */
export async function loadOrGenerateToken(): Promise<string> {
  try {
    const existing = (await readFile(TOKEN_FILE, "utf-8")).trim();

    if (existing.length >= 32) {
      return existing;
    }
  } catch {
    // File does not exist yet — generate below.
  }

  const token = randomBytes(32).toString("hex");
  await mkdir(TOKEN_DIR, { recursive: true, mode: 0o700 });
  await writeFile(TOKEN_FILE, token + "\n", { mode: 0o600 });

  return token;
}

export function getTokenFilePath(): string {
  return TOKEN_FILE;
}
