---
title: "P1: Get Organized"
status: inbox
priority: P1
created: 2026-04-11
updated: 2026-04-11
author: "GitHub Copilot"
goal: "Create a practical repo-organization plan for AI-DDTK that reduces sprawl first and adds semantic retrieval only where it materially improves discovery."
---

<!-- TOC -->

- [Phased Checklist (High-Level Progress)](#phased-checklist-high-level-progress)
- [Overview](#overview)
- [Goals](#goals)
- [Non-Goals](#non-goals)
- [Guiding Principle](#guiding-principle)
- [Phase 0 — Inventory and Classification](#phase-0--inventory-and-classification)
- [Phase 1 — Canonical Structure and Retention Rules](#phase-1--canonical-structure-and-retention-rules)
- [Phase 2 — Build a Repo Metadata Catalog](#phase-2--build-a-repo-metadata-catalog)
- [Phase 3 — Cleanup, Promotion, and Archival Pass](#phase-3--cleanup-promotion-and-archival-pass)
- [Phase 4 — Add Hybrid Retrieval Where It Helps](#phase-4--add-hybrid-retrieval-where-it-helps)
- [Phase 5 — Operating Rhythm and Ownership](#phase-5--operating-rhythm-and-ownership)
- [Success Criteria](#success-criteria)
- [Open Questions](#open-questions)

<!-- /TOC -->

---

## Phased Checklist (High-Level Progress)

> This document should be updated as work is completed. Mark off items immediately rather than batching status updates later.

- [ ] **Phase 0 — Inventory and Classification**
- [ ] **Phase 1 — Canonical Structure and Retention Rules**
- [ ] **Phase 2 — Build a Repo Metadata Catalog**
- [ ] **Phase 3 — Cleanup, Promotion, and Archival Pass**
- [ ] **Phase 4 — Add Hybrid Retrieval Where It Helps**
- [ ] **Phase 5 — Operating Rhythm and Ownership**

## Overview

AI-DDTK has grown into a toolkit repo with code, docs, recipes, project tracking, experiments, generated reports, and operational artifacts. The current problem is not only search. It is lifecycle clarity: what is canonical, what is in progress, what is generated, what is temporary, and what should be archived.

Embeddings can help with discovery, clustering, and semantic lookup across notes, reports, and docs. They do not replace naming rules, retention rules, or folder discipline. This plan treats semantic retrieval as a later layer added on top of a cleaner repo model.

## Goals

- [ ] Reduce ambiguity about where new files belong.
- [ ] Separate source-of-truth files from generated artifacts and temporary outputs.
- [ ] Create a machine-readable catalog of important files and directories.
- [ ] Make cleanup repeatable instead of one-off.
- [ ] Add semantic retrieval only after the repo has usable metadata and folder hygiene.

## Non-Goals

- [ ] Do not redesign the entire repo structure in one pass.
- [ ] Do not build a full knowledge platform before cleanup basics exist.
- [ ] Do not index every file blindly into a vector store.
- [ ] Do not treat generated artifacts as equal to canonical docs or source code.

## Guiding Principle

Organize first, index second.

If the repo lacks clear file lifecycle rules, embeddings will help search the mess without reducing the mess. The right sequence is:

1. Inventory the repo.
2. Classify files by lifecycle and purpose.
3. Clean up and normalize the highest-noise areas.
4. Add metadata-backed discovery.
5. Add hybrid lexical + semantic retrieval where it clearly improves workflow.

## Phase 0 — Inventory and Classification

Purpose: build a factual snapshot of what exists before making structural changes.

### Checklist

- [ ] Generate a repo-wide file inventory using tracked files as the baseline.
- [ ] Break the inventory down by top-level area: `tools/`, `experimental/`, `PROJECT/`, `docs/`, `recipes/`, `templates/`, `test/`, `bin/`, `temp/`.
- [ ] For each area, label files into one of these classes: `canonical-source`, `documentation`, `project-tracking`, `generated-artifact`, `temporary`, `experimental`, `archive-candidate`.
- [ ] Identify the noisiest zones by count and churn, not by intuition.
- [ ] Flag directories that mix multiple lifecycles in one place.
- [ ] Produce a first-pass list of files that are probably duplicated, stale, or misfiled.
- [ ] Record which generated outputs are intentionally checked in versus accidentally lingering.

### Deliverable

- [ ] A first-pass inventory snapshot stored in a machine-readable format such as JSON or CSV.

### Exit Criteria

- [ ] We can answer, with evidence, which parts of the repo are source, working notes, generated output, and probable cleanup targets.

## Phase 1 — Canonical Structure and Retention Rules

Purpose: define what belongs where and how long it should live.

### Checklist

- [ ] Define the canonical purpose of each top-level directory in one sentence.
- [ ] Confirm `PROJECT/` is only for planning, tracking, inbox, working, and done states.
- [ ] Confirm `temp/` is for sensitive and disposable runtime artifacts, not long-term reference docs.
- [ ] Define what qualifies for `experimental/` and what conditions trigger promotion out of it.
- [ ] Define which report outputs belong in-repo versus gitignored runtime storage.
- [ ] Review `.gitignore` coverage for reports, screenshots, scans, auth state, and logs.
- [ ] Write simple retention rules for generated content: keep, archive, or purge.
- [ ] Decide what must always have an owning doc or README in dense directories.

### Deliverable

- [ ] A short policy section or reference doc update that names the lifecycle rules for canonical, experimental, generated, and temporary files.

### Exit Criteria

- [ ] A contributor can decide where a new file belongs without guessing.

## Phase 2 — Build a Repo Metadata Catalog

Purpose: create a lightweight system of record for discovery and cleanup.

### Checklist

- [ ] Define the metadata schema for the catalog.
- [ ] Include at minimum: `path`, `area`, `file_type`, `lifecycle_class`, `owner_tool`, `canonical`, `generated`, `last_modified`, `status`, `notes`.
- [ ] Add optional tags for themes such as `mcp`, `wpcc`, `playwright`, `local-wp`, `query-monitor`, `servers`, `project-doc`.
- [ ] Generate the initial catalog automatically from the repo rather than maintaining it by hand.
- [ ] Add a rule for how manual overrides are stored when auto-detection is wrong.
- [ ] Mark high-value files explicitly as canonical references.
- [ ] Mark low-value files explicitly as cleanup or archive candidates.
- [ ] Decide where the catalog lives and whether it is checked in or regenerated.

### Deliverable

- [ ] A machine-readable catalog that can drive cleanup reports, folder summaries, and later search indexing.

### Exit Criteria

- [ ] We can query the repo by lifecycle and ownership instead of relying only on folder names.

## Phase 3 — Cleanup, Promotion, and Archival Pass

Purpose: reduce noise using the inventory and catalog rather than ad hoc decisions.

### Checklist

- [ ] Triage `PROJECT/1-INBOX` items into active, done, or misc states using existing doc rules.
- [ ] Move finished project docs out of inbox.
- [ ] Review `experimental/` for tools or docs that have effectively graduated.
- [ ] Move obsolete or superseded planning docs to the appropriate archive location instead of leaving duplicates in place.
- [ ] Consolidate duplicate instructions where one doc clearly supersedes another.
- [ ] Remove or archive tracked generated artifacts that do not belong in the main repo surface.
- [ ] Add missing README or index guidance in dense directories only where it reduces ambiguity.
- [ ] Re-run the inventory after cleanup and measure count reduction and clearer classification.

### Deliverable

- [ ] A visibly smaller and more legible repo surface, especially in project-tracking and experimental areas.

### Exit Criteria

- [ ] The highest-noise folders have fewer ambiguous files and clearer ownership.

## Phase 4 — Add Hybrid Retrieval Where It Helps

Purpose: improve discovery after structure exists.

### Checklist

- [ ] Start with hybrid retrieval, not embeddings alone.
- [ ] Use lexical search for exact names, paths, commands, headings, and schema keys.
- [ ] Use embeddings for semantic discovery across docs, reports, changelog entries, project notes, and scan outputs.
- [ ] Index docs and operational artifacts first.
- [ ] Add code chunks only when documentation is insufficient for the target workflow.
- [ ] Exclude binaries, screenshots, lockfiles, auth state, and highly repetitive output unless there is a clear use case.
- [ ] Test real queries against the index before expanding scope.
- [ ] Define success queries such as: “show me all files related to LocalWP auth failures” or “find similar past WPCC performance investigations.”

### Deliverable

- [ ] A narrow, high-signal retrieval layer aimed at discovery and clustering, not as a substitute for repo organization.

### Exit Criteria

- [ ] Semantic lookup answers real questions faster than plain grep without pulling in obvious noise.

## Phase 5 — Operating Rhythm and Ownership

Purpose: keep the repo organized after the first cleanup pass.

### Checklist

- [ ] Assign an owner or review rule for repo hygiene changes.
- [ ] Add a recurring cleanup cadence for inbox, experimental, and generated-output areas.
- [ ] Add a lightweight checklist for “new file acceptance” so artifacts do not accumulate silently.
- [ ] Require new generated-output directories to declare whether they are checked in or gitignored.
- [ ] Review the metadata catalog on a schedule rather than only during cleanup crises.
- [ ] Add a simple report that shows new files by lifecycle class since the last review.
- [ ] Revisit the hybrid index scope after one or two cleanup cycles.

### Deliverable

- [ ] A repeatable maintenance loop that prevents the repo from drifting back into ambiguity.

### Exit Criteria

- [ ] Repo organization becomes an operating habit, not a one-time project.

## Success Criteria

- [ ] The top-level repo areas each have a clear and enforced purpose.
- [ ] New files can be classified quickly as canonical, generated, temporary, experimental, or project-tracking.
- [ ] The noisiest folders have been reduced and normalized.
- [ ] A metadata catalog exists and can be regenerated.
- [ ] Semantic retrieval is scoped to the parts of the repo where it genuinely improves discovery.
- [ ] Contributors can find the right file faster without memorizing tribal knowledge.

## Open Questions

- [ ] Should the metadata catalog live under `PROJECT/`, `tools/`, or a new repo-maintenance location?
- [ ] Which generated artifacts are intentionally committed because they provide durable value?
- [ ] Which `experimental/` items are actually production-grade and just waiting for promotion?
- [ ] Should repo hygiene checks become part of `preflight.sh`, `post-flight.sh`, or a separate maintenance command?
- [ ] Is the first retrieval target this repo alone, or this repo plus neighboring WordPress project artifacts and reports?