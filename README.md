# README.md
# WoW LK Custom Server (AzerothCore, WotLK)

## What this is
A custom seasonal Wrath of the Lich King server built on AzerothCore with a modular, stability-first philosophy and unique gameplay systems.

## Principles
- Modular development (no core modifications)
- Player-driven feedback
- Seasonal patch model
- Population bots for low population (separate module), reduced as real players join
- Mercenaries are a permanent gameplay mechanic (always available)
- Stability and performance first

## Roadmap
- Patch 1: Mercenary System
- Patch 2: Level 90 + Crafting System
- Patch 3: New Zone + Questlines
- Patch 4: Custom Battleground Format

## Docs
- VISION.md
- ROADMAP.md
- PILLARS.md
- ARCHITECTURE.md
- PERFORMANCE_BUDGET.md
- MODULE_GUIDE.md
- RELEASE_MODEL.md
- PATCH_TEMPLATE.md
- CHANGELOG.md

## Tooling (Codex workflow)
We use Codex (ChatGPT Plus) to accelerate planning and implementation under strict constraints:
- Do not modify AzerothCore core unless explicitly requested.
- Prefer small, reviewable PR-sized changes (module skeleton → feature slices).
- Build/run/compile locally; use Codex for code generation, edits, SQL/config templates, review, and refactors.
See TOOLING_CODEX.md for prompt templates and operating rules.