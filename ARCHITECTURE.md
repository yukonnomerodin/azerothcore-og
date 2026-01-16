# WoW LK Custom Server — Architecture

## Intent
This architecture exists to:
- Preserve AzerothCore updateability (no core modifications).
- Enable rapid feature iteration via modules.
- Protect server performance via explicit budgets and guardrails.

## High-level structure
- **AzerothCore**: base server, transport, world simulation.
- **Modules**: isolated feature units (Patch 1, Patch 2, etc.).
- **Config layer**: per-module config, with runtime toggles where possible.
- **DB migrations**: each module maintains its own schema changes.
- **Telemetry/logging**: shared observability utilities for performance and gameplay metrics.

## AI actors separation (critical)
We operate with two distinct AI categories:

### 1) Mercenaries (gameplay mechanic)
- Permanent system (always available).
- Player-bound companions with explicit UI, limits, and rules.
- Implemented with bot-like AI internally, but treated as a gameplay feature.

### 2) Population bots (infrastructure module)
- Optional world population scaffolding.
- Independent scaling and enable/disable from mercenaries.
- Must NOT affect mercenary availability.

Do not couple these systems in logic, config, or progression.

## Module standards
Each module must include:
- `README.md` describing purpose, toggles, dependencies
- Config file or config section with defaults
- DB migration scripts (idempotent where possible)
- Feature flag (enable/disable) and safe failure behavior
- Minimal coupling with other modules (explicit integration points only)

## Performance guardrails
- No per-tick heavy logic without throttling.
- Prefer event-driven logic over polling.
- Avoid O(N players * N bots) patterns; batch where possible.
- Ensure graceful degradation: if load is high, reduce update frequency or disable non-critical behavior.

## Observability (minimum)
- Server tick health indicators (average loop time, spikes)
- Feature usage metrics (e.g., mercenary hires, active mercs)
- Error counters and rate-limited logs
- Simple admin commands for diagnostics (module status, counts)

## Patch flow
1. Define patch goal and scope
2. Define performance budget + metrics
3. Implement as module(s) with toggles
4. Load test with bots and representative world load
5. Release with patch notes + rollback plan

## Tooling: Codex (assisted development)
This project uses Codex to accelerate development while preserving architectural discipline.

Operating model:
- Planning/architecture: one focused Codex pass to produce patch briefs, hook points, data models, and risk/performance notes.
- Implementation: broken into small, reviewable PR-sized chunks (minimal diffs).
- Execution: compilation, runtime testing, and profiling are performed locally; Codex is used for:
  - code generation and targeted edits
  - SQL and configuration templates
  - code review and refactoring
  - interpreting build/runtime logs and proposing minimal fixes

Constraints (must be respected):
- Do NOT modify AzerothCore core unless explicitly requested.
- Prefer separate modules under /modules and follow existing AzerothCore module/CMake patterns.
- Keep changes minimal, clean, and reviewable.
