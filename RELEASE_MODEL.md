# WoW LK Custom Server — Release Model

## Concept
The server evolves through patches and seasonal updates. A patch can include:
- new systems,
- progression changes,
- content additions,
- balance and economy adjustments.

Permanent mechanics (e.g., Mercenaries) remain available across seasons; seasons may adjust tuning and content integration, not existence.

## Patch lifecycle
1. Design brief: goal, constraints, success metrics
2. Implementation: module(s), toggles, migrations
3. Testing: load tests, smoke tests, bot simulations
4. Release: patch notes + monitoring plan
5. Post-release: observe metrics, hotfix if required
6. Review: what worked, what to change next season

## Versioning
- Semantic versioning for server releases: `MAJOR.MINOR.PATCH`
- Patch identifiers for content cadence: `Patch 1`, `Patch 2`, etc.
- Maintain `CHANGELOG.md` for history.

## Rollback philosophy
- Prefer “disable module + revert config” as first-line rollback.
- Schema changes must be deliberate; document rollback constraints.

## Cadence
Patches ship when stability and performance gates are met.
Consistency is preferred over rushed releases.
