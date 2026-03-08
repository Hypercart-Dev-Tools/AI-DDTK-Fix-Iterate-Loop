export interface ActiveSiteContext {
  name: string;
  path: string;
}

/**
 * In-memory site context for a single MCP server process.
 * Phase 1 uses this only as a convenience fallback for read-only tools.
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