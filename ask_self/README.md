# ask_self

`ask_self` is a portable repository-grounded RAG scaffold for codebase Q&A. It builds a local sqlite-vec index from a repo corpus, retrieves relevant chunks with Gemini embeddings, and asks Gemini Pro to synthesize a final answer with optional question-quality feedback.

This README is written for the next LLM or engineer who inherits this folder and wants to maintain or spin it out into its own repository.

**Requirements**

Python 3.10+ with the following packages:

| Package      | Purpose                                | Install                  |
|--------------|----------------------------------------|--------------------------|
| `requests`   | Gemini API and GitHub API calls        | `pip install requests`   |
| `sqlite-vec` | Vector similarity search in SQLite     | `pip install sqlite-vec` |

Standard library modules used: `sqlite3`, `json`, `re`, `pathlib`, `dataclasses`, `concurrent.futures`, `argparse`, `array`, `os`, `sys`.

Quick setup:
```sh
python3 -m venv .venv
source .venv/bin/activate
pip install requests sqlite-vec
```

You also need a `GOOGLE_API_KEY` for Gemini embedding and synthesis. Optionally a `GITHUB_TOKEN` for PR ingestion. See **Credential Handling** below.

**Portable Repo Prerequisites**

If you want a VS Code agent to test `ask_self` directly inside a WordPress theme
or plugin repo, the recommended mode is to copy the entire `ask_self/` folder
into that target repo and run it there.

Target repo prerequisites:

- Python 3.10+
- `requests`
- `sqlite-vec`
- a valid `GOOGLE_API_KEY`
- the copied `ask_self/` folder
- write access to the repo's `temp/` directory for sqlite and env artifacts

Recommended target-repo layout:

```text
my-theme-or-plugin/
├── ask_self/
│   ├── ask_self_ingest.py
│   ├── ask_self_query.py
│   ├── ask_self_harness.py
│   ├── ask_self_helpers.py
│   ├── ask_self_system_instructions.json
│   ├── wp_theme_harness.json
│   └── wp_plugin_harness.json
└── temp/
    └── ask-self-rag.env
```

Example `temp/ask-self-rag.env`:

```env
GOOGLE_API_KEY=your-gemini-key
GITHUB_TOKEN=optional-github-token
```

When the folder is copied into the target repo, ask_self can infer the correct
repo root from `ask_self/*.json`, so `--repo-root` is usually not needed.

**Purpose**
This package exists to answer questions about a repository using the repository itself as the source of truth.

- It ingests docs, source files, and optional GitHub PR history into a local vector index.
- It retrieves semantically relevant chunks for a user question.
- It synthesizes a final answer from retrieved context instead of answering from model memory alone.
- It can assess whether the original question is vague, broad, or underspecified, and suggest a better question.

**Use Cases**

*Standalone*

- **Codebase Q&A** — Ask natural-language questions about a repo and get answers grounded in the actual source, docs, and changelog rather than model memory. Useful for onboarding, auditing, or navigating a large codebase.
- **PR-aware context** — With GitHub PR ingestion enabled, answers can draw on merged PR descriptions and discussion, surfacing decisions that live in review threads rather than code comments.
- **Question quality feedback** — The system assesses whether a question is vague or underspecified, and suggests a sharper reformulation. Useful for building self-service Q&A interfaces where users may not know how to ask.

*Integrated with the WPCC scanner*

- **Finding triage and explanation** — After the scanner flags issues, pipe findings into ask_self to get repo-grounded context: "Is this `eval()` usage intentional?" or "How does this repo typically handle `$wpdb->prepare()`?" Cuts triage time by distinguishing known patterns from real concerns.
- **False positive reduction** — The scanner's grep-based detection cannot see multi-line sanitization or architectural intent. ask_self can retrieve chunks showing a flagged pattern is wrapped in a mitigation elsewhere, acting as a semantic second opinion on structural matches.
- **Pattern gap discovery** — "What risks exist in this repo that the scanner doesn't currently check for?" is a question ask_self can attempt since it has both the pattern library and the source indexed together.
- **Repo-grounded remediation** — Instead of generic remediation advice, ask_self can show how the specific repo already handles a given pattern, producing fix suggestions that match the existing codebase conventions.

**Core Files**
- `ask_self_ingest.py`: builds the local sqlite-vec index from the configured corpus.
- `ask_self_query.py`: embeds a query, performs KNN retrieval, then calls Gemini Pro for structured synthesis.
- `ask_self_harness.py`: repo-specific configuration loader, env-file loader, and path helpers.
- `ask_self_harness.json`: repo-specific policy for corpus selection, labels, env file location, DB naming, and GitHub settings.
- `ask_self_system_instructions.json`: user-editable synthesis instruction layers for Gemini Pro.
- `ask_self_helpers.py`: chunking and context-format helpers.

**Runtime Architecture**
1. `ask_self_ingest.py` loads the harness config.
2. The harness loads a `.env`-style file from `temp/ask-self-rag.env` by default if it exists.
3. Ingest walks the repo using harness include and exclude rules.
4. Each file is classified into a source type and chunking strategy.
5. Chunks are embedded with `gemini-embedding-001`.
6. Embeddings plus metadata are written into sqlite plus sqlite-vec.
7. `ask_self_query.py` embeds the user question with `gemini-embedding-001`.
8. Query retrieves nearest chunks from sqlite-vec and reranks slightly by source priority.
9. Query loads layered system instructions from `ask_self_system_instructions.json`.
10. Gemini Pro synthesizes a structured answer from retrieved context.
11. The renderer formats the answer, caveats, question assessment, better-question suggestion, and source list.

**Model Split**
- Retrieval embeddings: `gemini-embedding-001`
- Final synthesis: `gemini-pro-latest`

The system is classic RAG. Retrieval and synthesis are intentionally separate so you can swap either layer independently later.

**Configuration Model**
The main extension point is `ask_self_harness.json`.

The harness controls:
- `repo_label`: label injected into synthesis prompts.
- `repo_kind`: optional registry classification such as `repo`, `theme`, or `plugin`.
- `repo_root`: optional explicit repo root override. If omitted, ask_self infers the repo root from the harness location.
- `db_filename` or `db_path`: where the sqlite index lives.
- `system_instructions_path`: which user-editable instruction file drives final synthesis.
- `env_file_path`: where runtime credentials are loaded from. Default is `temp/ask-self-rag.env`.
- `github`: optional PR-ingestion settings.
- `docs` and `source`: include patterns, exclude patterns, and file extensions.
- `classification_rules`: how files map to `doc`, `script`, `pattern`, `test`, `changelog`, or other source classes.

If you spin this into its own repo, preserve the distinction between:
- generic engine behavior in Python code
- repo policy in `ask_self_harness.json`
- answer behavior in `ask_self_system_instructions.json`

That split is the main architectural boundary worth protecting.

**Portable Harness Resolution**

By default, ask_self infers the repo root from the harness path:
- `repo/ask_self/*.json` resolves against `repo/`
- any other harness path resolves against the harness file's parent directory

You can override that with either:
- a `repo_root` key in the harness JSON
- `--repo-root` on `ask_self_ingest.py` or `ask_self_query.py`

This matters when you keep reusable harness templates in one repo and point them at another repo for ingestion/query.

**System Instruction Layer**
`ask_self_system_instructions.json` is intentionally user-editable.

It currently supports layered instructions:
- `base_system`
- `repo_context_system`
- `answer_style_system`
- `question_quality_system`
- `query_improvement_system`

It also defines a response contract for structured synthesis output. Keep this file editable and outside the code path for normal prompt tuning. If maintainers need to change answer behavior, they should start there rather than editing Python code.

**Credential Handling**
This package is intentionally biased toward keeping credentials out of tracked files.

- Default runtime env file: `temp/ask-self-rag.env`
- The harness auto-loads that file if present.
- Existing shell environment variables override file values.
- `temp/` should remain gitignored in any spun-out repo.

Expected env vars:
- `GOOGLE_API_KEY`
- `GITHUB_TOKEN` or another token name referenced by `github.token_env_vars`
- optional tenancy env var such as `WP_CODE_CHECK_SELF_ASK_TEAM_ID`

Example `temp/ask-self-rag.env`:

```env
GOOGLE_API_KEY=your-gemini-key
GITHUB_TOKEN=your-github-pat
WP_CODE_CHECK_SELF_ASK_TEAM_ID=optional-team-id
```

Do not store real credentials in `ask_self_harness.json`, `README.md`, or any committed `.env` file.

**Current Query Output Contract**
`ask_self_query.py --json` returns structured fields that downstream tools can consume:

- `answer`
- `supporting_evidence`
- `caveats`
- `question_assessment`
- `better_question`
- `why_this_is_better`
- `sources_consulted`
- `rendered_answer`

`rendered_answer` is a convenience field for terminal UX. If you build an API or UI around this package, prefer the structured fields and treat `rendered_answer` as presentation only.

**Known Engineering Tradeoffs**
- Gemini sometimes ignores JSON-only instructions or truncates structured output. The query layer contains repair and fallback logic to recover usable fields.
- Retrieval quality depends heavily on harness corpus policy. Bad include patterns will hurt answer quality faster than prompt tuning will fix it.
- The reranking logic is deliberately light. It nudges by priority but does not attempt cross-encoder style reranking.
- `sqlite_vec` is a runtime dependency. The package lazy-loads it so `--help` still works when the native extension is not installed.
- PR ingestion is optional and network-dependent. It should remain non-critical to local repo Q&A.

**How To Extend It**
- To support a new repo: copy the folder, rewrite `ask_self_harness.json`, update `ask_self_system_instructions.json`, and rebuild the index.
- For WordPress targets, start from `wp_theme_harness.json` or `wp_plugin_harness.json` and then tighten include/exclude patterns for the specific repo.
- To support new source types: add a new classification rule plus a chunking strategy if needed.
- To change answer behavior: edit `ask_self_system_instructions.json`.
- To change retrieval behavior: edit chunking, classification, or KNN/reranking logic in Python.
- To change models: update the model constants in `ask_self_ingest.py` and `ask_self_query.py`.

**WordPress Harness Templates**

This folder now includes:
- `wp_theme_harness.json` for block/classic theme repos
- `wp_plugin_harness.json` for plugin repos

Typical usage when the templates stay in AI-DDTK and the target repo lives elsewhere:

```sh
python3 ask_self/ask_self_ingest.py \
  --repo-root /path/to/wp-content/themes/my-theme \
  --harness-config ask_self/wp_theme_harness.json \
  --mode all \
  --no-prs

python3 ask_self/ask_self_query.py \
  --repo-root /path/to/wp-content/themes/my-theme \
  --harness-config ask_self/wp_theme_harness.json \
  --db-path /path/to/wp-content/themes/my-theme/temp/rag/wp-theme-self-ask.sqlite \
  "Where is the hero block assembled?"
```

If you copy the harness and system-instructions files into the target repo under `ask_self/`, `--repo-root` becomes optional because ask_self can infer the correct root from the copied harness path.

**VS Code Agent Quickstart**

This is the shortest reliable workflow for an agent working inside a theme or
plugin repo after the `ask_self/` folder has been copied there.

Theme repo quickstart:

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install requests sqlite-vec

mkdir -p temp
printf 'GOOGLE_API_KEY=%s\n' "$GOOGLE_API_KEY" > temp/ask-self-rag.env

python3 ask_self/ask_self_ingest.py \
  --harness-config ask_self/wp_theme_harness.json \
  --mode all \
  --no-prs

python3 ask_self/ask_self_query.py \
  --harness-config ask_self/wp_theme_harness.json \
  "Where is the hero block assembled?"
```

Plugin repo quickstart:

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install requests sqlite-vec

mkdir -p temp
printf 'GOOGLE_API_KEY=%s\n' "$GOOGLE_API_KEY" > temp/ask-self-rag.env

python3 ask_self/ask_self_ingest.py \
  --harness-config ask_self/wp_plugin_harness.json \
  --mode all \
  --no-prs

python3 ask_self/ask_self_query.py \
  --harness-config ask_self/wp_plugin_harness.json \
  "Which hook registers the cart fee logic?"
```

Recommended agent prompt:

```text
Use the copied ask_self folder in this repo. If dependencies are missing, install
requests and sqlite-vec into a local virtualenv. Put GOOGLE_API_KEY in
temp/ask-self-rag.env, run ask_self_ingest.py with the correct WordPress harness,
then use ask_self_query.py to answer questions about this codebase from the local
RAG index.
```

Fallback mode when `ask_self/` is not copied into the target repo:

- run from the source AI-DDTK repo with `--repo-root /path/to/target-repo`
- consider overriding `--registry-path` if you do not want the shared registry to live under the AI-DDTK workspace

**Registry And Multi-DB Query**

ask_self now maintains a shared local registry of ingested corpora at `temp/rag/ask_self_registry.json` by default.

Each registry entry records:
- `slug`
- `kind`
- `repo_root`
- `repo_label`
- `harness_config`
- `db_path`
- `ingest_command`
- `embed_model`
- `embed_dim`
- `updated_at`

Normal ingest updates that registry automatically unless you pass `--no-register`.

Query modes:
- Single repo by harness/db path: existing behavior
- Single repo by slug: `--target my-plugin`
- Multiple repos by slug: `--target my-plugin --target storefront-child` or `--targets my-plugin,storefront-child`
- Federated query across all compatible DBs: `--all-targets`

Federated query guardrail:
- ask_self refuses to merge registry targets built with different embedding model/dimension metadata

Examples:

```sh
python3 ask_self/ask_self_ingest.py \
  --repo-root /path/to/wp-content/plugins/my-plugin \
  --harness-config ask_self/wp_plugin_harness.json \
  --mode all \
  --no-prs

python3 ask_self/ask_self_query.py \
  --target my-plugin \
  "Which hook registers the cart fee logic?"

python3 ask_self/ask_self_query.py \
  --targets my-plugin,my-theme \
  "Where do we localize frontend script data?"
```

**If You Spin This Out**
Recommended repo contents:
- `ask_self_ingest.py`
- `ask_self_query.py`
- `ask_self_harness.py`
- `ask_self_helpers.py`
- `README.md`
- example `ask_self_harness.json`
- example `ask_self_system_instructions.json`
- `.gitignore` with `temp/`, `.venv/`, and sqlite artifacts ignored

Recommended follow-up work after spinout:
- add automated tests for env loading, harness loading, chunking, and structured-answer recovery
- add a small CLI wrapper with named commands
- add a sample harness for Python, PHP, and docs-heavy repos
- add a machine-readable schema file for the harness JSON

**Maintainer Rule**
If behavior feels repo-specific, put it in the harness or system-instructions file.
If behavior feels universally true for this RAG engine, put it in Python.
