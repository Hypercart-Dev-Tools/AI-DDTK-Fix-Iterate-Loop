# ask_self Roadmap

## Near-Term Candidate: Central RAG Web App

### Timing

This is a reasonable roadmap item for roughly 7 to 10 days out, provided the
goal is a narrow internal v1 and not a full platform rewrite.

The timing makes sense if the first version focuses on:

- registry of indexed repos and corpora
- ingest status and corpus metadata
- single-target and multi-target `/ask` queries
- basic auth, request logging, and health checks
- minimal admin UI for repo registration and diagnostics

This does **not** make sense as a 7 to 10 day item if v1 also tries to include:

- full multi-tenant billing/permissions
- live background indexing across many machines
- advanced review workflows
- central write-back into source repos
- production-grade HA/disaster recovery from day one

## Proposed v1 Shape

### Architecture

Keep `ask_self` as the ingestion/query engine for repo corpora.

Add a separate central web app repo that acts as:

- registry manager
- API layer
- auth/session layer
- orchestration layer for querying one or many corpora
- optional lightweight UI

Recommended split:

- `ask_self` remains the corpus builder and local RAG runtime
- central web app hosts the unified responder and registry
- corpus databases are treated as artifacts produced elsewhere and uploaded/synced

### Initial Storage Model

For v1, it is technically acceptable to push per-repo `sqlite-vec` databases to
a GCP GCE instance and serve them centrally behind a REST API.

This works because the current ask_self model is already:

- one repo or corpus target
- one sqlite DB
- one harness/config
- one registry entry

The central server can:

- maintain a registry of uploaded corpora
- open one DB for single-target queries
- open multiple DBs for federated nearest-neighbor retrieval
- merge hits globally and synthesize one answer

### Why This Is Good Enough For v1

- simplest deployment path
- no new vector infrastructure required immediately
- easy to inspect/debug artifacts
- low migration cost from the current local workflow
- lets the team prove demand before committing to a server-native vector backend

### Why This Should Probably Not Be The Final Architecture

Shipping whole SQLite DB files to a central host is workable, but it is not the
ideal long-term model for a shared multi-user service.

Main limitations:

- coarse-grained updates and sync
- awkward concurrency story as traffic grows
- harder operational model for partial reindexing
- less natural fit for access control and centralized observability
- more friction for global search across many repos

Recommended long-term direction:

- keep SQLite as a local build/export artifact if it remains useful
- move central serving later to a server-native backend such as PostgreSQL +
  `pgvector` or another managed vector store

## REST API Direction

### Suggested v1 Endpoints

- `GET /health`
- `GET /corpora`
- `POST /corpora/register`
- `POST /corpora/upload`
- `POST /ask`
- `POST /search`
- `GET /jobs`

### Suggested `/ask` Contract

Request:

- `question`
- `targets` or `all_targets`
- optional `top_k`
- optional `mode`

Response:

- `answer`
- `supporting_evidence`
- `caveats`
- `sources_consulted`
- `targets_consulted`
- diagnostics such as query time, embedding model, and selected corpora

## Role Of WP-DB-Toolkit `vector/server`

Reference path:

- `/Users/noelsaw/Documents/GH Repos/WP-DB-Toolkit/vector/server`

### Assessment

That project is **not** just a parser stub. It is already a substantial FastAPI
server with:

- auth/session handling
- HTML UI pages
- `/search` and `/ask` endpoints
- health checks
- runtime config loading
- Gemini integration
- request routing

### What It Appears Well-Suited For

It is a credible source of server patterns for the central web app, especially:

- FastAPI app structure
- auth/session patterns
- endpoint layout
- request diagnostics
- startup/config wiring
- lightweight internal UI ideas

### What It Is Not A Direct Fit For

Its current retrieval core is built around WooCommerce data in PostgreSQL with
`pgvector`, not local repo corpora stored in `sqlite-vec`.

That means it is **not** a drop-in backend for ask_self’s current corpus model.

Specifically, it assumes:

- product/order rows in PostgreSQL
- pgvector similarity search
- commerce-oriented semantic/analytics/hybrid routing
- SQL-aware data workflows

So the best use of that codebase is:

- borrow server/app/API/auth patterns
- do **not** reuse its retrieval layer as-is for repo-corpus RAG

## Recommended Delivery Plan

### Phase 1: Next 7 to 10 Days

Create a new central web app repo with:

- FastAPI service
- corpus registry
- uploaded SQLite corpus artifact support
- single-target and multi-target ask/search APIs
- basic auth
- simple admin page or JSON-only operator workflow

### Phase 2: Early Internal Rollout

Add:

- background artifact sync or upload jobs
- request logs and error dashboards
- corpus status pages
- version metadata for uploaded indexes
- reindex/reupload workflow per repo

### Phase 3: If Adoption Holds

Evaluate migration from centralized SQLite artifact serving to:

- PostgreSQL + `pgvector`
- or another dedicated vector backend

The trigger for this should be real operational pressure, not aesthetics.

## Recommendation

Proceed with the central web app as a narrow internal v1.

Best current framing:

- `ask_self` stays the repo-ingest/query engine
- a new central web app becomes the orchestrator and unified responder
- `WP-DB-Toolkit/vector/server` is a strong reference implementation for server
  structure and API shape
- uploaded `sqlite-vec` DBs on GCE are acceptable for v1
- a server-native vector backend should remain a later migration path, not a
  day-one requirement
