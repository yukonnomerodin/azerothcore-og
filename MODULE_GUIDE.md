# WoW LK Custom Server — Module Guide

## Goal
Modules should be:
- self-contained,
- enable/disable safe,
- observable,
- maintainable over seasons.

## Required structure (recommended)
- `modules/<ModuleName>/`
  - `README.md`
  - `conf/` (or config section)
  - `sql/` (migrations)
  - `src/` (module code)
  - `tests/` (optional)

## Must-have behaviors
- Feature flag: module can be disabled cleanly.
- No hard dependencies on other modules unless explicitly documented.
- DB migrations: versioned, idempotent where possible.
- Logging: rate-limited for repetitive errors.
- Admin visibility: show module status, key counts.

## Integration rules
- Integrations must be explicit and minimal.
- Avoid “reach-in” patterns (module A modifying module B internals).
- Prefer shared interfaces/utilities for cross-module collaboration.

## Mercenaries vs Population bots rule
- Mercenaries are a permanent gameplay mechanic module.
- Population bots are a separate infrastructure module.
- Do not couple availability, scaling, or configuration between these systems.

## Release rules
Every module change should include:
- config defaults,
- migration changes,
- patch note entry,
- rollback note if schema or critical behavior changes.
