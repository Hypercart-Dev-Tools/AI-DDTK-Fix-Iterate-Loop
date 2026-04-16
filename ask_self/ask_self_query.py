"""Python query path for the ask-self RAG scaffold."""

from __future__ import annotations

import argparse
import array
import json
import os
import re
import sqlite3
from pathlib import Path
from typing import Any

import requests

try:
    from ask_self_harness import (
        DEFAULT_HARNESS_PATH,
        REPO_ROOT,
        get_harness_repo_root,
        get_default_db_path,
        get_ingest_command,
        load_runtime_env,
        get_repo_slug,
        get_system_instructions_path,
        get_repo_label,
        get_tenancy_env_var,
        load_harness_config,
    )
    from ask_self_registry import DEFAULT_REGISTRY_PATH, list_registry_entries
    from ask_self_helpers import format_context
except ImportError:  # pragma: no cover - package import path
    from .ask_self_harness import (
        DEFAULT_HARNESS_PATH,
        REPO_ROOT,
        get_harness_repo_root,
        get_default_db_path,
        get_ingest_command,
        load_runtime_env,
        get_repo_slug,
        get_system_instructions_path,
        get_repo_label,
        get_tenancy_env_var,
        load_harness_config,
    )
    from .ask_self_registry import DEFAULT_REGISTRY_PATH, list_registry_entries
    from .ask_self_helpers import format_context

EMBED_MODEL = "gemini-embedding-001"
EMBED_DIM = 768
SYNTHESIS_MODEL = "gemini-pro-latest"
TOP_K = 20
PRIORITY_BOOST = 0.02
MAX_CONTEXT_CHARS = 80000
SYNTHESIS_RESPONSE_SCHEMA: dict[str, Any] = {
    "type": "OBJECT",
    "required": [
        "answer",
        "supporting_evidence",
        "caveats",
        "question_assessment",
        "better_question",
        "why_this_is_better",
    ],
    "properties": {
        "answer": {"type": "STRING"},
        "supporting_evidence": {"type": "ARRAY", "items": {"type": "STRING"}},
        "caveats": {"type": "ARRAY", "items": {"type": "STRING"}},
        "question_assessment": {
            "type": "OBJECT",
            "required": ["status", "reason"],
            "properties": {
                "status": {
                    "type": "STRING",
                    "enum": [
                        "clear",
                        "needs_clarification",
                        "too_broad",
                        "too_vague",
                        "underspecified",
                    ],
                },
                "reason": {"type": "STRING"},
            },
        },
        "better_question": {"type": "STRING"},
        "why_this_is_better": {"type": "STRING"},
    },
}

DEFAULT_HARNESS = load_harness_config(DEFAULT_HARNESS_PATH)
DEFAULT_HARNESS_ROOT = get_harness_repo_root(DEFAULT_HARNESS, fallback_repo_root=REPO_ROOT)
DEFAULT_DB_PATH = get_default_db_path(DEFAULT_HARNESS, repo_root=DEFAULT_HARNESS_ROOT)
DEFAULT_SYSTEM_INSTRUCTIONS_PATH = get_system_instructions_path(
    DEFAULT_HARNESS,
    repo_root=DEFAULT_HARNESS_ROOT,
)

_DB_CONN: sqlite3.Connection | None = None
_DB_PATH: Path | None = None
_SYSTEM_INSTRUCTIONS: dict[str, Any] | None = None
_SYSTEM_INSTRUCTIONS_PATH: Path | None = None


class TenancyError(RuntimeError):
    """Raised when optional tenancy checks fail."""


def _vector_to_blob(values: list[float]) -> bytes:
    return array.array("f", values).tobytes()


def _get_db(db_path: Path, *, ingest_command: str) -> sqlite3.Connection:
    global _DB_CONN, _DB_PATH

    resolved_path = db_path.resolve()
    if _DB_CONN is not None and _DB_PATH == resolved_path:
        return _DB_CONN

    if _DB_CONN is not None:
        _DB_CONN.close()
        _DB_CONN = None
        _DB_PATH = None

    if not resolved_path.exists():
        raise RuntimeError(f"RAG index missing at {resolved_path}. Run: {ingest_command}")

    import sqlite_vec

    conn = sqlite3.connect(str(resolved_path))
    conn.row_factory = sqlite3.Row
    conn.enable_load_extension(True)
    sqlite_vec.load(conn)
    _DB_CONN = conn
    _DB_PATH = resolved_path
    return conn


def _get_system_instructions(system_instructions_path: Path) -> dict[str, Any]:
    global _SYSTEM_INSTRUCTIONS, _SYSTEM_INSTRUCTIONS_PATH

    resolved_path = system_instructions_path.resolve()
    if _SYSTEM_INSTRUCTIONS is not None and _SYSTEM_INSTRUCTIONS_PATH == resolved_path:
        return _SYSTEM_INSTRUCTIONS

    with resolved_path.open("r", encoding="utf-8") as fh:
        _SYSTEM_INSTRUCTIONS = json.load(fh)
    _SYSTEM_INSTRUCTIONS_PATH = resolved_path
    return _SYSTEM_INSTRUCTIONS


def _normalize_text_list(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    if isinstance(value, str) and value.strip():
        return [value.strip()]
    return []


def _normalize_target_slugs(
    targets: list[str] | None = None,
    targets_csv: str | None = None,
) -> list[str]:
    values: list[str] = []
    for item in targets or []:
        text = str(item).strip()
        if text:
            values.append(text)
    if isinstance(targets_csv, str) and targets_csv.strip():
        for item in targets_csv.split(","):
            text = item.strip()
            if text:
                values.append(text)
    deduped: list[str] = []
    for value in values:
        if value not in deduped:
            deduped.append(value)
    return deduped


def _build_system_instruction(instructions: dict[str, Any]) -> str:
    layers = instructions.get("system_layers")
    if isinstance(layers, dict):
        ordered_keys = (
            "base_system",
            "repo_context_system",
            "answer_style_system",
            "question_quality_system",
            "query_improvement_system",
        )
        parts = [str(layers[key]).strip() for key in ordered_keys if str(layers.get(key) or "").strip()]

        response_contract = instructions.get("response_contract")
        if isinstance(response_contract, dict):
            parts.append(
                "Return valid JSON only with these top-level keys: "
                "answer, supporting_evidence, caveats, question_assessment, "
                "better_question, why_this_is_better."
            )
            parts.append(
                "question_assessment must be an object with keys: status and reason. "
                "Allowed status values: clear, needs_clarification, too_broad, too_vague, underspecified."
            )
            parts.append(
                "If the original question is already clear, set better_question and "
                "why_this_is_better to empty strings."
            )
        return "\n\n".join(part for part in parts if part)

    legacy_prompt = instructions.get("orchestrator_system")
    if isinstance(legacy_prompt, str) and legacy_prompt.strip():
        return legacy_prompt.strip()
    raise RuntimeError("System instructions are missing a usable synthesis prompt")


def _extract_json_object(text: str) -> str:
    stripped = text.strip()
    if stripped.startswith("{") and stripped.endswith("}"):
        return stripped

    fenced = re.search(r"```(?:json)?\s*(\{.*\})\s*```", stripped, flags=re.S)
    if fenced:
        return fenced.group(1).strip()

    start = stripped.find("{")
    end = stripped.rfind("}")
    if start != -1 and end != -1 and end > start:
        return stripped[start : end + 1]
    return stripped


def _normalize_structured_answer(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        return {
            "answer": str(payload).strip(),
            "supporting_evidence": [],
            "caveats": [],
            "question_assessment": {"status": "clear", "reason": ""},
            "better_question": "",
            "why_this_is_better": "",
        }

    assessment = payload.get("question_assessment")
    if not isinstance(assessment, dict):
        assessment = {}

    status = str(assessment.get("status") or "clear").strip() or "clear"
    reason = str(assessment.get("reason") or "").strip()

    return {
        "answer": str(payload.get("answer") or "").strip(),
        "supporting_evidence": _normalize_text_list(payload.get("supporting_evidence")),
        "caveats": _normalize_text_list(payload.get("caveats")),
        "question_assessment": {
            "status": status,
            "reason": reason,
        },
        "better_question": str(payload.get("better_question") or "").strip(),
        "why_this_is_better": str(payload.get("why_this_is_better") or "").strip(),
    }


def _recover_partial_json_payload(text: str) -> dict[str, Any]:
    payload: dict[str, Any] = {}
    compact = text.strip()

    answer_match = re.search(
        r'"answer"\s*:\s*"(.*?)"\s*,\s*"supporting_evidence"',
        compact,
        flags=re.S,
    )
    if answer_match:
        try:
            payload["answer"] = json.loads(f'"{answer_match.group(1)}"')
        except json.JSONDecodeError:
            payload["answer"] = answer_match.group(1).replace('\\"', '"').strip()

    status_match = re.search(r'"status"\s*:\s*"([^"]+)"', compact)
    reason_match = re.search(r'"reason"\s*:\s*"(.*?)"\s*[,}]', compact, flags=re.S)
    if status_match or reason_match:
        reason = ""
        if reason_match:
            try:
                reason = json.loads(f'"{reason_match.group(1)}"')
            except json.JSONDecodeError:
                reason = reason_match.group(1).replace('\\"', '"').strip()
        payload["question_assessment"] = {
            "status": status_match.group(1).strip() if status_match else "clear",
            "reason": reason,
        }

    better_question_match = re.search(
        r'"better_question"\s*:\s*"(.*?)"\s*,\s*"why_this_is_better"',
        compact,
        flags=re.S,
    )
    if better_question_match:
        try:
            payload["better_question"] = json.loads(f'"{better_question_match.group(1)}"')
        except json.JSONDecodeError:
            payload["better_question"] = better_question_match.group(1).replace('\\"', '"').strip()

    why_match = re.search(r'"why_this_is_better"\s*:\s*"(.*?)"\s*[,}]', compact, flags=re.S)
    if why_match:
        try:
            payload["why_this_is_better"] = json.loads(f'"{why_match.group(1)}"')
        except json.JSONDecodeError:
            payload["why_this_is_better"] = why_match.group(1).replace('\\"', '"').strip()

    return payload


def _render_structured_answer(payload: dict[str, Any], source_list: list[str]) -> str:
    parts: list[str] = []
    answer = str(payload.get("answer") or "").strip()
    if answer:
        parts.append(answer)

    supporting_evidence = _normalize_text_list(payload.get("supporting_evidence"))
    if supporting_evidence:
        parts.append(
            "Supporting evidence:\n" + "\n".join(f"- {item}" for item in supporting_evidence)
        )

    caveats = _normalize_text_list(payload.get("caveats"))
    if caveats:
        parts.append("Caveats:\n" + "\n".join(f"- {item}" for item in caveats))

    assessment = payload.get("question_assessment")
    if isinstance(assessment, dict):
        status = str(assessment.get("status") or "").strip()
        reason = str(assessment.get("reason") or "").strip()
        if status and status != "clear":
            assessment_block = f"Question assessment: {status}"
            if reason:
                assessment_block += f" - {reason}"
            parts.append(assessment_block)

    better_question = str(payload.get("better_question") or "").strip()
    why_better = str(payload.get("why_this_is_better") or "").strip()
    if better_question:
        improvement_block = f"Suggested better question: {better_question}"
        if why_better:
            improvement_block += f"\nWhy this is better: {why_better}"
        parts.append(improvement_block)

    if source_list:
        parts.append(f"Sources consulted: {', '.join(source_list)}")

    return "\n\n".join(part for part in parts if part)


def _question_quality_hint(query: str) -> str:
    lower = query.lower()
    words = re.findall(r"[a-z0-9']+", lower)
    if not words:
        return ""

    ambiguous_terms = {"this", "that", "it", "these", "those"}
    if len(words) <= 6 and any(term in ambiguous_terms for term in words):
        return (
            "Question quality hint: the question uses an ambiguous pronoun without "
            "clearly naming the subject. Unless the retrieved context makes the intent "
            "unmistakable, mark it as underspecified and suggest a better question."
        )
    if len(words) <= 4:
        return (
            "Question quality hint: the question is very short. If the intent or scope "
            "is not explicit, mark it as too vague or underspecified and suggest a "
            "better question."
        )
    return ""


def _generate_synthesis_text(
    *,
    query: str,
    context: str,
    system_prompt: str,
    api_key: str,
    repo_label: str,
    repair_mode: bool = False,
) -> str:
    quality_hint = _question_quality_hint(query)
    user_message = (
        f"CONTEXT (retrieved from the {repo_label} corpus):\n\n"
        f"{context}\n\n---\n\nQUESTION: {query}"
    )
    if quality_hint:
        user_message += f"\n\n{quality_hint}"
    if repair_mode:
        user_message += (
            "\n\nReturn compact JSON only. Keep answer under 120 words. "
            "Use at most 3 supporting_evidence bullets and 2 caveats."
        )

    payload = {
        "system_instruction": {"parts": [{"text": system_prompt}]},
        "contents": [{"role": "user", "parts": [{"text": user_message}]}],
        "generationConfig": {
            "temperature": 0.3,
            "maxOutputTokens": 1500,
            "responseMimeType": "application/json",
            "responseSchema": SYNTHESIS_RESPONSE_SCHEMA,
        },
    }
    resp = requests.post(
        (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"{SYNTHESIS_MODEL}:generateContent?key={api_key}"
        ),
        json=payload,
        timeout=90,
    )
    if not resp.ok:
        raise RuntimeError(f"Gemini synthesis {resp.status_code}: {resp.text[:300]}")

    data = resp.json()
    candidates = data.get("candidates") or []
    if not candidates:
        raise RuntimeError("Gemini synthesis: empty response")
    parts = ((candidates[0].get("content") or {}).get("parts") or [])
    text = parts[0].get("text") if parts else None
    if not text:
        raise RuntimeError("Gemini synthesis: empty response")
    return text


def _apply_question_quality_fallback(
    payload: dict[str, Any],
    *,
    query: str,
    repo_label: str,
) -> dict[str, Any]:
    quality_hint = _question_quality_hint(query)
    assessment = payload.get("question_assessment")
    if not quality_hint or not isinstance(assessment, dict):
        return payload

    status = str(assessment.get("status") or "").strip()
    better_question = str(payload.get("better_question") or "").strip()
    if status and status != "clear" and better_question:
        return payload

    payload["question_assessment"] = {
        "status": "underspecified",
        "reason": "The question is ambiguous or too short to identify a precise subject and scope.",
    }
    if not better_question:
        payload["better_question"] = (
            f"What specific part of {repo_label} should we improve next, and what "
            "outcome are we optimizing for?"
        )
    if not str(payload.get("why_this_is_better") or "").strip():
        payload["why_this_is_better"] = (
            "It names the subject explicitly and adds decision criteria, which makes "
            "the answer more actionable."
        )
    return payload


def assert_tenancy(team_id: str | None, harness_config: dict[str, Any]) -> None:
    """Optional tenant gate. If allowlist is unset, gate is disabled."""
    env_var = get_tenancy_env_var(harness_config)
    allowed = os.getenv(env_var)
    if not allowed:
        return
    if not team_id:
        raise TenancyError(f"team_id argument required when {env_var} is set")
    if team_id != allowed:
        raise TenancyError("team_id does not match allowlist")


def embed_query(query: str, api_key: str) -> bytes:
    endpoint = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{EMBED_MODEL}:embedContent?key={api_key}"
    )
    payload = {
        "model": f"models/{EMBED_MODEL}",
        "content": {"parts": [{"text": query}]},
        "taskType": "RETRIEVAL_QUERY",
        "outputDimensionality": EMBED_DIM,
    }
    resp = requests.post(endpoint, json=payload, timeout=60)
    if not resp.ok:
        raise RuntimeError(f"Gemini embed {resp.status_code}: {resp.text[:300]}")

    data = resp.json()
    values = (data.get("embedding") or {}).get("values")
    if not isinstance(values, list) or len(values) != EMBED_DIM:
        got = len(values) if isinstance(values, list) else None
        raise RuntimeError(f"Gemini embed: unexpected shape, got {got} dims")
    return _vector_to_blob(values)


def knn_search(conn: sqlite3.Connection, query_vec: bytes, k: int = TOP_K) -> list[dict[str, Any]]:
    hits = conn.execute(
        "SELECT rowid, distance FROM chunks_vec WHERE embedding MATCH ? ORDER BY distance LIMIT ?",
        (query_vec, int(k)),
    ).fetchall()
    if not hits:
        return []

    ids = [int(hit["rowid"]) for hit in hits]
    placeholders = ",".join("?" for _ in ids)
    rows = conn.execute(
        (
            "SELECT id, source, path, pr_number, version, priority, content "
            f"FROM chunks WHERE id IN ({placeholders})"
        ),
        ids,
    ).fetchall()
    by_id = {int(row["id"]): dict(row) for row in rows}

    dropped: list[int] = []
    ranked: list[dict[str, Any]] = []
    for hit in hits:
        rowid = int(hit["rowid"])
        row = by_id.get(rowid)
        if row is None:
            dropped.append(rowid)
            continue
        score = float(hit["distance"]) - float(row.get("priority", 1) or 1) * PRIORITY_BOOST
        row["distance"] = float(hit["distance"])
        row["score"] = score
        ranked.append(row)

    if dropped:
        print(
            "[self-ask] knn_search: dropped"
            f" {len(dropped)} hit(s) with missing metadata rows"
            f" (rowids: {', '.join(str(x) for x in dropped)}).",
            flush=True,
        )

    ranked.sort(key=lambda item: item["score"])
    return ranked


def _resolve_selected_targets(
    *,
    harness_config: dict[str, Any],
    repo_root: Path,
    db_path: Path | None,
    registry_path: Path | None,
    target_slugs: list[str],
    all_targets: bool,
    ingest_command: str,
) -> list[dict[str, Any]]:
    if db_path is not None and (target_slugs or all_targets):
        raise ValueError("Cannot combine --db-path with --target/--targets/--all-targets")

    if target_slugs or all_targets:
        registry_entries = list_registry_entries(registry_path or DEFAULT_REGISTRY_PATH)
        if not registry_entries:
            raise RuntimeError("ask_self registry is empty. Ingest a repo first or pass --db-path.")

        entry_map = {str(entry.get("slug") or ""): entry for entry in registry_entries}
        if all_targets:
            selected = registry_entries
        else:
            missing = [slug for slug in target_slugs if slug not in entry_map]
            if missing:
                raise RuntimeError(
                    "Unknown ask_self target slug(s): " + ", ".join(missing)
                )
            selected = [entry_map[slug] for slug in target_slugs]

        normalized: list[dict[str, Any]] = []
        for entry in selected:
            entry_embed_model = str(entry.get("embed_model") or "")
            entry_embed_dim = int(entry.get("embed_dim") or 0)
            if entry_embed_model != EMBED_MODEL or entry_embed_dim != EMBED_DIM:
                raise RuntimeError(
                    "Registry target "
                    f"{entry.get('slug')} uses incompatible embeddings "
                    f"({entry_embed_model}/{entry_embed_dim}); expected {EMBED_MODEL}/{EMBED_DIM}"
                )

            normalized.append(
                {
                    "slug": str(entry.get("slug") or ""),
                    "repo_label": str(entry.get("repo_label") or entry.get("slug") or "repository"),
                    "repo_root": str(entry.get("repo_root") or ""),
                    "db_path": Path(str(entry.get("db_path") or "")).expanduser().resolve(),
                    "ingest_command": str(entry.get("ingest_command") or ingest_command),
                }
            )
        return normalized

    return [
        {
            "slug": get_repo_slug(harness_config, repo_root=repo_root),
            "repo_label": get_repo_label(harness_config),
            "repo_root": str(repo_root.resolve()),
            "db_path": (db_path or get_default_db_path(harness_config, repo_root=repo_root)).resolve(),
            "ingest_command": ingest_command,
        }
    ]


def _search_targets(
    *,
    query_vec: bytes,
    targets: list[dict[str, Any]],
    top_k: int = TOP_K,
) -> list[dict[str, Any]]:
    ranked: list[dict[str, Any]] = []
    for target in targets:
        conn = _get_db(Path(target["db_path"]), ingest_command=str(target["ingest_command"]))
        hits = knn_search(conn, query_vec, top_k)
        for hit in hits:
            hit["repo_label"] = str(target["repo_label"])
            hit["target_slug"] = str(target["slug"])
            hit["target_repo_root"] = str(target["repo_root"])
            hit["target_db_path"] = str(target["db_path"])
        ranked.extend(hits)
    ranked.sort(key=lambda item: float(item.get("score") or 0.0))
    return ranked[:top_k]


def synthesize(
    query: str,
    context: str,
    system_prompt: str,
    api_key: str,
    *,
    repo_label: str,
) -> dict[str, Any]:
    text = _generate_synthesis_text(
        query=query,
        context=context,
        system_prompt=system_prompt,
        api_key=api_key,
        repo_label=repo_label,
    )
    try:
        structured = json.loads(_extract_json_object(text))
    except json.JSONDecodeError:
        repair_text = _generate_synthesis_text(
            query=query,
            context=context,
            system_prompt=system_prompt,
            api_key=api_key,
            repo_label=repo_label,
            repair_mode=True,
        )
        try:
            structured = json.loads(_extract_json_object(repair_text))
        except json.JSONDecodeError:
            structured = _recover_partial_json_payload(repair_text) or {"answer": repair_text}
    payload = _normalize_structured_answer(structured)
    return _apply_question_quality_fallback(payload, query=query, repo_label=repo_label)


def ask_self_structured(
    query: str,
    *,
    team_id: str | None = None,
    repo_root: Path | None = None,
    db_path: Path | None = None,
    registry_path: Path | None = None,
    system_instructions_path: Path | None = None,
    targets: list[str] | None = None,
    targets_csv: str | None = None,
    all_targets: bool = False,
    harness_config_path: Path = DEFAULT_HARNESS_PATH,
) -> dict[str, Any]:
    """Answer a repo question and return structured synthesis metadata."""
    if not isinstance(query, str) or not query.strip():
        raise ValueError("query must be a non-empty string")

    harness_config = load_harness_config(harness_config_path)
    resolved_repo_root = repo_root or get_harness_repo_root(
        harness_config,
        fallback_repo_root=REPO_ROOT,
    )
    load_runtime_env(harness_config, repo_root=resolved_repo_root)
    repo_label = get_repo_label(harness_config)
    ingest_command = get_ingest_command(harness_config)
    resolved_system_instructions_path = system_instructions_path or get_system_instructions_path(
        harness_config,
        repo_root=resolved_repo_root,
    )

    assert_tenancy(team_id, harness_config)

    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        raise RuntimeError("GOOGLE_API_KEY not set")

    instructions = _get_system_instructions(resolved_system_instructions_path)
    system_prompt = _build_system_instruction(instructions)
    query_vec = embed_query(query, api_key)
    selected_targets = _resolve_selected_targets(
        harness_config=harness_config,
        repo_root=resolved_repo_root,
        db_path=db_path,
        registry_path=registry_path,
        target_slugs=_normalize_target_slugs(targets, targets_csv),
        all_targets=all_targets,
        ingest_command=ingest_command,
    )
    hits = _search_targets(query_vec=query_vec, targets=selected_targets, top_k=TOP_K)
    if not hits:
        payload = _normalize_structured_answer(
            {"answer": "I could not find anything in the local index for that question."}
        )
        payload["sources_consulted"] = []
        payload["rendered_answer"] = payload["answer"]
        return payload

    context = format_context(hits, MAX_CONTEXT_CHARS)
    consulted_labels = [str(target["repo_label"]) for target in selected_targets if str(target["repo_label"]).strip()]
    corpus_label = consulted_labels[0] if len(consulted_labels) == 1 else "selected repositories"
    payload = synthesize(query, context, system_prompt, api_key, repo_label=corpus_label)
    source_list: list[str] = []
    for hit in hits[:8]:
        source_label = (
            f"PR #{hit.get('pr_number')}"
            if hit.get("source") == "pr"
            else (hit.get("path") or "unknown")
        )
        target_label = str(hit.get("repo_label") or "").strip()
        label = f"{target_label}: {source_label}" if target_label else source_label
        if label not in source_list:
            source_list.append(label)

    payload["targets_consulted"] = [
        {
            "slug": str(target["slug"]),
            "repo_label": str(target["repo_label"]),
            "db_path": str(target["db_path"]),
        }
        for target in selected_targets
    ]
    payload["sources_consulted"] = source_list
    payload["rendered_answer"] = _render_structured_answer(payload, source_list)
    return payload


def ask_self(
    query: str,
    *,
    team_id: str | None = None,
    repo_root: Path | None = None,
    db_path: Path | None = None,
    registry_path: Path | None = None,
    system_instructions_path: Path | None = None,
    targets: list[str] | None = None,
    targets_csv: str | None = None,
    all_targets: bool = False,
    harness_config_path: Path = DEFAULT_HARNESS_PATH,
) -> str:
    """Answer a repo question grounded in the local self-ask index."""
    payload = ask_self_structured(
        query,
        team_id=team_id,
        repo_root=repo_root,
        db_path=db_path,
        registry_path=registry_path,
        system_instructions_path=system_instructions_path,
        targets=targets,
        targets_csv=targets_csv,
        all_targets=all_targets,
        harness_config_path=harness_config_path,
    )
    return str(payload.get("rendered_answer") or payload.get("answer") or "")


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Query the local ask-self index")
    parser.add_argument("query", help="Question to ask against the local corpus")
    parser.add_argument("--team-id", default=None, help="Optional team id for allowlist checks")
    parser.add_argument(
        "--repo-root",
        default=None,
        help="Repo root for env, DB, and prompt resolution (defaults to the harness-inferred repo root)",
    )
    parser.add_argument(
        "--registry-path",
        default=None,
        help=f"ask_self registry JSON path (defaults to {DEFAULT_REGISTRY_PATH})",
    )
    parser.add_argument(
        "--db-path",
        default=None,
        help="Path to sqlite self-ask DB (defaults to the harness-defined path)",
    )
    parser.add_argument(
        "--target",
        action="append",
        dest="targets",
        default=None,
        help="Registry target slug to query (repeatable)",
    )
    parser.add_argument(
        "--targets",
        dest="targets_csv",
        default=None,
        help="Comma-separated registry target slugs to query",
    )
    parser.add_argument(
        "--all-targets",
        action="store_true",
        help="Query every compatible DB in the ask_self registry",
    )
    parser.add_argument(
        "--system-instructions-path",
        "--prompts-path",
        dest="system_instructions_path",
        default=None,
        help="Path to the system instructions JSON (defaults to the harness-defined path)",
    )
    parser.add_argument(
        "--harness-config",
        default=str(DEFAULT_HARNESS_PATH),
        help="Path to repo-specific harness JSON",
    )
    parser.add_argument("--json", action="store_true", help="Emit structured JSON output")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    try:
        payload = ask_self_structured(
            args.query,
            team_id=args.team_id,
            repo_root=Path(args.repo_root) if args.repo_root else None,
            db_path=Path(args.db_path) if args.db_path else None,
            registry_path=Path(args.registry_path) if args.registry_path else None,
            system_instructions_path=(
                Path(args.system_instructions_path) if args.system_instructions_path else None
            ),
            targets=args.targets,
            targets_csv=args.targets_csv,
            all_targets=bool(args.all_targets),
            harness_config_path=Path(args.harness_config),
        )
    except Exception as exc:  # noqa: BLE001
        if args.json:
            print(json.dumps({"ok": False, "error": str(exc)}))
        else:
            print(f"ERROR: {exc}")
        return 1

    if args.json:
        print(json.dumps({"ok": True, **payload}, ensure_ascii=False))
    else:
        print(payload["rendered_answer"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
