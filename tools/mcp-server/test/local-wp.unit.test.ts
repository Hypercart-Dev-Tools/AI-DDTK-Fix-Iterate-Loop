import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createLocalWpHandlers } from "../src/handlers/local-wp.js";
import { getWpCliAllowlistDecision } from "../src/security/allowlist.js";
import { SiteState } from "../src/state.js";
import { type ExecResult } from "../src/utils/exec.js";

async function createFixture(siteName = "demo") {
  const tempBase = process.platform === "darwin" ? "/tmp" : os.tmpdir();
  const root = await mkdtemp(path.join(tempBase, "amcp-"));
  const homeDir = path.join(root, "h");
  const repoRoot = path.join(root, "r");
  const sitePath = path.join(homeDir, "Local Sites", siteName, "app", "public");

  await mkdir(sitePath, { recursive: true });
  await mkdir(path.join(repoRoot, "bin"), { recursive: true });
  await writeFile(path.join(sitePath, "wp-config.php"), "<?php\n");
  await writeFile(path.join(repoRoot, "bin", "local-wp"), "#!/usr/bin/env bash\n");

  return {
    root,
    homeDir,
    repoRoot,
    siteName,
    async cleanup() {
      await rm(root, { recursive: true, force: true });
    },
  };
}

test("allowlist accepts safe commands and blocks dangerous ones", async () => {
  assert.equal(getWpCliAllowlistDecision("plugin list").allowed, true);
  assert.equal(getWpCliAllowlistDecision("eval").allowed, false);
  assert.equal(getWpCliAllowlistDecision("db drop").allowed, false);
  assert.equal(getWpCliAllowlistDecision("db query", ["SELECT * FROM wp_options LIMIT 1"]).allowed, true);
  assert.equal(getWpCliAllowlistDecision("db query", ["SELECT 1; DROP TABLE wp_posts"]).allowed, false);
  assert.equal(getWpCliAllowlistDecision("db query", ["DELETE FROM wp_options"]).allowed, false);
});

test("local_wp_run requires explicit site and rejects blocked commands before execution", async () => {
  const fixture = await createFixture();
  let invoked = false;

  try {
    const handlers = createLocalWpHandlers({
      state: new SiteState(),
      homeDir: fixture.homeDir,
      repoRoot: fixture.repoRoot,
      execRunner: async (): Promise<ExecResult> => {
        invoked = true;
        return { stdout: "", stderr: "", exitCode: 0 };
      },
    });

    await assert.rejects(() => handlers.runCommand("", "plugin list"), /explicit site/i);
    assert.equal(invoked, false);
  } finally {
    await fixture.cleanup();
  }
});
