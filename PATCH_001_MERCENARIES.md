# PATCH_001_MERCENARIES.md
# Patch 1 — Mercenary System

## Goal
Introduce a **permanent Mercenary System** that allows players to progress solo
or in small groups regardless of server population.

This system is always available and forms the core identity of the server.

---

## Clarification: Mercenaries vs Population Bots
- Mercenaries are a gameplay mechanic (always available).
- They may be implemented using bot-style AI internally.
- Population bots are a separate infrastructure module.
- Mercenary availability must NEVER depend on online player count.

---

## Scope

### Included (Patch 1)

#### PR-1 (initial release)
- Hireable mercenary via NPC “Mercenary Agent”
- Roles:
  - Tank
  - Healer
  - DPS
- Hire / Dismiss flow
- Persistence (hire state saved in DB)
- Restore on login / map change
- Configuration and guardrails (content restrictions)

#### PR-2 (follow-up within Patch 1)
- Basic control modes:
  - Follow
  - Stay
  - Assist
- Throttled AI update loop


### Excluded (explicitly NOT in Patch 1)
- Advanced combat rotations
- Mercenary gear management
- Multiple mercenaries per player
- Raid optimization
- PvP balancing

---

## System Overview
A mercenary is a player-bound companion NPC.
Patch 1 is delivered in stages:
- PR-1 focuses on hire/dismiss, persistence, and safe lifecycle handling.
- PR-2 introduces basic behavior controls and AI updates.


Its purpose is to:
- fill missing group roles
- reduce friction in solo play
- support progression without replacing real players

---

## Entry Point: Mercenary Agent (NPC)

### Interaction (PR-1)
- Gossip-based UI:
  - Hire Tank / Healer / DPS
  - Dismiss

### Restrictions (Patch 1 defaults)
- One mercenary per player
- Not allowed in arenas / raids / battlegrounds by default (configurable)

### Implementation note (Best practice for PR-1)
We do NOT require a “free NPC entry id” for Mercenary Agent in PR-1.
Instead, we bind the agent behavior to an existing NPC entry via config:
- `Mercenary.AgentEntry = <existing creature_template entry>`
You can spawn it with `.npc add <entry>`.

---

## Technical Implementation

### Module
`modules/mod-mercenary-system/`

### Repo integration pattern (this repository)
- Module integration via `modules/mod-mercenary-system/include.sh`
- Loader pattern:
  - `Addmod_mercenary_systemScripts()` in `*_loader.cpp`
  - calls a module registration function in the main `.cpp`

No AzerothCore core modifications.

### Script hooks (PR-1)
- **CreatureScript**
  - GossipHello / GossipSelect (Mercenary Agent)
- **PlayerScript**
  - OnLogin / OnLogout
  - OnMapChanged (enforce restrictions + restore)
- **WorldScript**
  - OnStartup / OnAfterConfigLoad (config load/reload)

---

## Data Model (PR-1)

### Database
World database

### Table: `mod_mercenary_hire`
Stores mercenary hire state per player.

Fields:
- `owner_guid` — Player GUID (primary key)
- `merc_guid` — Currently spawned mercenary creature GUID (0 if not spawned)
- `role` — Mercenary role (0 = Tank, 1 = Healer, 2 = DPS)
- `active` — Hire state (0 = dismissed, 1 = active)
- `created_at` — Hire creation timestamp
- `updated_at` — Last update timestamp

Notes:
- Only one mercenary per player is supported in Patch 1.
- `active = 1` with `merc_guid = 0` means the mercenary is hired but not currently spawned (e.g. after logout).

---

## Configuration (conf.dist)

### Required keys (PR-1)
MercenarySystem.Enable
MercenarySystem.AgentEntry
MercenarySystem.TankEntry
MercenarySystem.HealerEntry
MercenarySystem.DpsEntry
MercenarySystem.MaxPerPlayer
MercenarySystem.AllowInDungeons
MercenarySystem.AllowInRaids
MercenarySystem.AllowInBGs
MercenarySystem.AllowInArenas
MercenarySystem.AIUpdateIntervalMs (reserved for PR-2+)
MercenarySystem.Debug

---

## Performance Budget
- Event-driven logic only (gossip, login/logout, map change)
- No per-tick global scans
- Minimal DB access (only on events)
- Degrade safely by despawning mercenary in restricted contexts

---

## Restrictions (Patch 1 defaults)
- Arenas: disabled
- Raids: disabled
- Battlegrounds: disabled
- Dungeons: allowed

All configurable.

---

## Success Metrics

### Gameplay
- Mercenary adoption rate
- Solo progression success
- Session length (solo players)

### Performance
- World loop time before vs after
- Spike frequency
- Memory usage
- Error/log rates

---

## Rollback Plan
1. Disable `Mercenary.Enable`
2. Restart worldserver
3. Mercenaries despawn safely
4. No core data affected

---

## Player-facing Patch Notes (Draft)
- Added permanent Mercenary System
- Hire a Tank, Healer, or DPS companion via Mercenary Agent
- Designed for solo and small-group play
- Optional and configurable
