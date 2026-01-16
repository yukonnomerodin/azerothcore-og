# WoW LK Custom Server — Performance Budget

## Purpose
A formal agreement: features must fit within server performance constraints.
If a feature cannot fit, it must be redesigned, throttled, or postponed.

## Core rules
- Avoid frequent global scans (e.g., scanning all players/bots each tick).
- Prefer:
  - event-based updates,
  - cached queries,
  - batched operations,
  - rate-limited AI/behavior updates.

## Permanent systems note
Mercenaries are a permanent mechanic (always available), therefore:
- performance costs are continuous, not seasonal/temporary
- budgets must be validated at representative load (including bots and peak activity)
- mercenary AI must have explicit throttling and degradation behavior

## Required for each patch/module
Each patch must specify:
- What additional computations it introduces
- Where it runs (world loop, map loop, per-player)
- Update frequency (tick, every X ms, event-driven)
- Expected worst-case impact at target load

## Throttling guidelines
- AI updates should run at a controlled cadence (e.g., every 250–500ms or more) unless critical.
- Expensive pathing/decision-making must be amortized or cached.
- Any per-player feature must scale predictably as population increases.

## Degradation policy
Under load, non-critical systems should:
- reduce update frequency,
- skip cosmetic/non-essential behaviors,
- log a warning (rate-limited),
- recover automatically when load returns to normal.

## Testing expectations
- Baseline snapshot before enabling the module
- Load test with representative bot counts and world load
- Compare:
  - average loop time,
  - spike frequency,
  - memory growth,
  - error rates
