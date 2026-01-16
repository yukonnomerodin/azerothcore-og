# MAINTENANCE.md
# Project Maintenance & Reminders

## Purpose
This file exists to prevent documentation drift.
It defines when and how project documents must be reviewed and updated.

## When to update documents

### 1) New idea or system
If a new idea affects gameplay, progression, or long-term direction:
- Review: ROADMAP.md
- If it changes philosophy or identity: VISION.md
- If it adds a system: create a PATCH_00X_*.md using PATCH_TEMPLATE.md

### 2) Priority or route change
If patch order, focus, or scope changes:
- Update: ROADMAP.md
- Verify consistency with: PILLARS.md
- Add a note to: CHANGELOG.md (Unreleased)

### 3) Technical or architectural change
If implementation approach changes:
- Update: ARCHITECTURE.md
- If it affects performance assumptions: PERFORMANCE_BUDGET.md
- If it affects module rules: MODULE_GUIDE.md

### 4) Tooling change (Codex, CI, workflows)
If a core development tool or workflow changes:
- Update: ARCHITECTURE.md
- Update: README.md
- Add note to: CHANGELOG.md

## Codex usage reminder
This project uses Codex as an assisted development and planning tool.
When workflows, rules, or usage patterns change:
- Update the Codex-related sections in documentation.
- Ensure rules align with modular and performance-first principles.

## Review cadence
- After every patch release
- After any major design decision
- Before starting a new patch

## Rule of thumb
If code was changed in a meaningful way and no document was updated,
documentation is likely out of sync.
