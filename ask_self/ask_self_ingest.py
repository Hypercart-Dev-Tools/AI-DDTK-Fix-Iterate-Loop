"""Python ingest path for the ask-self RAG scaffold."""

from __future__ import annotations

import argparse
import array
import concurrent.futures
import json
import os
import re
import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import requests

try:
    from ask_self_harness import (
        DEFAULT_HARNESS_PATH,
        REPO_ROOT,
        classify_path,
        get_harness_repo_root,
        get_corpus_settings,
        get_default_db_path,
        get_github_settings,
        get_ingest_command,
        get_repo_kind,
        get_repo_label,
        get_repo_slug,
        load_runtime_env,
        load_harness_config,
        pick_github_token,
    )
    from ask_self_registry import get_registry_path, upsert_registry_entry, utc_timestamp
    from ask_self_helpers import (
        chunk_changelog,
        chunk_code,
        chunk_lines,
        chunk_text,
    )
except ImportError:  # pragma: no cover - package import path
    from .ask_self_harness import (
        DEFAULT_HARNESS_PATH,
        REPO_ROOT,
        classify_path,
        get_harness_repo_root,
        get_corpus_settings,
        get_default_db_path,
        get_github_settings,
        get_ingest_command,
        get_repo_kind,
        get_repo_label,
        get_repo_slug,
        load_runtime_env,
        load_harness_config,
        pick_github_token,
    )
    from .ask_self_registry import get_registry_path, upsert_registry_entry, utc_timestamp
    from .ask_self_helpers import (
        chunk_changelog,
        chunk_code,
        chunk_lines,
        chunk_text,
    )

EMBED_MODEL = "gemini-embedding-001"
EMBED_DIM = 768
INGEST_MODES = ("docs", "code", "all")

DEFAULT_HARNESS = load_harness_config(DEFAULT_HARNESS_PATH)
DEFAULT_HARNESS_ROOT = get_harness_repo_root(DEFAULT_HARNESS, fallback_repo_root=REPO_ROOT)
DEFAULT_GITHUB_SETTINGS = get_github_settings(DEFAULT_HARNESS)
DEFAULT_DB_PATH = get_default_db_path(DEFAULT_HARNESS, repo_root=DEFAULT_HARNESS_ROOT)
DEFAULT_PR_FETCH_LIMIT = int(DEFAULT_GITHUB_SETTINGS.get("default_fetch_limit") or 200)
DEFAULT_REGISTRY_PATH = get_registry_path()


@dataclass
class ChunkRow:
    source: str
    content: str
    path: str | None = None
    pr_number: int | None = None
    version: str | None = None
    priority: int = 1


def _vector_to_blob(values: list[float]) -> bytes:
    return array.array("f", values).tobytes()


def _compile_patterns(patterns: list[str] | tuple[str, ...] | None) -> list[re.Pattern[str]]:
    if not patterns:
        return []
    return [re.compile(pattern) for pattern in patterns]


def _normalize_extensions(extensions: list[str] | tuple[str, ...] | None) -> tuple[str, ...]:
    if not extensions:
        return (".md",)

    cleaned: list[str] = []
    for ext in extensions:
        text = str(ext).strip()
        if not text:
            continue
        if not text.startswith("."):
            text = "." + text
        cleaned.append(text.lower())

    if not cleaned:
        return (".md",)
    return tuple(dict.fromkeys(cleaned))


def walk_repo_files(
    repo_root: Path,
    *,
    include_patterns: list[re.Pattern[str]] | tuple[re.Pattern[str], ...],
    exclude_patterns: list[re.Pattern[str]] | tuple[re.Pattern[str], ...],
    extensions: list[str] | tuple[str, ...],
) -> list[Path]:
    """Walk the repository and return files matching the configured corpus rules."""
    ext_filter = _normalize_extensions(extensions)
    found: list[Path] = []
    for path in repo_root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in ext_filter:
            continue
        rel = path.relative_to(repo_root).as_posix()
        if any(rx.search(rel) for rx in exclude_patterns):
            continue
        if any(rx.search(rel) for rx in include_patterns):
            found.append(path)
    found.sort(key=lambda item: item.as_posix())
    return found


def embed_one(text: str, api_key: str, *, task_type: str = "RETRIEVAL_DOCUMENT") -> list[float]:
    endpoint = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{EMBED_MODEL}:embedContent?key={api_key}"
    )
    payload = {
        "model": f"models/{EMBED_MODEL}",
        "content": {"parts": [{"text": text}]},
        "taskType": task_type,
        "outputDimensionality": EMBED_DIM,
    }
    resp = requests.post(endpoint, json=payload, timeout=60)
    if not resp.ok:
        raise RuntimeError(f"Gemini embed {resp.status_code}: {resp.text[:400]}")
    data = resp.json()
    values = (data.get("embedding") or {}).get("values")
    if not isinstance(values, list) or len(values) != EMBED_DIM:
        got = len(values) if isinstance(values, list) else None
        raise RuntimeError(f"Gemini embed: unexpected shape, got {got} dims")
    return [float(v) for v in values]


def embed_batch(texts: list[str], api_key: str, *, concurrency: int = 4) -> list[list[float]]:
    """Embed a batch of chunks with simple retry handling."""
    out: list[list[float] | None] = [None] * len(texts)

    def work(idx: int) -> None:
        attempt = 0
        while True:
            try:
                out[idx] = embed_one(texts[idx], api_key)
                return
            except Exception:
                attempt += 1
                if attempt >= 3:
                    raise
                time.sleep(0.5 * attempt)

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, concurrency)) as pool:
        futures = [pool.submit(work, i) for i in range(len(texts))]
        for fut in futures:
            fut.result()

    return [value for value in out if value is not None]


def fetch_merged_prs(
    *,
    owner: str,
    repo: str,
    token: str | None,
    limit: int = DEFAULT_PR_FETCH_LIMIT,
) -> list[dict[str, Any]]:
    """Fetch merged PRs for optional repo-history grounding."""
    if not token or not owner or not repo:
        return []

    url = f"https://api.github.com/repos/{owner}/{repo}/pulls"
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2022-11-28",
    }

    page = 1
    merged: list[dict[str, Any]] = []
    while len(merged) < limit:
        resp = requests.get(
            url,
            headers=headers,
            params={
                "state": "closed",
                "sort": "updated",
                "direction": "desc",
                "per_page": 100,
                "page": page,
            },
            timeout=30,
        )
        if not resp.ok:
            raise RuntimeError(f"GitHub PR fetch failed {resp.status_code}: {resp.text[:300]}")

        rows = resp.json()
        if not rows:
            break
        for pr in rows:
            if pr.get("merged_at"):
                merged.append(pr)
                if len(merged) >= limit:
                    break
        page += 1

    return merged[:limit]


def open_db(db_path: Path) -> sqlite3.Connection:
    """Create a fresh sqlite-vec index."""
    import sqlite_vec

    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(str(db_path))
    conn.enable_load_extension(True)
    sqlite_vec.load(conn)
    conn.execute(
        """
        CREATE TABLE chunks (
          id INTEGER PRIMARY KEY,
          source TEXT NOT NULL,
          path TEXT,
          pr_number INTEGER,
          version TEXT,
          priority INTEGER NOT NULL DEFAULT 1,
          content TEXT NOT NULL,
          created_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
        """
    )
    conn.execute(f"CREATE VIRTUAL TABLE chunks_vec USING vec0(embedding float[{EMBED_DIM}])")
    conn.commit()
    return conn


def insert_chunk(conn: sqlite3.Connection, row: ChunkRow, embedding: list[float]) -> None:
    """Insert a metadata row plus its embedding vector."""
    cur = conn.execute(
        (
            "INSERT INTO chunks (source, path, pr_number, version, priority, content) "
            "VALUES (?, ?, ?, ?, ?, ?)"
        ),
        (row.source, row.path, row.pr_number, row.version, row.priority, row.content),
    )
    rowid = int(cur.lastrowid)
    conn.execute(
        "INSERT INTO chunks_vec(rowid, embedding) VALUES (?, ?)",
        (rowid, _vector_to_blob(embedding)),
    )


def _chunk_file(text: str, *, chunker: str) -> list[str] | list[dict[str, str | None]]:
    if chunker == "changelog":
        return chunk_changelog(text)
    if chunker == "python":
        return chunk_code(text)
    if chunker == "line":
        return chunk_lines(text)
    return chunk_text(text)


def build_doc_rows(
    repo_root: Path,
    *,
    harness_config: dict[str, Any],
    max_doc_files: int | None = None,
    include_patterns: list[str] | tuple[str, ...] | None = None,
    exclude_patterns: list[str] | tuple[str, ...] | None = None,
    doc_extensions: list[str] | tuple[str, ...] | None = None,
    source_allowlist: list[str] | tuple[str, ...] | None = None,
    mode: str = "docs",
) -> list[ChunkRow]:
    """Build chunk rows from the repository corpus."""
    if mode not in INGEST_MODES:
        raise ValueError(f"build_doc_rows: mode must be one of {INGEST_MODES}")

    if include_patterns is not None:
        inc_rx = _compile_patterns(list(include_patterns))
    else:
        inc_rx = _compile_patterns(get_corpus_settings(harness_config, mode)["include_patterns"])

    if exclude_patterns is not None:
        exc_rx = _compile_patterns(list(exclude_patterns))
    else:
        exc_rx = _compile_patterns(get_corpus_settings(harness_config, mode)["exclude_patterns"])

    if doc_extensions is not None:
        ext_list: list[str] = list(doc_extensions)
    else:
        ext_list = get_corpus_settings(harness_config, mode)["extensions"]

    files = walk_repo_files(
        repo_root,
        include_patterns=inc_rx,
        exclude_patterns=exc_rx,
        extensions=ext_list,
    )
    if max_doc_files is not None:
        files = files[: max(0, max_doc_files)]

    allowed_sources = {str(item).strip() for item in (source_allowlist or []) if str(item).strip()}
    rows: list[ChunkRow] = []

    for file_path in files:
        rel = file_path.relative_to(repo_root).as_posix()
        text = file_path.read_text(encoding="utf-8", errors="replace")
        doc_class = classify_path(rel, harness_config)
        source = str(doc_class["source"])
        priority = int(doc_class["priority"])
        chunker = str(doc_class.get("chunker") or "text")

        if allowed_sources and source not in allowed_sources:
            continue

        chunks = _chunk_file(text, chunker=chunker)
        if chunker == "changelog":
            for entry in chunks:
                rows.append(
                    ChunkRow(
                        source="changelog",
                        path=rel,
                        version=entry["version"],
                        priority=priority,
                        content=str(entry["content"]),
                    )
                )
            continue

        for chunk in chunks:
            rows.append(
                ChunkRow(
                    source=source,
                    path=rel,
                    priority=priority,
                    content=str(chunk),
                )
            )

    return rows


def build_pr_rows(prs: list[dict[str, Any]]) -> list[ChunkRow]:
    """Build chunk rows from merged pull request metadata."""
    rows: list[ChunkRow] = []
    for pr in prs:
        pr_num = pr.get("number")
        body = pr.get("body") or ""
        text = (
            f"PR #{pr_num}: {pr.get('title')}\n"
            f"Merged: {pr.get('merged_at')} by {(pr.get('user') or {}).get('login', 'unknown')}\n\n"
            f"{body}"
        )
        rows.append(
            ChunkRow(
                source="pr",
                path=f"PR #{pr_num}",
                pr_number=int(pr_num),
                priority=1,
                content=text[: 9600],
            )
        )
    return rows


def ingest(
    *,
    repo_root: Path | None = None,
    db_path: Path | None = None,
    registry_path: Path | None = None,
    harness_config_path: Path = DEFAULT_HARNESS_PATH,
    include_prs: bool = True,
    register: bool = True,
    github_owner: str | None = None,
    github_repo: str | None = None,
    pr_fetch_limit: int | None = None,
    max_doc_files: int | None = None,
    max_rows: int | None = None,
    concurrency: int = 4,
    include_patterns: list[str] | None = None,
    exclude_patterns: list[str] | None = None,
    doc_extensions: list[str] | None = None,
    source_allowlist: list[str] | None = None,
    mode: str = "docs",
) -> dict[str, Any]:
    """Build the local ask-self vector index."""
    harness_config = load_harness_config(harness_config_path)
    resolved_repo_root = repo_root or get_harness_repo_root(
        harness_config,
        fallback_repo_root=REPO_ROOT,
    )
    load_runtime_env(harness_config, repo_root=resolved_repo_root)

    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        raise RuntimeError("GOOGLE_API_KEY not set")

    resolved_db_path = db_path or get_default_db_path(
        harness_config,
        repo_root=resolved_repo_root,
    )
    github_settings = get_github_settings(harness_config)
    owner = github_owner if github_owner is not None else str(github_settings.get("owner") or "")
    repo = github_repo if github_repo is not None else str(github_settings.get("repo") or "")
    limit = pr_fetch_limit if pr_fetch_limit is not None else int(
        github_settings.get("default_fetch_limit") or DEFAULT_PR_FETCH_LIMIT
    )

    t0 = time.time()
    doc_rows = build_doc_rows(
        resolved_repo_root,
        harness_config=harness_config,
        max_doc_files=max_doc_files,
        include_patterns=include_patterns,
        exclude_patterns=exclude_patterns,
        doc_extensions=doc_extensions,
        source_allowlist=source_allowlist,
        mode=mode,
    )

    prs: list[dict[str, Any]] = []
    if include_prs:
        prs = fetch_merged_prs(
            owner=owner,
            repo=repo,
            token=pick_github_token(harness_config),
            limit=limit,
        )

    all_rows = doc_rows + build_pr_rows(prs)
    if max_rows is not None:
        all_rows = all_rows[: max(0, max_rows)]

    embeddings = embed_batch([row.content for row in all_rows], api_key, concurrency=concurrency)

    conn = open_db(resolved_db_path)
    try:
        with conn:
            for row, embedding in zip(all_rows, embeddings):
                insert_chunk(conn, row, embedding)

        total = conn.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
        by_source_rows = conn.execute(
            "SELECT source, COUNT(*) AS c FROM chunks GROUP BY source ORDER BY c DESC"
        ).fetchall()
    finally:
        conn.close()

    corpus_settings = get_corpus_settings(harness_config, mode)
    result: dict[str, Any] = {
        "db_path": str(resolved_db_path),
        "total_chunks": int(total),
        "by_source": {str(source): int(count) for source, count in by_source_rows},
        "corpus_policy": {
            "repo_root": str(resolved_repo_root),
            "mode": mode,
            "harness_config": str(harness_config.get("_config_path", harness_config_path)),
            "include_patterns": include_patterns or corpus_settings["include_patterns"],
            "exclude_patterns": exclude_patterns or corpus_settings["exclude_patterns"],
            "extensions": doc_extensions or corpus_settings["extensions"],
            "source_allowlist": source_allowlist or [],
        },
        "elapsed_seconds": round(time.time() - t0, 2),
    }

    if register:
        entry = {
            "slug": get_repo_slug(harness_config, repo_root=resolved_repo_root),
            "kind": get_repo_kind(harness_config),
            "repo_root": str(resolved_repo_root.resolve()),
            "repo_label": get_repo_label(harness_config),
            "harness_config": str(Path(str(harness_config.get("_config_path", harness_config_path))).resolve()),
            "db_path": str(resolved_db_path.resolve()),
            "ingest_command": get_ingest_command(harness_config),
            "embed_model": EMBED_MODEL,
            "embed_dim": EMBED_DIM,
            "updated_at": utc_timestamp(),
            "last_ingest_mode": mode,
            "total_chunks": int(total),
        }
        _, resolved_registry_path = upsert_registry_entry(entry, registry_path)
        result["registry"] = {
            "path": str(resolved_registry_path),
            "slug": entry["slug"],
            "kind": entry["kind"],
        }

    return result


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build local ask-self sqlite index")
    parser.add_argument(
        "--db-path",
        default=None,
        help="Output sqlite DB path (defaults to the harness-defined path)",
    )
    parser.add_argument(
        "--registry-path",
        default=None,
        help=f"Registry JSON path (defaults to {DEFAULT_REGISTRY_PATH})",
    )
    parser.add_argument(
        "--repo-root",
        default=None,
        help="Repo root to ingest (defaults to the harness-inferred repo root)",
    )
    parser.add_argument(
        "--harness-config",
        default=str(DEFAULT_HARNESS_PATH),
        help="Path to repo-specific harness JSON",
    )
    parser.add_argument("--no-prs", action="store_true", help="Skip GitHub PR ingestion")
    parser.add_argument(
        "--no-register",
        action="store_true",
        help="Skip updating the shared ask-self registry",
    )
    parser.add_argument(
        "--github-owner",
        default=None,
        help="GitHub owner/org override",
    )
    parser.add_argument(
        "--github-repo",
        default=None,
        help="GitHub repository override",
    )
    parser.add_argument(
        "--pr-fetch-limit",
        type=int,
        default=None,
        help="Max merged PRs (defaults to the harness setting)",
    )
    parser.add_argument("--max-doc-files", type=int, default=None, help="Limit corpus files")
    parser.add_argument("--max-rows", type=int, default=None, help="Limit total chunks")
    parser.add_argument("--concurrency", type=int, default=4, help="Embedding concurrency")
    parser.add_argument(
        "--include-pattern",
        action="append",
        dest="include_patterns",
        default=None,
        help="Regex to include repo-relative files (repeatable)",
    )
    parser.add_argument(
        "--exclude-pattern",
        action="append",
        dest="exclude_patterns",
        default=None,
        help="Regex to exclude repo-relative files (repeatable)",
    )
    parser.add_argument(
        "--doc-ext",
        "--ext",
        action="append",
        dest="doc_extensions",
        default=None,
        help="Corpus file extension to ingest (repeatable, e.g. md or py)",
    )
    parser.add_argument(
        "--source",
        action="append",
        dest="source_allowlist",
        default=None,
        help="Allow only classified source(s) from the harness config",
    )
    parser.add_argument(
        "--mode",
        choices=list(INGEST_MODES),
        default="docs",
        help="Corpus mode: docs, code, or all",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON summary")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    try:
        result = ingest(
            repo_root=Path(args.repo_root) if args.repo_root else None,
            db_path=Path(args.db_path) if args.db_path else None,
            registry_path=Path(args.registry_path) if args.registry_path else None,
            harness_config_path=Path(args.harness_config),
            include_prs=not args.no_prs,
            register=not args.no_register,
            github_owner=args.github_owner,
            github_repo=args.github_repo,
            pr_fetch_limit=args.pr_fetch_limit,
            max_doc_files=args.max_doc_files,
            max_rows=args.max_rows,
            concurrency=args.concurrency,
            include_patterns=args.include_patterns,
            exclude_patterns=args.exclude_patterns,
            doc_extensions=args.doc_extensions,
            source_allowlist=args.source_allowlist,
            mode=args.mode,
        )
    except Exception as exc:  # noqa: BLE001
        if args.json:
            print(json.dumps({"ok": False, "error": str(exc)}))
        else:
            print(f"ERROR: {exc}")
        return 1

    if args.json:
        print(json.dumps({"ok": True, **result}, ensure_ascii=False, indent=2))
    else:
        print(
            f"Indexed {result['total_chunks']} chunks into {result['db_path']}"
            f" in {result['elapsed_seconds']}s"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
