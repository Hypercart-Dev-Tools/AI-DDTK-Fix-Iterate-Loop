import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createServersHandlers } from "../src/handlers/servers.js";

test("servers handlers use canonical JSON data and sync generated markdown", async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), "servers-registry-"));

  try {
    const repoRoot = path.join(root, "repo");
    const toolsDir = path.join(repoRoot, "tools");
    const registryDataPath = path.join(toolsDir, "servers.registry.json");
    const markdownPath = path.join(toolsDir, "servers.md");
    await mkdir(toolsDir, { recursive: true });

    await writeFile(
      registryDataPath,
      JSON.stringify({
        version: 1,
        mutexEntries: [
          { port: 80, service: "Local WP + Valet", owner: "Shared", hostname: "*.local/*.test", notes: "mutex" },
        ],
        entries: [
          { port: 3306, service: "MySQL", owner: "Homebrew", hostname: "localhost", notes: "db" },
        ],
        ranges: [],
      }, null, 2),
    );
    await writeFile(
      markdownPath,
      [
        "# Servers",
        "",
        "<!-- GENERATED:PORT_REGISTRY:START -->",
        "placeholder",
        "<!-- GENERATED:PORT_REGISTRY:END -->",
        "",
      ].join("\n"),
    );

    const handlers = createServersHandlers({ repoRoot, registryDataPath, markdownPath });

    const before = await handlers.checkPort(3306);
    const mutex = await handlers.checkPort(80);
    const add = await handlers.addEntry({
      port: 8741,
      service: "Dify nginx",
      owner: "Docker",
      hostname: "dify.test",
      notes: "proxy target",
    });
    const after = await handlers.listRegistry();

    assert.equal(before.status, "allocated");
    assert.equal(mutex.status, "mutex");
    assert.equal(add.added, true);
    assert.deepEqual(after.allocatedPorts, [3306, 8741]);

    const rawRegistry = JSON.parse(await readFile(registryDataPath, "utf8")) as {
      entries: Array<{ port: number }>;
    };
    assert.deepEqual(rawRegistry.entries.map((entry) => entry.port), [3306, 8741]);

    const markdown = await readFile(markdownPath, "utf8");
    assert.match(markdown, /\| 8741 \| Dify nginx \| Docker \| dify\.test \| proxy target \|/);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
