# WPCC + ask_self + AI-DDTK Integration Architecture

## System Diagram

Use this diagram as a prompt for a design tool or general-purpose LLM to produce
a marketing-ready visual. All labels, data flows, and groupings are accurate to
the current and planned architecture.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                                                                 │
│                          AI-DDTK  (Orchestration Layer)                         │
│                                                                                 │
│   ┌───────────────────────────────────────────────────────────────────────────┐  │
│   │                     Fix-Iterate Loop Controller                          │  │
│   │                                                                          │  │
│   │   Guardrails: 5 failed iterations → stop · 10 total → stop              │  │
│   │               confidence trending down → stop · ASK_HUMAN on risk       │  │
│   └───────────────────────────────┬───────────────────────────────────────────┘  │
│                                   │                                              │
│                                   │ orchestrates                                 │
│                                   ▼                                              │
│   ┌─────────────────── Step 1: Write/Modify Code ──────────────────────────┐    │
│   │                     VS Code AI Agent                                    │    │
│   │              (Claude Code · Copilot · Cursor · etc.)                    │    │
│   └─────────────────────────────┬───────────────────────────────────────────┘    │
│                                 │                                                │
│                                 │ feeds diff / changed files                     │
│                                 ▼                                                │
│   ┌─────────────────── Step 2: Static Analysis ────────────────────────────┐    │
│   │                        (run in parallel)                                │    │
│   │                                                                         │    │
│   │   ┌─────────────────────┐     ┌──────────────────────┐                  │    │
│   │   │   WPCC Scanner      │     │   PHP-Parser AST     │                  │    │
│   │   │                     │     │                      │                  │    │
│   │   │  ┌───────────────┐  │     │  ┌────────────────┐  │                  │    │
│   │   │  │ grep patterns │  │     │  │ Return shapes  │  │                  │    │
│   │   │  │ (54 rules)    │  │     │  │ Contract checks│  │                  │    │
│   │   │  └───────────────┘  │     │  │ Hook arg count │  │                  │    │
│   │   │  ┌───────────────┐  │     │  │ Priority clash │  │                  │    │
│   │   │  │ Semgrep rules │  │     │  │ Fire arg count │  │                  │    │
│   │   │  │ (pilot, opt.) │  │     │  │ Hook inventory │  │                  │    │
│   │   │  └───────────────┘  │     │  └────────────────┘  │                  │    │
│   │   │                     │     │                      │                  │    │
│   │   │  check-performance  │     │  wpcc-ast-check.php  │                  │    │
│   │   │  .sh                │     └──────────────────────┘                  │    │
│   │   └─────────────────────┘                                               │    │
│   │                                Findings:                                 │    │
│   │   Findings:                    · missing return keys                     │    │
│   │   · security patterns          · shape mismatches                        │    │
│   │   · performance anti-patterns  · hook arg mismatches                     │    │
│   │   · unbounded queries          · priority conflicts                      │    │
│   │   Findings:                                                              │    │
│   │   · security patterns        ◄── violations? → fix, loop to Step 1      │    │
│   │   · performance anti-patterns                                            │    │
│   │   · unbounded queries                                                    │    │
│   └─────────────────────────────┬───────────────────────────────────────────┘    │
│                                 │                                                │
│                                 │ passes if clean                                │
│                                 ▼                                                │
│   ┌─────────────────── Step 3: Semantic Review ────────────────────────────┐    │
│   │                                                                         │    │
│   │                    ┌───────────────────────────────┐                     │    │
│   │                    │        ask_self RAG           │                     │    │
│   │                    │                               │                     │    │
│   │                    │  ┌─────────────────────────┐  │                     │    │
│   │                    │  │  sqlite-vec index       │  │                     │    │
│   │                    │  │  (source + docs + PRs   │  │                     │    │
│   │                    │  │   + AST metadata        │  │                     │    │
│   │                    │  │   + QM profiles)        │  │                     │    │
│   │                    │  └─────────────────────────┘  │                     │    │
│   │                    │                               │                     │    │
│   │                    │  Modes:                       │                     │    │
│   │                    │  · Q&A (freeform questions)   │                     │    │
│   │                    │  · Review (diff → verdict)    │                     │    │
│   │                    │  · Enrichment (finding →      │                     │    │
│   │                    │    repo-grounded context)     │                     │    │
│   │                    └───────────────────────────────┘                     │    │
│   │                                                                         │    │
│   │   Checks:                    Returns:                                    │    │
│   │   · DRY violations           · structured verdict                        │    │
│   │   · SOLID principles         · evidence from indexed codebase            │    │
│   │   · repo conventions         · suggested fixes grounded in existing code │    │
│   │                                                                         │    │
│   │                              ◄── violations? → fix, loop to Step 1      │    │
│   └─────────────────────────────┬───────────────────────────────────────────┘    │
│                                 │                                                │
│                                 │ passes if clean                                │
│                                 ▼                                                │
│   ┌─────────────────── Step 4: Runtime Verification (optional) ────────────┐    │
│   │                        (requires running WP site)                       │    │
│   │                                                                         │    │
│   │   ┌───────────────────────────────────────────────────────────────────┐  │    │
│   │   │   Playwright + Passwordless Login (pw_auth)                      │  │    │
│   │   │                                                                   │  │    │
│   │   │   mu-plugin auto-login · no credentials in agent context         │  │    │
│   │   │   Authenticated page loads at near-manual-operator quality        │  │    │
│   │   │   Drives all runtime tools below (QM, HookTrace, DOM checks)     │  │    │
│   │   └───────────────────────────────────────────────────────────────────┘  │    │
│   │          │ authenticated browser sessions                                │    │
│   │          ▼                                                               │    │
│   │   ┌─────────────────────┐     ┌──────────────────────┐                  │    │
│   │   │   Query Monitor     │     │   HookTrace          │                  │    │
│   │   │                     │     │                      │                  │    │
│   │   │  qm_profile_page   │     │  hooktrace_profile   │                  │    │
│   │   │  qm_slow_queries   │     │  hooktrace_slow_hooks│                  │    │
│   │   │  qm_duplicate_     │     │  hooktrace_hook_chain│                  │    │
│   │   │  queries            │     │                      │                  │    │
│   │   └─────────────────────┘     └──────────────────────┘                  │    │
│   │                                                                         │    │
│   │   Captures:                   Captures:                                  │    │
│   │   · SQL queries + timing      · per-callback execution order             │    │
│   │   · N+1 / duplicate queries   · per-callback timing                      │    │
│   │   · cache hit/miss rates      · source file for each callback            │    │
│   │   · HTTP API calls            · hooks that fired vs. didn't              │    │
│   │                                                                         │    │
│   │                              ◄── regressions? → fix, loop to Step 1     │    │
│   └─────────────────────────────┬───────────────────────────────────────────┘    │
│                                 │                                                │
│                                 │ all layers clean                               │
│                                 ▼                                                │
│   ┌─────────────────── Step 5: Done ───────────────────────────────────────┐    │
│   │                     Code is verified across all layers                  │    │
│   └─────────────────────────────────────────────────────────────────────────┘    │
│                                                                                 │
│   ┌───────────────────────────────────────────────────────────────────────────┐  │
│   │                          MCP Server (26 tools)                           │  │
│   │                                                                          │  │
│   │  pw_auth_* (passwordless login)  ·  qm_* (profiling)  ·  wpcc_* (scan) │  │
│   │  local_wp_* (site mgmt)  ·  tmux_* (sessions)  ·  wpcc_ast_check      │  │
│   │  ask_self_query  ·  ask_self_review  ·  hooktrace_* (planned)           │  │
│   └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘


DATA FLOW BETWEEN LAYERS
─────────────────────────

Any finding from any layer can be enriched by ask_self:

  grep finding ──────┐
  Semgrep finding ───┤
  AST finding ───────┼──► ask_self ──► repo-grounded context
  QM slow query ─────┤                 (why it matters, how
  HookTrace timing ──┘                  this repo handles it,
                                        what PR introduced it)


COMPONENT OWNERSHIP
───────────────────

  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
  │    WPCC      │    │   ask_self   │    │   AI-DDTK    │
  │              │    │              │    │              │
  │ · Scanner    │    │ · RAG engine │    │ · MCP server │
  │ · 54 grep    │    │ · Ingest     │    │ · Loop ctrl  │
  │   patterns   │    │ · Query      │    │ · Playwright │
  │ · Semgrep    │    │ · Review     │    │   + password-│
  │   rules      │    │   (planned)  │    │   less login │
  │ · AST checker│    │ · Harness    │    │   mu-plugin  │
  │ · Pattern    │    │   config     │    │ · QM bridge  │
  │   library    │    │ · System     │    │ · HookTrace  │
  │              │    │   instruct.  │    │   (planned)  │
  │              │    │              │    │ · LocalWP    │
  │              │    │              │    │ · Recipes    │
  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘
         │                   │                   │
         │     detection     │   understanding   │  orchestration
         │     + structure   │   + enrichment    │  + runtime +
         │                   │                   │  auth
         │                   │                   │
         └───────────────────┴───────────────────┘
                      │
              All exposed as MCP tools
              to any VS Code AI agent
```

---

Integration ideas worth considering:

The scanner is grep-based and structural; ask_self is semantic. That's a complementary pairing, not a redundant one:

Finding explainer / triage assistant — Scanner flags 30 issues across a site. Feed those findings into ask_self as a query: "Why does this repo use $wpdb->prepare() this way?" or "Is this eval() usage intentional?" It can pull from PRs, changelogs, and docs to tell you whether a finding is a known pattern or a real concern. Cuts triage time.

False positive reducer — Scanner's grep can't see multi-line sanitization or architectural intent. ask_self can retrieve chunks showing that a flagged pattern is wrapped in a mitigation elsewhere. This is the "secondary evaluator" you're intuiting — a semantic second opinion on structural matches.

Pattern gap discovery — "What risks exist in this repo that the scanner doesn't check for?" is a question ask_self can actually attempt, since it has the pattern library and the source indexed together.

Remediation grounded in repo conventions — Instead of generic "use prepared statements" advice, ask_self can show how this specific repo already handles that pattern elsewhere.

AI-DDTK - POTENTIAL INTEGRATION
https://github.com/Hypercart-Dev-Tools/AI-DDTK-Fix-Iterate-Loop/

## Review System Instruction Layer (Sketch)

This layer would live alongside the existing Q&A layers in `ask_self_system_instructions.json`.
It is designed to be invoked by an AI agent inside a Fix-Iterate Loop (see AI-DDTK)
rather than by a human asking freeform questions.

### System instruction additions

```json
{
  "system_layers": {
    "...existing layers unchanged...": "...",

    "review_system": "You are a code reviewer with access to the full indexed codebase. You are given a diff or file excerpt. Your job is to identify violations of DRY, SOLID, and repo-specific conventions by comparing the submitted code against existing patterns in the retrieved context. Do not invent violations — only flag issues where the retrieved context provides concrete evidence of an existing pattern, utility, or abstraction that the new code duplicates or contradicts. If you find no violations, say so explicitly.",

    "review_severity_system": "Classify each violation as: MUST_FIX (blocks merge — duplication of existing utility, broken interface contract, security regression), SHOULD_FIX (strong suggestion — could use existing abstraction, naming inconsistency with established conventions), or CONSIDER (style preference — alternative exists but current approach is acceptable). Never inflate severity."
  }
}
```

### Review response contract

```json
{
  "review_response_contract": {
    "format": "json",
    "fields": {
      "verdict": "one of: clean, has_violations",
      "violations": [
        {
          "principle": "DRY | SRP | OCP | LSP | ISP | DIP | CONVENTION",
          "severity": "MUST_FIX | SHOULD_FIX | CONSIDER",
          "location": "file path and line range in the submitted diff",
          "description": "what the violation is",
          "existing_pattern": "file path and excerpt from the indexed codebase that the new code duplicates or contradicts",
          "suggested_fix": "concrete refactoring suggestion grounded in the existing pattern"
        }
      ],
      "summary": "one-sentence overall assessment",
      "sources_consulted": ["array of retrieved chunk sources"]
    }
  }
}
```

### How this fits the AI-DDTK Fix-Iterate Loop

The review layer slots into Step 3 (Verify) of the Fix-Iterate Loop.
The AI agent is the loop controller; ask_self is the verification oracle.

```
Fix-Iterate Loop (AI-DDTK)          ask_self (WPCC)
─────────────────────────           ───────────────
1. Agent writes/modifies code
                                    
2. Agent extracts diff:
   git diff --cached > /tmp/diff
                                    
3. Verify via ask_self:             ◄── ask_self_review.py --diff /tmp/diff
                                        --checks dry,srp,convention
                                        --harness-config ask_self_harness.json
                                        --json
                                    
                                    Returns structured verdict:
                                    {
                                      "verdict": "has_violations",
                                      "violations": [
                                        {
                                          "principle": "DRY",
                                          "severity": "MUST_FIX",
                                          "location": "src/utils/parse.py:42-58",
                                          "existing_pattern": "src/lib/parser.py:10-25 — parse_input() already does this",
                                          "suggested_fix": "Import and call parse_input() from src/lib/parser.py"
                                        }
                                      ]
                                    }
                                    
4. Agent reads verdict:
   - "clean" → done, exit loop
   - "has_violations" → apply
     suggested_fix, loop to step 1
                                    
5. Guardrails (from AI-DDTK):
   - 5 failed iterations → stop
   - 10 total iterations → stop
   - Confidence trending down → stop
```

### Iteration template (extends AI-DDTK format)

```
ITERATION N:
1. What I changed: [describe code change]
2. Diff: [file paths and line counts]
3. ask_self command: ask_self_review.py --diff /tmp/diff --checks dry,srp --json
4. Expected result: {"verdict": "clean"}
5. Actual result: [paste structured verdict]
6. Status: CLEAN / N violations (X MUST_FIX, Y SHOULD_FIX, Z CONSIDER)
7. Next action: [apply suggested fixes or stop]

META-REFLECTION (Iteration N):
Confidence: [1-10]
Violations trending: [up/down/flat]
Risk: [LOW / MEDIUM / HIGH]
Continue? [YES / NO / ASK_HUMAN]
```

### MCP tool definition (for VS Code agent integration)

For Claude Code or other VS Code agents to call ask_self natively in the loop,
expose it as an MCP tool. Minimal definition:

```json
{
  "tools": [
    {
      "name": "ask_self_review",
      "description": "Review a code diff against the indexed codebase for DRY, SOLID, and convention violations. Returns structured violations with evidence from existing code.",
      "inputSchema": {
        "type": "object",
        "properties": {
          "diff": {
            "type": "string",
            "description": "Unified diff text to review"
          },
          "checks": {
            "type": "array",
            "items": {"type": "string", "enum": ["dry", "srp", "ocp", "lsp", "isp", "dip", "convention"]},
            "description": "Which principles to check. Defaults to all."
          },
          "harness_config": {
            "type": "string",
            "description": "Path to ask_self_harness.json"
          }
        },
        "required": ["diff"]
      }
    },
    {
      "name": "ask_self_query",
      "description": "Ask a natural-language question about the indexed codebase. Returns a grounded answer with sources.",
      "inputSchema": {
        "type": "object",
        "properties": {
          "question": {
            "type": "string",
            "description": "The question to ask"
          },
          "harness_config": {
            "type": "string",
            "description": "Path to ask_self_harness.json"
          }
        },
        "required": ["question"]
      }
    }
  ]
}
```

The MCP server would be a thin wrapper: parse input → call ask_self CLI → return JSON.
The `--json` output contract already exists — no new serialization needed.

### What lives where

| Concern | Home | Why |
|---------|------|-----|
| Loop control, guardrails, iteration template | AI-DDTK | Generic agent pattern, not ask_self-specific |
| Review system instructions, severity rules | ask_self_system_instructions.json | Answer-behavior config, not code |
| Diff parsing, review-mode query construction | ask_self_review.py (new) | Engine code, repo-agnostic |
| MCP server adapter | AI-DDTK or standalone | Integration glue, should live near the agent |
| Repo-specific convention rules | ask_self_harness.json per repo | Policy, not code |

### Implementation order (suggested)

1. Add `review_system` and `review_severity_system` layers to ask_self_system_instructions.json
2. Add `review_response_contract` to the same file
3. Write `ask_self_review.py` — accepts a diff, embeds it, queries with review instructions, returns structured verdict
4. Test manually: `git diff HEAD~1 | python3 ask_self_review.py --json`
5. Wrap as MCP tool in AI-DDTK
6. Wire into Fix-Iterate Loop template as the verify step

---

## PHP-Parser AST Integration

WPCC already has a working PHP-Parser AST checker (`dist/bin/ast/wpcc-ast-check.php`)
that can detect return array shapes and enforce expected keys. See
`PROJECT/3-COMPLETED/P1-PHP-PARSER.md` for the full research log and Phase 2 findings.

There are three integration layers between PHP-Parser AST analysis and ask_self,
each progressively deeper.

### Layer 1: AST findings as ask_self queries (simplest)

The AST checker produces structural findings (missing keys, shape mismatches).
ask_self adds semantic context: *why* the shape matters, *where* the contract is
documented, *how* the repo handles similar patterns elsewhere.

```
wpcc-ast-check.php                     ask_self
────────────────                       ─────────
--rule return-array-shape
--paths src/ajax-handler.php
        │
        ▼
Finding: "Return at line 152 missing
key 'wholesale_flag' expected by
config"
        │
        ├──► ask_self --json \
        │    "Why does ajax_search_customers need a wholesale_flag key?
        │     What consumes this return value?"
        │
        ▼
Grounded answer from PR history,
docs, and source:
"PR #87 added wholesale filtering.
The KISS_Woo_Order_Filter at
line 44 of class-order-filter.php
destructures this key. Missing it
causes silent filter bypass."
```

**What this gives you:** Instead of "missing key X" the developer sees *why* the
key matters and *what breaks* without it — all grounded in their own repo.

**Implementation:** Pipe AST JSON findings into ask_self queries. No code changes
to either tool — just a shell wrapper or AI-DDTK recipe:

```bash
# Run AST check, then enrich each finding with semantic context
php dist/bin/ast/wpcc-ast-check.php \
  --rule return-array-shape \
  --paths "$TARGET" \
  --output json \
| jq -r '.findings[] | .message' \
| while read -r finding; do
    python3 ask_self/ask_self_query.py \
      --harness-config ask_self/ask_self_harness.json \
      --json \
      "Explain this AST finding in repo context: $finding"
  done
```

### Layer 2: AST metadata indexed into ask_self (medium effort)

Index AST-extracted structural data as chunks alongside docs and source.
This makes retrieval structurally aware — ask_self can answer questions like
"which functions return arrays with a 'customers' key?" without re-parsing.

**What gets indexed:**

| AST extraction | Chunk content | Source type |
|----------------|---------------|-------------|
| Function signatures | `function ajax_search_customers(): array{customers, total, has_more}` | `ast-signature` |
| Return shapes | `ajax_search_customers returns {customers: list, total: int, has_more: bool} at line 152` | `ast-shape` |
| Class hierarchies | `KISS_Woo_Order_Filter extends Abstract_Filter, implements Filterable` | `ast-hierarchy` |
| Hook registrations | `add_filter('woocommerce_cart_item_price', 'my_custom_price', 10, 3)` | `ast-hook` |

**Implementation sketch:**

1. Add an `ast_extract` command to `wpcc-ast-check.php` that outputs structured
   metadata (not findings) as JSON lines — one per function/class/hook.

2. Add an `ast` source type to `ask_self_harness.json`:
   ```json
   {
     "classification_rules": [
       {
         "pattern": "^ast-extracts/.+\\.jsonl$",
         "source": "ast",
         "priority": 5,
         "chunker": "line"
       }
     ]
   }
   ```

3. Ingest pipeline: run AST extraction before `ask_self_ingest.py`, write
   output to `temp/ast-extracts/`, then ingest picks it up as another source.

**What this gives you:** ask_self retrieval now understands code structure, not
just text similarity. "What functions return an array with a customers key?"
returns precise AST-grounded results instead of grep-like text matches.

### Layer 3: AST-aware review loop (deepest — lives in AI-DDTK)

Combine the review loop from the previous section with AST verification as
a second oracle alongside ask_self. The agent gets two independent signals:
structural correctness (AST) and semantic/convention correctness (ask_self).

```
Fix-Iterate Loop (AI-DDTK)
───────────────────────────
1. Agent writes/modifies PHP code
        │
        ▼
2. Structural verification (AST):
   php wpcc-ast-check.php --rule return-array-shape --paths changed_files
        │
        ├── Shape violations? → agent fixes before proceeding
        │
        ▼
3. Semantic verification (ask_self):
   ask_self_review.py --diff <(git diff) --checks dry,srp,convention
        │
        ├── DRY/SOLID violations? → agent fixes, loop to step 1
        │
        ▼
4. Both clean → done
```

**Why two oracles are better than one:**

| Check | AST alone | ask_self alone | Both |
|-------|-----------|----------------|------|
| Missing return key | Catches | Might miss (text similarity won't flag a missing key reliably) | Catches |
| Duplicate utility | Can't detect (no semantic similarity) | Catches (vector similarity finds existing code) | Catches |
| Wrong product type (`WC_Product_Variable` vs `Simple`) | Catches (with PHPStan, not basic PHP-Parser) | Might catch (if docs describe the distinction) | Catches |
| Naming convention violation | Can't detect | Catches (retrieves repo's naming patterns) | Catches |
| Contract mismatch (filter expects shape X, function returns Y) | Catches (shape enforcement) | Can explain *why* it matters | Catches + explains |

**MCP tool additions for the AST oracle:**

```json
{
  "name": "wpcc_ast_check",
  "description": "Run PHP-Parser AST checks on PHP files. Returns structural findings (missing keys, shape mismatches) as JSON.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "rule": {
        "type": "string",
        "enum": ["return-array-shape", "hook-arg-mismatch", "hook-inventory"],
        "description": "Which AST rule to run"
      },
      "paths": {
        "type": "string",
        "description": "Space-separated file paths to check"
      },
      "config": {
        "type": "string",
        "description": "Path to rule config JSON"
      }
    },
    "required": ["rule", "paths"]
  }
}
```

### Where each layer lives

| Layer | WPCC | AI-DDTK | ask_self |
|-------|------|---------|----------|
| 1. AST findings → ask_self queries | AST checker (exists) | Shell recipe | Query pipeline (exists) |
| 2. AST metadata in index | AST extract command (new) | — | Harness config + ingest (minor changes) |
| 3. Dual-oracle review loop | AST checker (exists) | Loop controller + MCP tools | Review mode (new) |

### Implementation order

Start with Layer 1 — it requires zero code changes to either tool and validates
the value proposition. If enriched findings are useful, proceed to Layer 2 to
make retrieval structurally aware. Layer 3 is the full vision but depends on the
review mode from the previous section being built first.

### Relationship to Semgrep migration

The Semgrep migration plan (`PROJECT/1-INBOX/FEATURE-SEMGREP-MIGRATION-PLAN.md`)
is pursuing a *replacement* of grep-based pattern detection for 5-10 noisy rules.
AST integration with ask_self is a different axis:

| Concern | Semgrep | PHP-Parser + ask_self |
|---------|---------|----------------------|
| Goal | Better pattern matching (fewer false positives) | Structural understanding + semantic context |
| Replaces | grep-based detection | Nothing — additive layer |
| Scope | Per-rule migration | Cross-cutting enrichment |
| Dependencies | Semgrep binary | PHP-Parser (already bundled), ask_self |

These are complementary, not competing. Semgrep improves detection precision;
AST + ask_self improves what you can *do* with findings after detection.
A Semgrep finding can be enriched by ask_self the same way a grep finding can.

---

## Runtime Observability: Query Monitor + HookTrace (Optional)

Everything above — grep, AST, Semgrep, ask_self — operates on source code at rest.
Query Monitor and HookTrace add a *runtime* layer: what actually happens when a
page loads. This is the difference between "this code *could* run N+1 queries"
(static finding) and "this page *did* run 47 duplicate queries in 380ms" (runtime proof).

AI-DDTK already has a production-grade QM bridge (`tools/qm-bridge/`) exposing
3 MCP tools: `qm_profile_page`, `qm_slow_queries`, `qm_duplicate_queries`.
HookTrace is listed as a recommended companion but has no bridge yet.

### The four-layer analysis stack

| Layer | Tool | What it sees | Data type | Exists today? |
|-------|------|-------------|-----------|---------------|
| 1. Pattern detection | WPCC grep / Semgrep | Text patterns in source | Static | Yes |
| 2. Structural analysis | PHP-Parser AST | Syntax trees, return shapes, contracts | Static | Yes |
| 3. Semantic understanding | ask_self RAG | Docs, PRs, conventions, intent | Static (indexed) | Yes |
| 4. Runtime observation | Query Monitor + HookTrace | Actual queries, timings, hook execution | Dynamic (per-request) | QM: Yes, HookTrace: No |

Each layer catches things the others can't. The value compounds when they feed
into each other.

### How QM data feeds into ask_self

The QM bridge already captures structured JSON profiles with database queries,
timing, cache stats, and HTTP calls. This data can enrich ask_self in two ways:

**A. Runtime findings as ask_self queries (immediate, no code changes)**

Same pattern as Layer 1 of AST integration — pipe runtime observations into
ask_self for repo-grounded explanation.

```
qm_slow_queries                        ask_self
───────────────                        ─────────
Profile /wp-admin/edit.php
threshold_ms: 50
        │
        ▼
Slow query: "SELECT * FROM
wp_postmeta WHERE post_id IN
(1,2,3,...,500)" — 340ms
        │
        ├──► ask_self --json \
        │    "Why does the edit.php page run an unbounded
        │     wp_postmeta query? Is there a known fix or
        │     caching strategy in this repo?"
        │
        ▼
Grounded answer:
"CHANGELOG v1.0.41 documents this as
pattern WPQ-002. The recommended fix
is update_post_meta_cache() before
the loop. See dist/patterns/
wp-query-unbounded.json for the
detection rule."
```

**What this gives you:** Runtime proof + static remediation in one step. The
developer sees "this query is slow" *and* "here's how this repo handles it"
without switching contexts.

**B. Runtime profiles indexed into ask_self (medium effort)**

Index QM profile summaries as a new source type so retrieval has runtime awareness.
Useful for repos with recurring performance investigations.

```json
{
  "classification_rules": [
    {
      "pattern": "^qm-profiles/.+\\.json$",
      "source": "runtime-profile",
      "priority": 4,
      "chunker": "text"
    }
  ]
}
```

The QM bridge already saves profiles to `temp/qm-profiles/<domain>_<timestamp>.json`.
Adding that directory to the harness include patterns makes historical profiles
searchable: "Which pages had slow queries last week?" or "Has the cart page
performance changed since PR #142?"

### How HookTrace would fit

HookTrace captures what QM doesn't: per-callback execution order, timing, and
source file for every hook fired during a request. This fills a specific gap
in the analysis stack.

**What HookTrace sees that nothing else does:**

| Question | grep | AST | ask_self | QM | HookTrace |
|----------|------|-----|----------|-----|-----------|
| "Which callbacks fire on `woocommerce_checkout_process`?" | Can find `add_action` calls | Can find `add_action` calls | Can retrieve docs about the hook | No | **Yes — actual execution order and timing** |
| "Is our callback running before or after WooCommerce's?" | No | No | Maybe (if documented) | No | **Yes — shows exact priority ordering** |
| "Which hook callback is causing the 200ms delay?" | No | No | No | Shows total page time | **Yes — per-callback timing** |
| "Did our filter accidentally remove another plugin's hook?" | No | No | No | No | **Yes — shows what fired and what didn't** |

**HookTrace bridge sketch (for AI-DDTK):**

HookTrace exposes its data via `window.hookTraceData` on the page (when active).
A bridge would follow the same pattern as the QM bridge:

```
┌──────────────────────┐
│ AI-DDTK MCP Server   │
│                      │
│ hooktrace_profile()  │──► Playwright hits page with HookTrace active
│                      │    Extracts window.hookTraceData via page.evaluate()
│                      │    Returns structured JSON
│                      │
│ hooktrace_slow_hooks()│──► Filters for callbacks above threshold
│                      │
│ hooktrace_hook_chain()│──► Returns full callback chain for a named hook
└──────────────────────┘
```

**Proposed MCP tools:**

```json
{
  "tools": [
    {
      "name": "hooktrace_profile",
      "description": "Capture all hooks fired during a page load with per-callback timing and source files.",
      "inputSchema": {
        "type": "object",
        "properties": {
          "siteUrl": { "type": "string" },
          "path": { "type": "string" },
          "user": { "type": "string", "description": "WordPress user to authenticate as" }
        },
        "required": ["siteUrl", "path"]
      }
    },
    {
      "name": "hooktrace_slow_hooks",
      "description": "Return hook callbacks exceeding a timing threshold.",
      "inputSchema": {
        "type": "object",
        "properties": {
          "siteUrl": { "type": "string" },
          "path": { "type": "string" },
          "threshold_ms": { "type": "number", "default": 10 },
          "user": { "type": "string" }
        },
        "required": ["siteUrl", "path"]
      }
    },
    {
      "name": "hooktrace_hook_chain",
      "description": "Return the full callback chain for a specific hook, with priority ordering, timing, and source file for each callback.",
      "inputSchema": {
        "type": "object",
        "properties": {
          "siteUrl": { "type": "string" },
          "path": { "type": "string" },
          "hook_name": { "type": "string", "description": "e.g. woocommerce_checkout_process" },
          "user": { "type": "string" }
        },
        "required": ["siteUrl", "path", "hook_name"]
      }
    }
  ]
}
```

### The full review loop with runtime verification

With all four layers available, the Fix-Iterate Loop gains a runtime verification
step that closes the gap between "code looks correct" and "code works correctly":

```
Fix-Iterate Loop (AI-DDTK) — Full Stack
────────────────────────────────────────

1. Agent writes/modifies PHP code
        │
        ▼
2. Static checks (parallel):
   ├── WPCC grep/Semgrep scan ──► pattern violations?
   └── PHP-Parser AST check ───► shape/contract violations?
        │
        ├── Violations? → fix, loop to 1
        │
        ▼
3. Semantic review:
   ask_self_review.py --diff --checks dry,srp,convention
        │
        ├── DRY/SOLID violations? → fix, loop to 1
        │
        ▼
4. Runtime verification (optional, requires running site):
   ├── qm_profile_page ─────────► slow queries? N+1? cache misses?
   └── hooktrace_hook_chain ─────► hook ordering issues? slow callbacks?
        │
        ├── Runtime regressions? → fix, loop to 1
        │
        ▼
5. All layers clean → done
```

**When runtime verification matters:**

- Performance-sensitive changes (checkout, cart, search)
- Hook priority changes (could break execution order)
- Database query changes (could introduce N+1 patterns)
- Cache strategy changes (could invalidate wrong keys)

**When to skip it:**

- Pure documentation or config changes
- No running WordPress site available
- Changes to code paths not exercisable via page load

### Where runtime tools live

| Tool | Home | Why |
|------|------|-----|
| QM bridge (mu-plugin + MCP handler) | AI-DDTK `tools/qm-bridge/` | Already exists, production-grade |
| HookTrace bridge (MCP handler) | AI-DDTK `tools/hooktrace-bridge/` (new) | Runtime integration, same pattern as QM |
| Runtime profile indexing into ask_self | ask_self harness config | Just a classification rule + include pattern |
| Runtime-enriched queries | Shell recipe or AI-DDTK recipe | Pipe MCP output → ask_self |
| Loop controller with runtime step | AI-DDTK Fix-Iterate Loop | Loop orchestration lives here |

### Implementation order

1. **QM → ask_self query enrichment** (no code changes) — pipe `qm_slow_queries`
   output into ask_self for repo-grounded remediation. Shell recipe only.
2. **QM profile indexing** (minor config change) — add `qm-profiles/` to
   ask_self harness include patterns so historical profiles are searchable.
3. **HookTrace bridge** (new MCP handler in AI-DDTK) — follows QM bridge pattern.
   Playwright-based, extracts `window.hookTraceData`, returns structured JSON.
4. **HookTrace → ask_self enrichment** — same as step 1 but for hook data.
5. **Full-stack loop integration** — wire runtime step into Fix-Iterate Loop
   template as optional Step 4.

### Relationship to existing layers

```
                    ┌─────────────────────────────────┐
                    │        ask_self (semantic)       │
                    │   Answers "why" and "how" from   │
                    │   docs, PRs, conventions         │
                    └──────────┬──────────────────────┘
                               │ enriches findings from all layers
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│   Static/Pattern │ │   Static/Struct  │ │   Runtime/Obs    │
│                  │ │                  │ │                  │
│  WPCC grep       │ │  PHP-Parser AST  │ │  Query Monitor   │
│  Semgrep (pilot) │ │  PHPStan (dev)   │ │  HookTrace       │
│                  │ │                  │ │                  │
│  "this pattern   │ │  "this shape is  │ │  "this page ran  │
│   exists in code"│ │   wrong"         │ │   47 queries"    │
└──────────────────┘ └──────────────────┘ └──────────────────┘
     Layer 1              Layer 2              Layer 4
```

ask_self (Layer 3) sits above the others as the semantic enrichment layer.
Any finding from any layer can be fed into ask_self for repo-grounded context.
The layers don't depend on each other — they can be adopted incrementally
and combined selectively based on what a given review or investigation needs.