# TOOLING_CODEX.md
# Codex Usage Playbook (Plus limits optimized)

## Purpose
Use Codex efficiently under Plus limits:
- planning and architecture in 1 pass
- implementation via small, reviewable PR-sized chunks
- local build/run by developer, Codex used for code generation, edits, SQL/config, review/refactor

## Non-negotiables (project + repo constraints)
- Do NOT modify AzerothCore core unless explicitly requested.
- Prefer implementing gameplay features as separate modules under `/modules`.
- Keep changes minimal, clean, and reviewable (PR-sized).
- When adding features, include SQL and config templates if needed.
- Mercenaries are a permanent gameplay mechanic (always available).
- Population bots are a separate module; do not couple scaling/availability/config with mercenaries.

## Repository facts (from scan + verified by build)
- This repository is AzerothCore (WotLK) with a module system under `/modules`.
- Modules are integrated via `modules/<module>/include.sh` (no per-module CMakeLists.txt in this repo).
- Each module typically contains:
  - `include.sh`
  - `src/` (module code + loader)
  - `conf/*.conf.dist` (installed automatically)
  - `sql/` (manual or migration-applied)
- Script registration follows the standard pattern:
  - `Addmod_<module_name>Scripts()` in `*_loader.cpp`
  - calls a module-specific registration function in the main `.cpp`
- Gameplay extensions use `ScriptMgr` hooks (`CreatureScript`, `PlayerScript`, `WorldScript`).
- Core modifications are forbidden unless explicitly requested.

## Recommended Codex workflow

### 1) Planning pass (1x analysis)
Use Codex once to produce:
- design brief (goals, scope, risks)
- hook points (ScriptMgr types + events)
- minimal data model (tables + key fields)
- performance constraints and throttling strategy
Output must be a single patch doc: `PATCH_00X_*.md`

### 2) Implementation as small PR chunks
Each Codex request should map to a small, reviewable diff:
- PR-0: module skeleton (include.sh + loader + conf.dist + sql placeholders)
- PR-1: NPC gossip UI + hire/dismiss + persistence (no AI)
- PR-2: basic behaviors (Follow/Stay/Assist) + throttling
- PR-3: restrictions/guardrails + observability + admin/debug tools
- PR-4: profiling + perf hardening

### 3) Local execution responsibilities
Developer (local):
- configure/build
- run worldserver/authserver
- provide runtime logs, crash dumps, perf metrics

Codex:
- interpret logs, propose minimal fixes
- generate code and targeted edits
- write SQL and configuration templates
- review diffs for cleanliness and risk
- refactor/optimize hot spots

## Prompt templates (copy/paste)

### A) Planning (single pass)
"Create PATCH_001_MERCENARIES.md using PATCH_TEMPLATE.md.
Include: goal, scope, ScriptMgr hook plan, data model (SQL tables),
config keys, performance strategy, restrictions, rollback plan.
Constraint: no core modifications; module under /modules."

### B) PR-sized implementation chunk
"Make a small PR-sized change for modules/mod-mercenary-system/.
Follow this repo’s module pattern (include.sh, src/, conf/, sql/).
Minimal diff; no core edits. Output exact files to add/replace."

### C) Code edit / refactor
"Refactor file X to reduce complexity, preserve behavior, keep changes minimal and reviewable."

### D) Log-driven fix
"Given this build/runtime log, identify root cause and propose the smallest fix.
Output exact code diffs or full file replacements. Avoid core changes."

## Workflow rules (must follow)
- Always propose the best next action first (most stable, least risky option).
- If the user agrees, provide exact step-by-step instructions (where to edit, what to paste, commands/SQL), preferably full ready-to-copy code.
- Maintain continuity: keep a living `CODE_SNAPSHOT_MERCENARY.md` updated after each PR (config, SQL, and full key source files).

## Documentation sync rule
If a meaningful design decision is made or patch route changes:
- update ROADMAP.md
- update PATCH docs
- update CHANGELOG.md (Unreleased)

If tooling/workflow changes:
- update this file (TOOLING_CODEX.md)
