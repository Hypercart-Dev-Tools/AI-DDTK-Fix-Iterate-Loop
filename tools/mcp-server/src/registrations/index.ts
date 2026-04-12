import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { createEnvProbesHandlers } from "../handlers/env-probes.js";
import { createLocalWpHandlers } from "../handlers/local-wp.js";
import { createPostFlightHandlers } from "../handlers/post-flight.js";
import { createPwAuthHandlers } from "../handlers/pw-auth.js";
import { createQmHandlers } from "../handlers/qm.js";
import { createServersHandlers } from "../handlers/servers.js";
import { createTmuxHandlers } from "../handlers/tmux.js";
import { createWpAjaxTestHandlers } from "../handlers/wp-ajax-test.js";
import { createWpccHandlers } from "../handlers/wpcc.js";
import { SiteState } from "../state.js";
import { registerEnvProbeTools } from "./env-probes.js";
import { registerLocalWpTools } from "./local-wp.js";
import { registerPostFlightTools } from "./post-flight.js";
import { registerPrompts } from "./prompts.js";
import { registerPwAuthTools } from "./pw-auth.js";
import { registerQmTools } from "./qm.js";
import { registerServersTools } from "./servers.js";
import { registerTmuxTools } from "./tmux.js";
import { registerWpAjaxTestTools } from "./wp-ajax-test.js";
import { registerWpccTools } from "./wpcc.js";

export interface RegisterAllToolsDeps {
  repoRoot: string;
  state?: SiteState;
}

export function registerAllTools(server: McpServer, deps: RegisterAllToolsDeps): void {
  const { repoRoot } = deps;
  const state = deps.state ?? new SiteState();

  const pwAuthHandlers = createPwAuthHandlers({ repoRoot });

  registerLocalWpTools(server, createLocalWpHandlers({ state, repoRoot }));
  registerPwAuthTools(server, pwAuthHandlers);
  registerWpAjaxTestTools(server, createWpAjaxTestHandlers({ repoRoot }));
  registerTmuxTools(server, createTmuxHandlers({ repoRoot }));
  registerWpccTools(server, createWpccHandlers({ repoRoot }));
  registerQmTools(
    server,
    createQmHandlers({
      getCookiesForSite: (user, domain) => pwAuthHandlers.getCookiesForSite(user, domain),
      repoRoot,
    }),
  );
  registerPostFlightTools(server, createPostFlightHandlers({ repoRoot }));
  registerServersTools(server, createServersHandlers({ repoRoot }));
  registerEnvProbeTools(server, createEnvProbesHandlers({ repoRoot }));
  registerPrompts(server);
}
