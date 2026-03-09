export interface ActiveSiteContext {
  name: string;
  path: string;
}

/**
 * In-memory site context for a single MCP server process.
 * Used as a convenience fallback for read-only tools.
 */
export class SiteState {
  private activeSite: ActiveSiteContext | null = null;

  setActiveSite(site: ActiveSiteContext): ActiveSiteContext {
    this.activeSite = { ...site };
    return this.getActiveSite() as ActiveSiteContext;
  }

  getActiveSite(): ActiveSiteContext | null {
    return this.activeSite ? { ...this.activeSite } : null;
  }

  clearActiveSite(): void {
    this.activeSite = null;
  }
}

/**
 * Per-session site state store for HTTP/SSE transport.
 * Each client session gets its own isolated SiteState so
 * active-site context is never shared across clients.
 */
export class SessionStore {
  private sessions = new Map<string, SiteState>();

  getOrCreate(sessionId: string): SiteState {
    let state = this.sessions.get(sessionId);

    if (!state) {
      state = new SiteState();
      this.sessions.set(sessionId, state);
    }

    return state;
  }

  remove(sessionId: string): boolean {
    return this.sessions.delete(sessionId);
  }

  has(sessionId: string): boolean {
    return this.sessions.has(sessionId);
  }

  get size(): number {
    return this.sessions.size;
  }
}