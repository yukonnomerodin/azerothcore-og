# CODE_SNAPSHOT_MERCENARY.md
# mod-mercenary-system — Current Code Snapshot

## Status
- Current PR level: PR-0 / PR-1 / PR-2 ...
- Last updated: YYYY-MM-DD

## Module tree
modules/mod-mercenary-system/
- include.sh
- conf/mod_mercenary_system.conf.dist
- sql/world/...
- src/mod-mercenary-system.cpp
- src/mod-mercenary-system_loader.cpp

## Key decisions (do not violate)
- Mercenaries are a permanent gameplay mechanic (always available).
- Population bots are a separate module; no coupling.
- No core modifications unless explicitly requested.
- Event-driven logic; no per-tick global scans.

## Current config keys
###############################################################################
# Mercenary System (mod-mercenary-system)
#
# Permanent gameplay mechanic. Always available.
# Must NOT depend on online population.
# Population bots are a separate module.
###############################################################################

[worldserver]

MercenarySystem.Enable = 1
MercenarySystem.AgentEntry = 900246
MercenarySystem.TankEntry   = 246
MercenarySystem.HealerEntry = 246
MercenarySystem.DpsEntry    = 246
MercenarySystem.MaxPerPlayer = 1
MercenarySystem.AllowInDungeons = 1
MercenarySystem.AllowInRaids = 0
MercenarySystem.AllowInBGs = 1
MercenarySystem.AllowInArenas = 0
MercenarySystem.AIUpdateIntervalMs = 300
MercenarySystem.Debug = 0


## SQL schema
-- PR-1: Mercenary hire persistence (world DB)

CREATE TABLE IF NOT EXISTS `mod_mercenary_hire` (
  `owner_guid` BIGINT UNSIGNED NOT NULL,
  `merc_guid`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `role`       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `active`     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`owner_guid`),
  KEY `idx_merc_guid` (`merc_guid`),
  KEY `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


## Current code (paste full files)
- mod-mercenary-system_loader.cpp
- mod-mercenary-system.cpp
### src/mod-mercenary-system_loader.cpp
```cpp
// modules/mod-mercenary-system/src/mod-mercenary-system_loader.cpp

void AddMercenarySystemScripts();

void Addmod_mercenary_systemScripts()
{
    AddMercenarySystemScripts();
}
```

### src/mod-mercenary-system.cpp
```cpp
// modules/mod-mercenary-system/src/mod-mercenary-system.cpp

#include "ScriptMgr.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "GameTime.h"
#include "Map.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptedGossip.h" // gossip helpers
#include "Configuration/Config.h"
#include "Log.h"

namespace Mercenary
{
    enum Role : uint8
    {
        ROLE_TANK   = 0,
        ROLE_HEALER = 1,
        ROLE_DPS    = 2
    };

    struct HireData
    {
        bool active = false;
        Role role = ROLE_TANK;
        ObjectGuid mercGuid = ObjectGuid::Empty;
        bool found = false;
    };

    static bool   s_Enable        = true;
    static uint32 s_AgentEntry    = 0;
    static uint32 s_TankEntry     = 0;
    static uint32 s_HealerEntry   = 0;
    static uint32 s_DpsEntry      = 0;
    static uint32 s_MaxPerPlayer  = 1;
    static uint32 s_AIUpdateMs    = 300;

    static bool s_AllowInDungeons = true;
    static bool s_AllowInRaids    = false;
    static bool s_AllowInBGs      = true;
    static bool s_AllowInArenas   = false;

    static bool s_Debug = false;

    static void LoadConfig()
    {
        s_Enable     = sConfigMgr->GetOption<bool>("MercenarySystem.Enable", true);
        s_AgentEntry = sConfigMgr->GetOption<uint32>("MercenarySystem.AgentEntry", 0);

        s_TankEntry   = sConfigMgr->GetOption<uint32>("MercenarySystem.TankEntry", 0);
        s_HealerEntry = sConfigMgr->GetOption<uint32>("MercenarySystem.HealerEntry", 0);
        s_DpsEntry    = sConfigMgr->GetOption<uint32>("MercenarySystem.DpsEntry", 0);

        s_MaxPerPlayer = sConfigMgr->GetOption<uint32>("MercenarySystem.MaxPerPlayer", 1);
        s_AIUpdateMs   = sConfigMgr->GetOption<uint32>("MercenarySystem.AIUpdateIntervalMs", 300);

        s_AllowInDungeons = sConfigMgr->GetOption<bool>("MercenarySystem.AllowInDungeons", true);
        s_AllowInRaids    = sConfigMgr->GetOption<bool>("MercenarySystem.AllowInRaids", false);
        s_AllowInBGs      = sConfigMgr->GetOption<bool>("MercenarySystem.AllowInBGs", true);
        s_AllowInArenas   = sConfigMgr->GetOption<bool>("MercenarySystem.AllowInArenas", false);

        s_Debug = sConfigMgr->GetOption<bool>("MercenarySystem.Debug", false);

        if (s_Debug)
        {
            LOG_INFO("module",
                "[Mercenary] Config: Enable={}, AgentEntry={}, TankEntry={}, HealerEntry={}, DpsEntry={}, MaxPerPlayer={}, AIUpdateMs={}",
                s_Enable, s_AgentEntry, s_TankEntry, s_HealerEntry, s_DpsEntry, s_MaxPerPlayer, s_AIUpdateMs);
        }
    }

    static bool IsAllowedHere(Player* player)
    {
        if (!player)
            return false;

        Map* map = player->GetMap();
        if (!map)
            return false;

        if (map->IsDungeon() && !map->IsRaid() && !s_AllowInDungeons)
            return false;

        if (map->IsRaid() && !s_AllowInRaids)
            return false;

        if (map->IsBattlegroundOrArena())
        {
            if (map->IsBattleArena())
                return s_AllowInArenas;

            return s_AllowInBGs;
        }

        return true;
    }

    static uint32 EntryForRole(Role role)
    {
        switch (role)
        {
            case ROLE_TANK:   return s_TankEntry;
            case ROLE_HEALER: return s_HealerEntry;
            case ROLE_DPS:    return s_DpsEntry;
            default:          return 0;
        }
    }

    static HireData DB_LoadHire(uint64 ownerGuidRaw)
    {
        HireData data;
        if (QueryResult result = WorldDatabase.Query(
                "SELECT role, active, merc_guid FROM mod_mercenary_hire WHERE owner_guid = {}",
                ownerGuidRaw))
        {
            Field* fields = result->Fetch();
            data.role = Role(fields[0].Get<uint8>());
            data.active = fields[1].Get<uint8>() != 0;
            data.mercGuid = ObjectGuid(fields[2].Get<uint64>());
            data.found = true;
        }
        return data;
    }

    static void DB_UpsertHire(uint64 ownerGuidRaw, Role role, bool active, uint64 mercGuidRaw)
    {
        WorldDatabase.Execute(
            "INSERT INTO mod_mercenary_hire (owner_guid, merc_guid, role, active) "
            "VALUES ({}, {}, {}, {}) "
            "ON DUPLICATE KEY UPDATE merc_guid = VALUES(merc_guid), role = VALUES(role), active = VALUES(active)",
            ownerGuidRaw, mercGuidRaw, uint32(role), active ? 1 : 0
        );
    }

    static void DB_UpdateMercGuid(uint64 ownerGuidRaw, uint64 mercGuidRaw)
    {
        WorldDatabase.Execute(
            "UPDATE mod_mercenary_hire SET merc_guid = {} WHERE owner_guid = {}",
            mercGuidRaw, ownerGuidRaw
        );
    }

    static void DB_UpdateActive(uint64 ownerGuidRaw, bool active)
    {
        WorldDatabase.Execute(
            "UPDATE mod_mercenary_hire SET active = {} WHERE owner_guid = {}",
            active ? 1 : 0, ownerGuidRaw
        );
    }

    static bool DespawnMerc(Player* player, ObjectGuid mercGuid)
    {
        if (!player || mercGuid.IsEmpty())
            return false;

        if (Creature* merc = ObjectAccessor::GetCreature(*player, mercGuid))
        {
            merc->DespawnOrUnsummon(0);
            return true;
        }

        return false;
    }

    static void LogMissingEntry(uint32 entry, char const* context)
    {
        static Seconds lastLogTime = Seconds(0);
        Seconds now = GameTime::GetGameTime();

        if (now - lastLogTime < Seconds(60))
            return;

        lastLogTime = now;
        LOG_ERROR("module", "[Mercenary] Missing creature entry {} for {}.", entry, context);
    }

    static Creature* SpawnMerc(Player* player, Role role)
    {
        if (!player || !player->IsInWorld())
            return nullptr;

        if (!s_Enable || !IsAllowedHere(player))
            return nullptr;

        HireData hire = DB_LoadHire(player->GetGUID().GetRawValue());
        if (s_MaxPerPlayer <= 1 && hire.found && hire.active)
        {
            if (!hire.mercGuid.IsEmpty())
            {
                if (Creature* existing = ObjectAccessor::GetCreature(*player, hire.mercGuid))
                    return existing;
            }
        }

        uint32 entry = EntryForRole(role);
        if (entry == 0)
        {
            LogMissingEntry(entry, "mercenary role");
            return nullptr;
        }

        Position pos = player->GetPosition();
        Creature* merc = player->SummonCreature(entry, pos, TEMPSUMMON_MANUAL_DESPAWN);
        if (!merc)
            return nullptr;

        merc->SetOwnerGUID(player->GetGUID());
        merc->SetFaction(player->GetFaction());
        merc->SetReactState(REACT_DEFENSIVE);

        DB_UpsertHire(player->GetGUID().GetRawValue(), role, true, merc->GetGUID().GetRawValue());

        if (s_Debug)
            LOG_INFO("module", "[Mercenary] Spawned merc role={} entry={} for {}", uint32(role), entry, player->GetName());

        return merc;
    }

    static void EnsureMercenaryState(Player* player)
    {
        if (!player || !player->IsInWorld())
            return;

        HireData hire = DB_LoadHire(player->GetGUID().GetRawValue());
        if (!hire.found || !hire.active)
            return;

        if (!IsAllowedHere(player))
        {
            if (DespawnMerc(player, hire.mercGuid))
                DB_UpdateMercGuid(player->GetGUID().GetRawValue(), 0);
            return;
        }

        if (!hire.mercGuid.IsEmpty())
        {
            if (ObjectAccessor::GetCreature(*player, hire.mercGuid))
                return;

            DB_UpdateMercGuid(player->GetGUID().GetRawValue(), 0);
        }

        SpawnMerc(player, hire.role);
    }

    static void CleanupMercenary(Player* player)
    {
        if (!player)
            return;

        HireData hire = DB_LoadHire(player->GetGUID().GetRawValue());
        if (!hire.found)
            return;

        if (DespawnMerc(player, hire.mercGuid))
            DB_UpdateMercGuid(player->GetGUID().GetRawValue(), 0);
    }
}

// ----------------------------------------------------
// Scripts
// ----------------------------------------------------

class MercenarySystem_WorldScript : public WorldScript
{
public:
    MercenarySystem_WorldScript() : WorldScript("MercenarySystem_WorldScript") {}

    void OnStartup() override
    {
        Mercenary::LoadConfig();
    }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        Mercenary::LoadConfig();
    }
};

enum MercGossipActions : uint32
{
    ACTION_HIRE_TANK   = 100,
    ACTION_HIRE_HEALER = 101,
    ACTION_HIRE_DPS    = 102,
    ACTION_DISMISS     = 103
};

class MercenaryAgent_CreatureScript : public CreatureScript
{
public:
    MercenaryAgent_CreatureScript() : CreatureScript("MercenaryAgent_CreatureScript") {}

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return true;

        // Only act on configured AgentEntry
        if (Mercenary::s_AgentEntry == 0 || creature->GetEntry() != Mercenary::s_AgentEntry)
            return true;

        ClearGossipMenuFor(player);

        if (!Mercenary::s_Enable)
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Mercenary system is disabled.", GOSSIP_SENDER_MAIN, 999);
            SendGossipMenuFor(player, 1, creature->GetGUID());
            return true;
        }

        if (!Mercenary::IsAllowedHere(player))
        {
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Mercenaries are not allowed here.", GOSSIP_SENDER_MAIN, 999);
            SendGossipMenuFor(player, 1, creature->GetGUID());
            return true;
        }

        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Hire: Tank",   GOSSIP_SENDER_MAIN, ACTION_HIRE_TANK);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Hire: Healer", GOSSIP_SENDER_MAIN, ACTION_HIRE_HEALER);
        AddGossipItemFor(player, GOSSIP_ICON_BATTLE, "Hire: DPS",    GOSSIP_SENDER_MAIN, ACTION_HIRE_DPS);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT,   "Dismiss",      GOSSIP_SENDER_MAIN, ACTION_DISMISS);

        SendGossipMenuFor(player, 1, creature->GetGUID());
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        if (!player || !creature)
            return true;

        if (Mercenary::s_AgentEntry == 0 || creature->GetEntry() != Mercenary::s_AgentEntry)
            return true;

        CloseGossipMenuFor(player);

        switch (action)
        {
            case ACTION_HIRE_TANK:
                Mercenary::SpawnMerc(player, Mercenary::ROLE_TANK);
                break;
            case ACTION_HIRE_HEALER:
                Mercenary::SpawnMerc(player, Mercenary::ROLE_HEALER);
                break;
            case ACTION_HIRE_DPS:
                Mercenary::SpawnMerc(player, Mercenary::ROLE_DPS);
                break;
            case ACTION_DISMISS:
            default:
            {
                Mercenary::CleanupMercenary(player);
                Mercenary::DB_UpdateActive(player->GetGUID().GetRawValue(), false);
                break;
            }
        }

        return true;
    }
};

class MercenarySystem_PlayerScript : public PlayerScript
{
public:
    MercenarySystem_PlayerScript() : PlayerScript("MercenarySystem_PlayerScript") {}

    void OnPlayerLogin(Player* player) override
    {
        Mercenary::EnsureMercenaryState(player);
    }

    void OnPlayerLogout(Player* player) override
    {
        Mercenary::CleanupMercenary(player);
    }

    void OnPlayerUpdateZone(Player* player, uint32 /*newZone*/, uint32 /*newArea*/) override
    {
        Mercenary::EnsureMercenaryState(player);
    }

    void OnPlayerJoinBG(Player* player) override
    {
        if (player && !Mercenary::s_AllowInBGs)
            Mercenary::CleanupMercenary(player);
    }

    void OnPlayerJoinArena(Player* player) override
    {
        if (player && !Mercenary::s_AllowInArenas)
            Mercenary::CleanupMercenary(player);
    }
};

void AddMercenarySystemScripts()
{
    new MercenarySystem_WorldScript();
    new MercenaryAgent_CreatureScript();
    new MercenarySystem_PlayerScript();
}


```
