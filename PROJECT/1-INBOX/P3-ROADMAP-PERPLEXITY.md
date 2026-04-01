---
title: AI-DDTK Roadmap
status: partially in progress
author: Perplexity -> Claude Code Reviewed and Edited
reviewer: Noel Saw
created: 2026-03-07
updated: 2026-03-09
project: AI-DDTK
category: roadmap
priority: high
source: perplexity
---

# AI‑DDTK Roadmap (Perplexity Draft)

This roadmap reflects an opinionated path to make AI‑DDTK a high‑leverage toolkit for serious WordPress developers and AI‑native teams. [github](https://github.com/Hypercart-Dev-Tools/AI-DDTK)

## Assessment Summary

| # | Item | Effort | New Dev Appeal | Intermediate Appeal | Advanced Appeal |
|---|------|--------|---------------|---------------------|-----------------|
| 1 | Deepen Value for Power Users | High | Low | Med | High |
| 2 | Killer End-to-End Workflow | High | High | High | High |
| 3 | Harden Core Tooling | High | Low | Med | High |
| 4 | Smooth Environment & Setup | **Low–Med** | **High** | Med | Low |
| 5 | Agent-First Design & Docs | Med | Med | Med | High |
| 6 | VS Code & MCP Integration ✅ Complete | **Low** | **High** | **High** | Med |
| 7 | Auth & Browser Automation Polish | Med | High | High | Med |
| 8 | Experimental → Stable Recipes | Low–Med | Med | High | Med |
| 9 | Team Use & Collaboration | Med–High | Low | Med | High |
| 10 | Onboarding & Educational Content | Low–Med | High | Med | Low |

**Completed:** #6 (VS Code & MCP Integration) shipped on 2026-03-09 with repo-tracked VS Code configs, secure MCP HTTP/SSE transport, installer setup, and concise onboarding docs.

---

## 1. Deepen Value for Power Users

AI‑DDTK already targets developers who are comfortable with WP‑CLI, Playwright, and AI agents, so the first priority is to make it an indispensable daily tool for that group. That means optimizing for speed, reliability, and "time to useful output" rather than mass‑market simplicity. Planned work includes tightening the fix‑iterate loop, reducing false positives in scans, and making agent‑driven workflows robust enough to trust on client projects. [github](https://github.com/Hypercart-Dev-Tools)

> **Effort: High** — Touches runtime behavior across multiple tools; requires real-world iteration.
> **Appeal:** Low for new devs (they aren't power users yet), Med for intermediate, High for advanced. This is important long-term but not where to start.

## 2. Killer End‑to‑End Workflow

The project should ship at least one "hero" workflow that feels magical and demo‑worthy from a single command. A concrete target is: from a clean clone and Local site, `wpcc run <project>` plus an AI agent results in a triaged report, GitHub issues, and a PR with proposed fixes and Playwright screenshots. This workflow should be documented with a short screencast and a step‑by‑step recipe so new users can reproduce it within 15–30 minutes on their own plugin or theme. [github](https://github.com/Hypercart-Dev-Tools/WP-Code-Check)

> **Effort: High** — Requires multiple subsystems working together end-to-end; lots of integration polish.
> **Appeal:** High across the board — this is the "wow" moment. But the effort cost means it should come after foundations (#3, #4, #6) are solid.

## 3. Harden Core Tooling (WPCC, Templates, Fix‑Iterate)

WP Code Check, templates, and the fix‑iterate loop are the backbone of AI‑DDTK and should be treated as first‑class, production‑grade components. Near‑term work includes improving `.wpcignore` handling, progress indicators, and timeout behavior so long scans on large repos remain predictable. Template UX should be smoothed so teams can maintain a stable library of project configs that work across branches, forks, and CI environments without constant manual updates. [github](https://github.com/Hypercart-Dev-Tools/WP-Code-Check/issues/112)

> **Effort: High** — Deep, unglamorous infrastructure work with many edge cases.
> **Appeal:** Low for new devs, Med for intermediate, High for advanced. Essential but not a good entry point for adoption.

## 4. Smooth Environment & Setup

The current setup expects Git, Node, Python, Composer, Playwright, WP‑CLI, and Local; this is acceptable for power users but needs to feel streamlined rather than fragile. The roadmap includes improving `install.sh` diagnostics, auto‑detection of common Local setups, and clearer failure messages when prerequisites are missing or misconfigured. A small set of "golden path" environments (e.g., macOS + Homebrew + Local) will be documented and tested end‑to‑end so new contributors can get a green run quickly. [youtube](https://www.youtube.com/watch?v=vi9iRvsqMgM)

> **Effort: Low–Med** — Mostly better error messages and docs; auto-detection adds some complexity.
> **Appeal:** High for new devs (setup is their first experience), Med for intermediate, Low for advanced (they've already gotten past it). Strong runner-up to #6.

## 5. Agent‑First Design & Documentation

AI‑DDTK is explicitly built to be driven by AI coding assistants, so agent‑facing docs and conventions are as important as human‑facing ones. The roadmap includes expanding `AGENTS.md` with more concrete prompts, failure‑mode guidance, and examples of how agents should use temp directories, wpcc templates, and fix‑iterate loops. The goal is for a new agent configuration (Claude, GPT‑based, etc.) to become effective with AI‑DDTK after copying a small set of recommended system instructions and examples. [github](https://github.com/Hypercart-Dev-Tools/AI-DDTK-Fix-Iterate-Loop/issues/7)

> **Effort: Med** — Writing good agent-facing docs requires testing with actual agents and iterating.
> **Appeal:** Med across the board, High for advanced users building agent workflows. Important differentiator but niche.

## 6. VS Code & MCP Integration

> **Status:** Complete on 2026-03-09.

To reduce friction, AI‑DDTK should ship with opinionated but simple integration snippets for VS Code tasks, launch configs, and MCP server tooling. This includes sample `tasks.json` entries for common commands (`wpcc run`, `pw-auth login`, AJAX tests) and minimal guidance on wiring those into AI agents so devs can trigger workflows from their editor. Where possible, the toolkit should aim for "open folder, accept suggested tasks, run one command" as the default experience for new projects. [caseywest](https://caseywest.com/ai-driven-development-modernizing-a-decade-old-website-in-3-days)

> **Effort: Low** — Sample JSON files, a few launch configs, and short docs. No new runtime code.
> **Appeal:** High for new devs (removes CLI intimidation), High for intermediate (productivity boost), Med for advanced. This shipped as a strong starting-point improvement because it had low effort, broad reach, and made the rest of the roadmap easier to adopt. It's also inherently demo-worthy, feeding back into #2 and #10.

## 7. Authentication & Browser Automation Polish

`pw-auth` and Playwright integration already solve a real pain point around logging into wp‑admin in tests, but they can be made more turnkey. Planned improvements include clearer status output, better handling of environment types, and ready‑to‑use Playwright test templates that demonstrate admin flows, AJAX requests, and basic visual regression using PixelMatch. The objective is for a user to move from "no Playwright tests" to "smoke tests with reliable admin login" in a single short session. [wpmayor](https://wpmayor.com/best-wordpress-web-development-ai/)

> **Effort: Med** — Involves Playwright test templates and environment detection logic.
> **Appeal:** High for new and intermediate devs (solves a real pain point), Med for advanced. Good second project after #6.

## 8. Experimental Workflows → Stable Recipes

The `experimental/` directory is a good incubator, but promising scripts like `theme-crash-loop.sh` should graduate into documented recipes once validated. The roadmap includes a lightweight promotion process: try on 2–3 real projects, capture gotchas, then rewrite as a stable recipe (with flags and guardrails) and add it to `recipes/` with a short HOWTO. Over time, this should form a curated library of workflows (crash loops, performance baselines, upgrade audits) that teams can rely on instead of ad‑hoc shell snippets. [github](https://github.com/Hypercart-Dev-Tools/WP-DB-Toolkit/blob/main/CHANGELOG.md)

> **Effort: Low–Med** — Mostly curation and documentation of existing code; some refactoring for flags/guardrails.
> **Appeal:** Med for new devs, High for intermediate (ready-made solutions), Med for advanced. Good ongoing process rather than a one-time project.

## 9. Team Use & Collaboration Features

As AI‑DDTK becomes central to a team's workflow, collaboration and repeatability matter more than individual productivity hacks. Roadmap items here include conventions for committing templates and configs, recommended directory layouts for reports, and patterns for integrating with GitHub issues, Jira, Linear, or Asana via exported artifacts. The aim is that any team member (or agent) can run the same command and get comparable outputs, regardless of local machine quirks. [github](https://github.com/Hypercart-Dev-Tools/AI-DDTK)

> **Effort: Med–High** — Involves conventions, integrations, and cross-environment consistency testing.
> **Appeal:** Low for new devs (solo users), Med for intermediate, High for advanced/team leads. Important but premature until the core toolkit is stable (#3).

## 10. Onboarding & Educational Content

Finally, the project needs lightweight, focused content that shows "why this exists" and "what problems it solves" without overwhelming new users. Short recipes, copy‑pastable commands, and one or two opinionated tutorials (e.g., "hardening a WooCommerce plugin with WPCC + fix‑iterate") will help developers understand when AI‑DDTK is worth adopting. This content should live alongside the code (in `recipes/` and docs) and be kept up to date as the toolkit evolves. [github](https://github.com/Hypercart-Dev-Tools)

> **Effort: Low–Med** — Writing and maintaining tutorials; no code changes needed.
> **Appeal:** High for new devs (entry point), Med for intermediate, Low for advanced. Strong complement to #6 — the integration gets them in, the content keeps them.

***
