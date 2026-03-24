import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createWpAjaxTestHandlers } from "../src/handlers/wp-ajax-test.js";
import { type ExecResult } from "../src/utils/exec.js";

async function createFixture() {
  const root = await mkdtemp(path.join(os.tmpdir(), "amcp-ajax-"));
  const repoRoot = path.join(root, "repo");

  await mkdir(path.join(repoRoot, "bin"), { recursive: true });
  await writeFile(path.join(repoRoot, "bin", "wp-ajax-test"), "#!/usr/bin/env node\n");

  return {
    repoRoot,
    async cleanup() {
      await rm(root, { recursive: true, force: true });
    },
  };
}

test("wp_ajax_test parses successful JSON output", async () => {
  const fixture = await createFixture();

  try {
    const handlers = createWpAjaxTestHandlers({
      repoRoot: fixture.repoRoot,
      execRunner: async (_file, args): Promise<ExecResult> => {
        assert.deepEqual(args, [
          "--url",
          "http://demo.local",
          "--action",
          "demo_action",
          "--data",
          '{"postId":42}',
          "--format",
          "json",
          "--method",
          "POST",
          "--auth",
          "temp/auth.json",
          "--nopriv",
          "--insecure",
        ]);

        return {
          stdout: JSON.stringify({
            success: true,
            action: "demo_action",
            url: "http://demo.local/wp-admin/admin-ajax.php",
            status_code: 200,
            response_time_ms: 52,
            response: { ok: true },
            headers: { "content-type": "application/json" },
          }),
          stderr: "",
          exitCode: 0,
        };
      },
    });

    const result = await handlers.runTest("http://demo.local", "demo_action", { postId: 42 }, "temp/auth.json", "POST", true, true);

    assert.equal(result.success, true);
    assert.equal(result.statusCode, 200);
    assert.equal(result.responseTimeMs, 52);
    assert.deepEqual(result.response, { ok: true });
    assert.deepEqual(result.headers, { "content-type": "application/json" });
    assert.equal(result.authProvided, true);
  } finally {
    await fixture.cleanup();
  }
});

test("wp_ajax_test parses CLI JSON errors from stderr and preserves exit codes", async () => {
  const fixture = await createFixture();

  try {
    const handlers = createWpAjaxTestHandlers({
      repoRoot: fixture.repoRoot,
      execRunner: async (): Promise<ExecResult> => ({
        stdout: "",
        stderr: JSON.stringify({
          success: false,
          error: { code: "AUTH_REQUIRED", message: "Auth file not found" },
          suggestions: ["Create temp/auth.json"],
        }),
        exitCode: 1,
      }),
    });

    const result = await handlers.runTest("http://demo.local", "demo_action");

    assert.equal(result.success, false);
    assert.equal(result.exitCode, 1);
    assert.deepEqual(result.error, { code: "AUTH_REQUIRED", message: "Auth file not found" });
    assert.deepEqual(result.suggestions, ["Create temp/auth.json"]);
  } finally {
    await fixture.cleanup();
  }
});

test("wp_ajax_test rejects flag-shaped auth file input before execution", async () => {
  const fixture = await createFixture();
  let invoked = false;

  try {
    const handlers = createWpAjaxTestHandlers({
      repoRoot: fixture.repoRoot,
      execRunner: async (): Promise<ExecResult> => {
        invoked = true;
        return { stdout: "", stderr: "", exitCode: 0 };
      },
    });

    await assert.rejects(() => handlers.runTest("http://demo.local", "demo_action", {}, "--verbose"), /must not start with '-'/);
    assert.equal(invoked, false);
  } finally {
    await fixture.cleanup();
  }
});

test("wp_ajax_test rejects non-http URLs before execution", async () => {
  const fixture = await createFixture();
  let invoked = false;

  try {
    const handlers = createWpAjaxTestHandlers({
      repoRoot: fixture.repoRoot,
      execRunner: async (): Promise<ExecResult> => {
        invoked = true;
        return { stdout: "", stderr: "", exitCode: 0 };
      },
    });

    await assert.rejects(() => handlers.runTest("file:///tmp/demo", "demo_action"), /only allows http:\/\/ or https:\/\//);
    assert.equal(invoked, false);
  } finally {
    await fixture.cleanup();
  }
});

test("wp_ajax_test prefers --auth-state over --auth when both are provided", async () => {
  const fixture = await createFixture();

  try {
    const handlers = createWpAjaxTestHandlers({
      repoRoot: fixture.repoRoot,
      execRunner: async (_file, args): Promise<ExecResult> => {
        // Should pass --auth-state, not --auth
        assert.ok(args.includes("--auth-state"), "Expected --auth-state in args");
        assert.ok(!args.includes("--auth"), "Should not include --auth when --auth-state is provided");
        assert.ok(args.includes("temp/playwright/.auth/admin.json"), "Expected auth state path in args");

        return {
          stdout: JSON.stringify({
            success: true,
            action: "demo_action",
            url: "http://demo.local/wp-admin/admin-ajax.php",
            status_code: 200,
            response_time_ms: 30,
            response: { ok: true },
            headers: {},
          }),
          stderr: "",
          exitCode: 0,
        };
      },
    });

    const result = await handlers.runTest(
      "http://demo.local",
      "demo_action",
      {},
      "temp/auth.json", // legacy auth — should be ignored
      "POST",
      false,
      false,
      "temp/playwright/.auth/admin.json", // auth-state — should win
    );

    assert.equal(result.success, true);
    assert.equal(result.authProvided, true);
  } finally {
    await fixture.cleanup();
  }
});

test("wp_ajax_test rejects flag-shaped auth-state path", async () => {
  const fixture = await createFixture();
  let invoked = false;

  try {
    const handlers = createWpAjaxTestHandlers({
      repoRoot: fixture.repoRoot,
      execRunner: async (): Promise<ExecResult> => {
        invoked = true;
        return { stdout: "", stderr: "", exitCode: 0 };
      },
    });

    await assert.rejects(
      () => handlers.runTest("http://demo.local", "demo_action", {}, undefined, "POST", false, false, "--verbose"),
      /must not start with '-'/,
    );
    assert.equal(invoked, false);
  } finally {
    await fixture.cleanup();
  }
});

test("wp_ajax_test throws when exit 0 stdout is not valid JSON", async () => {
  const fixture = await createFixture();

  try {
    const handlers = createWpAjaxTestHandlers({
      repoRoot: fixture.repoRoot,
      execRunner: async (): Promise<ExecResult> => ({
        stdout: "not-json",
        stderr: "",
        exitCode: 0,
      }),
    });

    await assert.rejects(() => handlers.runTest("http://demo.local", "demo_action"), /expected JSON output/);
  } finally {
    await fixture.cleanup();
  }
});