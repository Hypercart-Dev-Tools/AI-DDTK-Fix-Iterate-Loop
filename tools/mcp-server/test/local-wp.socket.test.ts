import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, stat, writeFile } from "node:fs/promises";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createLocalWpHandlers } from "../src/handlers/local-wp.js";
import { SiteState } from "../src/state.js";
import { ExecFileTextError, type ExecResult } from "../src/utils/exec.js";

async function startUnixSocket(socketPath: string): Promise<net.Server> {
  const server = net.createServer();
  await new Promise<void>((resolve, reject) => {
    server.once("error", reject);
    server.listen(socketPath, () => resolve());
  });

  for (let attempt = 0; attempt < 20; attempt += 1) {
    try {
      if ((await stat(socketPath)).isSocket()) {
        break;
      }
    } catch {
      // Wait briefly for the socket file to materialize.
    }

    await new Promise((resolve) => setTimeout(resolve, 10));
  }

  return server;
}

async function createFixture(siteName = "demo") {
  const tempBase = process.platform === "darwin" ? "/tmp" : os.tmpdir();
  const root = await mkdtemp(path.join(tempBase, "amcp-"));
  const homeDir = path.join(root, "h");
  const repoRoot = path.join(root, "r");
  const sitePath = path.join(homeDir, "Local Sites", siteName, "app", "public");
  const runRoot = path.join(homeDir, "Library", "Application Support", "Local", "run");
  const liveRunRoot = path.join(runRoot, "s-live");
  const socketPath = path.join(liveRunRoot, "mysql", "mysqld.sock");

  await mkdir(sitePath, { recursive: true });
  await mkdir(path.join(liveRunRoot, "conf", "nginx"), { recursive: true });
  await mkdir(path.join(liveRunRoot, "mysql"), { recursive: true });
  await mkdir(path.join(repoRoot, "bin"), { recursive: true });
  await writeFile(path.join(sitePath, "wp-config.php"), "<?php\n");
  await writeFile(
    path.join(liveRunRoot, "conf", "nginx", "site.conf"),
    `server {\n    root "${sitePath}";\n    server_name ${siteName}.local *.${siteName}.local;\n}\n`,
  );
  await writeFile(path.join(repoRoot, "bin", "local-wp"), "#!/usr/bin/env bash\n");

  return {
    root,
    homeDir,
    repoRoot,
    siteName,
    sitePath,
    socketPath,
    async cleanup(server?: net.Server) {
      if (server) {
        await new Promise<void>((resolve) => server.close(() => resolve()));
      }
      await rm(root, { recursive: true, force: true });
    },
  };
}

test("select site prefers the active Local run when stale configs also match", async () => {
  const fixture = await createFixture();
  const staleRunRoot = path.join(
    fixture.homeDir,
    "Library",
    "Application Support",
    "Local",
    "run",
    "s-stale",
  );
  const socketServer = await startUnixSocket(fixture.socketPath);

  await mkdir(path.join(staleRunRoot, "conf", "nginx"), { recursive: true });
  await mkdir(path.join(staleRunRoot, "mysql"), { recursive: true });
  await writeFile(
    path.join(staleRunRoot, "conf", "nginx", "site.conf"),
    `server {\n    root "${fixture.sitePath}";\n    server_name ${fixture.siteName}.local;\n}\n`,
  );

  try {
    const handlers = createLocalWpHandlers({
      state: new SiteState(),
      homeDir: fixture.homeDir,
      repoRoot: fixture.repoRoot,
    });

    const selected = await handlers.selectSite(fixture.siteName);

    assert.equal(selected.site, fixture.siteName);
    assert.equal(selected.activeSite, fixture.siteName);
  } finally {
    await fixture.cleanup(socketServer);
  }
});

test("select site enables read-only active-site fallback for connectivity", async () => {
  const fixture = await createFixture();
  const socketServer = await startUnixSocket(fixture.socketPath);
  const calls: Array<{ file: string; args: string[] }> = [];

  try {
    const handlers = createLocalWpHandlers({
      state: new SiteState(),
      homeDir: fixture.homeDir,
      repoRoot: fixture.repoRoot,
      execRunner: async (file, args): Promise<ExecResult> => {
        calls.push({ file, args });
        return { stdout: "PHP version:\t8.2.12\n", stderr: "", exitCode: 0 };
      },
    });

    const selected = await handlers.selectSite(fixture.siteName);
    const connectivity = await handlers.testConnectivity();

    assert.equal(selected.site, fixture.siteName);
    assert.equal(connectivity.site, fixture.siteName);
    assert.equal(connectivity.status, "ok");
    assert.deepEqual(calls[0]?.args, [fixture.siteName, "cli", "info"]);
    assert.match(calls[0]?.file ?? "", /bin\/local-wp$/);
  } finally {
    await fixture.cleanup(socketServer);
  }
});

test("site info parsing returns wp version, active theme, plugins, and site url", async () => {
  const fixture = await createFixture();
  const socketServer = await startUnixSocket(fixture.socketPath);

  try {
    const handlers = createLocalWpHandlers({
      state: new SiteState(),
      homeDir: fixture.homeDir,
      repoRoot: fixture.repoRoot,
      execRunner: async (_file, args): Promise<ExecResult> => {
        const command = args.slice(1).join(" ");

        switch (command) {
          case "cli info":
            return { stdout: "PHP version:\t8.2.12\nWP-CLI version:\t2.10.0\n", stderr: "", exitCode: 0 };
          case "core version":
            return { stdout: "6.8.1\n", stderr: "", exitCode: 0 };
          case "theme list --format=json":
            return {
              stdout: JSON.stringify([
                { name: "twentytwentyfive", status: "inactive" },
                { name: "storefront", status: "active" },
              ]),
              stderr: "",
              exitCode: 0,
            };
          case "plugin list --format=json --fields=name,status,version":
            return {
              stdout: JSON.stringify([
                { name: "woocommerce", status: "active", version: "9.8.0" },
                { name: "query-monitor", status: "inactive", version: "3.16.0" },
              ]),
              stderr: "",
              exitCode: 0,
            };
          case "option get siteurl":
            return { stdout: "https://demo.local\n", stderr: "", exitCode: 0 };
          default:
            throw new Error(`Unexpected command: ${command}`);
        }
      },
    });

    const info = await handlers.getSiteInfo(fixture.siteName);

    assert.equal(info.site, fixture.siteName);
    assert.equal(info.wpVersion, "6.8.1");
    assert.equal(info.phpVersion, "8.2.12");
    assert.equal(info.activeTheme, "storefront");
    assert.equal(info.siteUrl, "https://demo.local");
    assert.equal(info.plugins.length, 2);
    assert.equal(info.plugins[0]?.name, "woocommerce");
  } finally {
    await fixture.cleanup(socketServer);
  }
});

test("local_wp_run returns wrapper output and exit code", async () => {
  const fixture = await createFixture();
  const socketServer = await startUnixSocket(fixture.socketPath);
  const calls: Array<string[]> = [];

  try {
    const handlers = createLocalWpHandlers({
      state: new SiteState(),
      homeDir: fixture.homeDir,
      repoRoot: fixture.repoRoot,
      execRunner: async (_file, args): Promise<ExecResult> => {
        calls.push(args);
        throw new ExecFileTextError("Command failed", "partial output", "fatal error", 42, false);
      },
    });

    const result = await handlers.runCommand(fixture.siteName, "plugin list", ["--status=active"]);

    assert.equal(result.site, fixture.siteName);
    assert.equal(result.command, "plugin list");
    assert.equal(result.exitCode, 42);
    assert.equal(result.stdout, "partial output");
    assert.equal(result.stderr, "fatal error");
    assert.deepEqual(calls[0], [fixture.siteName, "plugin", "list", "--status=active"]);
  } finally {
    await fixture.cleanup(socketServer);
  }
});
