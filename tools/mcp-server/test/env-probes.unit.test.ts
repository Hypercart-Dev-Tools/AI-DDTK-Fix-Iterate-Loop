import assert from "node:assert/strict";
import { chmod, mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createEnvProbesHandlers } from "../src/handlers/env-probes.js";

async function createExecutableScript(root: string, name: string): Promise<string> {
  const scriptPath = path.join(root, name);
  await writeFile(scriptPath, "#!/usr/bin/env bash\n");
  await chmod(scriptPath, 0o755);
  return scriptPath;
}

test("env probes validate JSON shape from external scripts", async () => {
  const root = await mkdtemp(path.join(os.tmpdir(), "env-probes-"));

  try {
    const repoRoot = path.join(root, "repo");
    await mkdir(repoRoot, { recursive: true });
    const monitorScriptPath = await createExecutableScript(root, "servers-monitor.sh");
    const devContextScriptPath = await createExecutableScript(root, "dev-context.sh");

    const handlers = createEnvProbesHandlers({
      repoRoot,
      monitorScriptPath,
      devContextScriptPath,
      exec: async (file) => {
        if (file === monitorScriptPath) {
          return { stdout: JSON.stringify({ status: "ok", counts: { critical: 0 } }), stderr: "", exitCode: 0 };
        }

        return { stdout: JSON.stringify({ mode: "valet", services: { valet_nginx: true } }), stderr: "", exitCode: 0 };
      },
    });

    const monitor = await handlers.monitorCheck();
    const devContext = await handlers.devContextStatus();

    assert.equal(monitor.status, "error");
    assert.match(monitor.message ?? "", /unexpected JSON shape/i);
    assert.equal(devContext.mode, "none");
    assert.match(devContext.message ?? "", /unexpected JSON shape/i);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});
