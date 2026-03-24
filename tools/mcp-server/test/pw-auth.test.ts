import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, rm, stat, utimes, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { AUTH_STATUS_URI_TEMPLATE, createPwAuthHandlers } from "../src/handlers/pw-auth.js";
import { ExecFileTextError, type ExecResult } from "../src/utils/exec.js";

async function createPwAuthFixture() {
  const root = await mkdtemp(path.join(os.tmpdir(), "amcp-pwauth-"));
  const repoRoot = path.join(root, "repo");
  const workingDir = path.join(root, "workspace");
  const authDir = path.join(workingDir, "temp", "playwright", ".auth");

  await mkdir(path.join(repoRoot, "bin"), { recursive: true });
  await mkdir(authDir, { recursive: true });
  await writeFile(path.join(repoRoot, "bin", "pw-auth"), "#!/usr/bin/env bash\n");

  return {
    root,
    repoRoot,
    workingDir,
    authDir,
    async cleanup() {
      await rm(root, { recursive: true, force: true });
    },
  };
}

test("pw_auth_login builds the internal local-wp prefix and retries once on timeout", async () => {
  const fixture = await createPwAuthFixture();
  const calls: Array<{ file: string; args: string[]; cwd?: string }> = [];
  const fixedNow = Date.parse("2026-03-09T12:00:00.000Z");
  const authFilePath = path.join(fixture.authDir, "editor.json");

  try {
    const handlers = createPwAuthHandlers({
      repoRoot: fixture.repoRoot,
      workingDir: fixture.workingDir,
      now: () => fixedNow,
      execRunner: async (file, args, options): Promise<ExecResult> => {
        calls.push({ file, args, cwd: options?.cwd });

        if (calls.length === 1) {
          throw new ExecFileTextError("Command timed out", "", "timeout", 124, true);
        }

        await writeFile(authFilePath, JSON.stringify({ cookies: [] }));
        await utimes(authFilePath, fixedNow / 1000, fixedNow / 1000);

        return {
          stdout: "[pw-auth] Done. Use in Playwright scripts:\n[pw-auth]   storageState: 'temp/playwright/.auth/editor.json'\n",
          stderr: "",
          exitCode: 0,
        };
      },
    });

    const result = await handlers.login(
      "http://demo.local",
      "Demo Site's Test",
      "editor",
      "/wp-admin/site-editor.php",
      true,
    );

    assert.equal(calls.length, 2);
    assert.match(calls[0]?.file ?? "", /bin\/pw-auth$/);
    assert.equal(calls[0]?.cwd, fixture.workingDir);
    assert.deepEqual(calls[0]?.args, [
      "login",
      "--site-url",
      "http://demo.local",
      "--wp-cli",
      "local-wp 'Demo Site'\\''s Test'",
      "--user",
      "editor",
      "--redirect",
      "/wp-admin/site-editor.php",
      "--force",
    ]);
    assert.equal(result.site, "Demo Site's Test");
    assert.equal(result.user, "editor");
    assert.equal(result.authFile, "temp/playwright/.auth/editor.json");
    assert.equal(result.exitCode, 0);
    assert.equal(result.retried, true);
    assert.equal(result.cacheFreshUntil, "2026-03-10T00:00:00.000Z");
  } finally {
    await fixture.cleanup();
  }
});

test("pw_auth_status returns metadata-only auth cache details", async () => {
  const fixture = await createPwAuthFixture();
  const fixedNow = Date.parse("2026-03-09T12:00:00.000Z");
  const freshFile = path.join(fixture.authDir, "admin.json");
  const staleFile = path.join(fixture.authDir, "editor.json");

  try {
    await writeFile(freshFile, JSON.stringify({ cookies: [1] }));
    await writeFile(staleFile, JSON.stringify({ cookies: [1, 2] }));
    await utimes(freshFile, (fixedNow - 30 * 60_000) / 1000, (fixedNow - 30 * 60_000) / 1000);
    await utimes(staleFile, (fixedNow - 13 * 3_600_000) / 1000, (fixedNow - 13 * 3_600_000) / 1000);

    const handlers = createPwAuthHandlers({
      repoRoot: fixture.repoRoot,
      workingDir: fixture.workingDir,
      now: () => fixedNow,
      execRunner: async (_file, args, options): Promise<ExecResult> => {
        assert.deepEqual(args, ["status"]);
        assert.equal(options?.cwd, fixture.workingDir);
        return {
          stdout:
            `  User: admin\n  File: ${freshFile}\n  Age:  0h\n  Size: 13 bytes\n  Status: FRESH (< 12h; live validation happens on login)\n\n` +
            `  User: editor\n  File: ${staleFile}\n  Age:  13h\n  Size: 16 bytes\n  Status: STALE (>= 12h, will re-auth on next login)\n\n`,
          stderr: "",
          exitCode: 0,
        };
      },
    });

    const result = await handlers.status();

    assert.equal(result.exitCode, 0);
    assert.equal(result.authDir, "temp/playwright/.auth");
    assert.equal(result.users.length, 2);
    assert.equal(result.users[0]?.user, "admin");
    assert.equal(result.users[0]?.validationStatus, "fresh");
    assert.equal(result.users[0]?.fresh, true);
    assert.equal(result.users[1]?.user, "editor");
    assert.equal(result.users[1]?.validationStatus, "stale");
    assert.equal(result.users[1]?.ageHours, 13);
    assert.match(result.rawText, /User: admin/);
  } finally {
    await fixture.cleanup();
  }
});

test("pw_auth_clear only deletes the explicit user's auth file", async () => {
  const fixture = await createPwAuthFixture();
  const adminFile = path.join(fixture.authDir, "admin.json");
  const editorFile = path.join(fixture.authDir, "editor.json");

  try {
    await writeFile(adminFile, JSON.stringify({ admin: true }));
    await writeFile(editorFile, JSON.stringify({ editor: true }));

    const handlers = createPwAuthHandlers({ repoRoot: fixture.repoRoot, workingDir: fixture.workingDir });
    const result = await handlers.clear("editor");

    assert.equal(result.user, "editor");
    assert.equal(result.filePath, "temp/playwright/.auth/editor.json");
    assert.equal(result.existed, true);
    assert.equal(result.cleared, true);
    assert.equal((await stat(adminFile)).isFile(), true);
    await assert.rejects(() => stat(editorFile));
  } finally {
    await fixture.cleanup();
  }
});

test("pw-auth auth status resources list users and return metadata without exposing file contents", async () => {
  const fixture = await createPwAuthFixture();
  const fixedNow = Date.parse("2026-03-09T12:00:00.000Z");
  const adminFile = path.join(fixture.authDir, "admin.json");

  try {
    await writeFile(adminFile, JSON.stringify({ cookies: [{ value: "secret" }] }));
    await utimes(adminFile, (fixedNow - 60_000) / 1000, (fixedNow - 60_000) / 1000);

    const handlers = createPwAuthHandlers({
      repoRoot: fixture.repoRoot,
      workingDir: fixture.workingDir,
      now: () => fixedNow,
    });

    const resources = await handlers.listStatusResources();
    const existingResource = await handlers.readStatusResource("admin");
    const missingResource = await handlers.readStatusResource("missing.user");

    assert.equal(AUTH_STATUS_URI_TEMPLATE, "auth://status/{user}");
    assert.equal(resources.length, 1);
    assert.equal(resources[0]?.uri, "auth://status/admin");
    assert.match(resources[0]?.description ?? "", /admin/);

    const existingPayload = JSON.parse(existingResource.contents[0]?.text ?? "{}");
    const missingPayload = JSON.parse(missingResource.contents[0]?.text ?? "{}");

    assert.equal(existingPayload.user, "admin");
    assert.equal(existingPayload.exists, true);
    assert.equal(existingPayload.filePath, "temp/playwright/.auth/admin.json");
    assert.equal(existingPayload.validationStatus, "fresh");
    assert.equal(existingPayload.cookies, undefined);
    assert.equal(existingResource.contents[0]?.uri, "auth://status/admin");

    assert.equal(missingPayload.user, "missing.user");
    assert.equal(missingPayload.exists, false);
    assert.equal(missingPayload.filePath, null);
    assert.equal(missingPayload.validationStatus, "missing");

    const rawFileText = await readFile(adminFile, "utf8");
    assert.match(rawFileText, /secret/);
    assert.doesNotMatch(existingResource.contents[0]?.text ?? "", /secret/);
  } finally {
    await fixture.cleanup();
  }
});