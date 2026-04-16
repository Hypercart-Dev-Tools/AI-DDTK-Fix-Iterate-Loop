"""Harness helpers for repo-specific ask-self configuration."""

from __future__ import annotations

import copy
import json
import os
import re
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_HARNESS_PATH = REPO_ROOT / "ask_self" / "ask_self_harness.json"

DEFAULT_HARNESS: dict[str, Any] = {
    "repo_label": "This repository",
    "repo_kind": "repo",
    "db_filename": "ask_self.sqlite",
    "system_instructions_path": "ask_self/ask_self_system_instructions.json",
    "env_file_path": "temp/ask-self-rag.env",
    "ingest_command": "python3 ask_self/ask_self_ingest.py",
    "tenancy_env_var": "SELF_ASK_TEAM_ID",
    "github": {
        "owner": "",
        "repo": "",
        "default_fetch_limit": 200,
        "token_env_vars": ["GITHUB_TOKEN"],
    },
    "docs": {
        "extensions": [".md"],
        "include_patterns": [r"^[^/]+\.md$", r"^PROJECT/.+\.md$"],
        "exclude_patterns": [
            r"^\.git/",
            r"^node_modules/",
            r"^temp/",
            r"^scratch/",
            r"^\.venv/",
        ],
    },
    "source": {
        "extensions": [".py"],
        "include_patterns": [r"^[^/]+\.py$", r"^(?:src|app|lib|server|scripts|tests)/.+\.py$"],
        "exclude_patterns": [
            r"^\.git/",
            r"^node_modules/",
            r"^temp/",
            r"^scratch/",
            r"^\.venv/",
        ],
    },
    "classification_rules": [
        {
            "pattern": r"(?i)changelog\.md$",
            "source": "changelog",
            "priority": 5,
            "chunker": "changelog",
        },
        {
            "pattern": r"(?i)strategy|product.*brief|moat|pmf|positioning",
            "source": "strategy",
            "priority": 5,
            "chunker": "text",
        },
        {
            "pattern": r"^tests?/",
            "source": "test",
            "priority": 1,
            "chunker": "line",
        },
        {
            "pattern": r"\.py$",
            "source": "module",
            "priority": 3,
            "chunker": "python",
        },
        {
            "pattern": r"\.(?:sh|bash|zsh|js|mjs|cjs|ts|tsx|jsx|php)$",
            "source": "script",
            "priority": 2,
            "chunker": "line",
        },
    ],
    "default_classification": {
        "source": "doc",
        "priority": 1,
        "chunker": "text",
    },
}


def _deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    merged = copy.deepcopy(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = _deep_merge(merged[key], value)
        else:
            merged[key] = copy.deepcopy(value)
    return merged


def resolve_repo_path(value: str, *, repo_root: Path = REPO_ROOT) -> Path:
    """Resolve a repo-relative or absolute path."""
    if not isinstance(value, str) or not value.strip():
        raise TypeError("resolve_repo_path: value must be a non-empty string")
    path = Path(value)
    return path if path.is_absolute() else repo_root / path


def get_harness_repo_root(
    config: dict[str, Any],
    *,
    fallback_repo_root: Path = REPO_ROOT,
) -> Path:
    """Infer the repo root for a harness config.

    If the config declares `repo_root`, resolve it relative to the harness file.
    Otherwise infer the repo root from the harness path itself:
    - `repo/ask_self/*.json` -> `repo/`
    - any other location    -> parent directory of the config file
    """
    config_path_value = config.get("_config_path")
    config_path: Path | None = None
    if isinstance(config_path_value, str) and config_path_value.strip():
        config_path = Path(config_path_value).resolve()

    inferred_root = fallback_repo_root.resolve()
    if config_path is not None:
        config_dir = config_path.parent
        inferred_root = (
            config_dir.parent if config_dir.name == "ask_self" else config_dir
        ).resolve()

    repo_root_value = config.get("repo_root")
    if isinstance(repo_root_value, str) and repo_root_value.strip():
        return resolve_repo_path(repo_root_value, repo_root=inferred_root).resolve()

    return inferred_root


def load_harness_config(config_path: Path | None = None) -> dict[str, Any]:
    """Load and validate harness configuration."""
    path = Path(config_path or DEFAULT_HARNESS_PATH)
    config = copy.deepcopy(DEFAULT_HARNESS)

    if path.exists():
        with path.open("r", encoding="utf-8") as fh:
            loaded = json.load(fh)
        if not isinstance(loaded, dict):
            raise TypeError("Harness config must be a JSON object")
        config = _deep_merge(config, loaded)

    config["_config_path"] = str(path.resolve())
    return config


def get_repo_label(config: dict[str, Any]) -> str:
    """Return the repo label shown in prompts and messages."""
    label = config.get("repo_label")
    if not isinstance(label, str) or not label.strip():
        return str(DEFAULT_HARNESS["repo_label"])
    return label.strip()


def get_repo_kind(config: dict[str, Any]) -> str:
    """Return the normalized repo kind used for registry metadata."""
    kind = str(config.get("repo_kind") or DEFAULT_HARNESS["repo_kind"]).strip().lower()
    if not kind:
        return str(DEFAULT_HARNESS["repo_kind"])
    return re.sub(r"[^a-z0-9_-]+", "-", kind).strip("-") or str(DEFAULT_HARNESS["repo_kind"])


def get_repo_slug(config: dict[str, Any], *, repo_root: Path = REPO_ROOT) -> str:
    """Return a stable repo slug for registry lookups."""
    raw_value = config.get("repo_slug")
    if not isinstance(raw_value, str) or not raw_value.strip():
        raw_value = repo_root.name or get_repo_label(config)

    slug = re.sub(r"[^a-z0-9]+", "-", raw_value.strip().lower()).strip("-")
    return slug or "repo"


def get_ingest_command(config: dict[str, Any]) -> str:
    """Return the recommended ingest command for operator-facing errors."""
    command = config.get("ingest_command")
    if not isinstance(command, str) or not command.strip():
        return str(DEFAULT_HARNESS["ingest_command"])
    return command.strip()


def get_tenancy_env_var(config: dict[str, Any]) -> str:
    """Return the optional allowlist env var name."""
    env_var = config.get("tenancy_env_var")
    if not isinstance(env_var, str) or not env_var.strip():
        return str(DEFAULT_HARNESS["tenancy_env_var"])
    return env_var.strip()


def get_default_db_path(config: dict[str, Any], *, repo_root: Path = REPO_ROOT) -> Path:
    """Return the default sqlite path for this harness."""
    db_path = config.get("db_path")
    if isinstance(db_path, str) and db_path.strip():
        return resolve_repo_path(db_path, repo_root=repo_root)

    db_filename = config.get("db_filename") or DEFAULT_HARNESS["db_filename"]
    return repo_root / "temp" / "rag" / str(db_filename)


def get_system_instructions_path(config: dict[str, Any], *, repo_root: Path = REPO_ROOT) -> Path:
    """Return the system instructions file path for this harness."""
    instructions_path = (
        config.get("system_instructions_path")
        or config.get("prompts_path")
        or DEFAULT_HARNESS["system_instructions_path"]
    )
    return resolve_repo_path(str(instructions_path), repo_root=repo_root)


def get_env_file_path(config: dict[str, Any], *, repo_root: Path = REPO_ROOT) -> Path:
    """Return the runtime env file path for this harness."""
    env_file_path = config.get("env_file_path") or DEFAULT_HARNESS["env_file_path"]
    return resolve_repo_path(str(env_file_path), repo_root=repo_root)


def _strip_env_quotes(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def load_runtime_env(config: dict[str, Any], *, repo_root: Path = REPO_ROOT) -> Path | None:
    """Load a simple KEY=VALUE env file if it exists.

    Existing environment variables win over file values so operators can override
    the temp env file from their shell or CI runner when needed.
    """
    env_file_path = get_env_file_path(config, repo_root=repo_root)
    if not env_file_path.exists():
        return None

    with env_file_path.open("r", encoding="utf-8") as fh:
        for raw_line in fh:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[7:].strip()
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            name = key.strip()
            if not name or name in os.environ:
                continue
            os.environ[name] = _strip_env_quotes(value.strip())

    return env_file_path


def get_github_settings(config: dict[str, Any]) -> dict[str, Any]:
    """Return GitHub ingestion settings."""
    github = config.get("github")
    return github if isinstance(github, dict) else {}


def get_corpus_settings(config: dict[str, Any], mode: str) -> dict[str, list[str]]:
    """Return include/exclude/extensions for the requested ingest mode."""
    if mode not in {"docs", "code", "all"}:
        raise ValueError("mode must be one of: docs, code, all")

    docs = config.get("docs") if isinstance(config.get("docs"), dict) else {}
    source = config.get("source") if isinstance(config.get("source"), dict) else {}

    def values(section: dict[str, Any], key: str) -> list[str]:
        raw = section.get(key) or []
        return [str(item) for item in raw if str(item).strip()]

    docs_include = values(docs, "include_patterns")
    docs_exclude = values(docs, "exclude_patterns")
    docs_ext = values(docs, "extensions")

    source_include = values(source, "include_patterns")
    source_exclude = values(source, "exclude_patterns")
    source_ext = values(source, "extensions")

    if mode == "docs":
        return {
            "include_patterns": docs_include,
            "exclude_patterns": docs_exclude,
            "extensions": docs_ext,
        }
    if mode == "code":
        return {
            "include_patterns": source_include,
            "exclude_patterns": source_exclude,
            "extensions": source_ext,
        }

    return {
        "include_patterns": list(dict.fromkeys(docs_include + source_include)),
        "exclude_patterns": list(dict.fromkeys(docs_exclude + source_exclude)),
        "extensions": list(dict.fromkeys(docs_ext + source_ext)),
    }


def classify_path(rel_path: str, config: dict[str, Any]) -> dict[str, Any]:
    """Classify a repo-relative path using harness rules."""
    if not isinstance(rel_path, str) or not rel_path:
        raise TypeError("classify_path: rel_path must be a non-empty string")

    rules = config.get("classification_rules") or []
    for rule in rules:
        if not isinstance(rule, dict):
            continue
        pattern = rule.get("pattern")
        if not isinstance(pattern, str) or not pattern:
            continue
        if re.search(pattern, rel_path):
            return {
                "source": str(rule.get("source") or "doc"),
                "priority": int(rule.get("priority") or 1),
                "chunker": str(rule.get("chunker") or "text"),
            }

    default_rule = (
        config.get("default_classification")
        if isinstance(config.get("default_classification"), dict)
        else {}
    )
    return {
        "source": str(default_rule.get("source") or "doc"),
        "priority": int(default_rule.get("priority") or 1),
        "chunker": str(default_rule.get("chunker") or "text"),
    }


def pick_github_token(config: dict[str, Any]) -> str | None:
    """Return the first configured GitHub token found in the environment."""
    github = get_github_settings(config)
    env_vars = github.get("token_env_vars") or []
    for env_name in env_vars:
        name = str(env_name).strip()
        if not name:
            continue
        value = os.getenv(name)
        if value:
            return value
    return None
