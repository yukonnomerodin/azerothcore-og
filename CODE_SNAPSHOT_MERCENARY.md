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
- Mercenary.Enable = 1
- Mercenary.AgentEntry = 0
- Mercenary.TankEntry   = 0
- Mercenary.HealerEntry = 0
- Mercenary.DpsEntry    = 0
- Mercenary.MaxPerPlayer = 1
- Mercenary.AllowInDungeons = 1
- Mercenary.AllowInRaids = 0
- Mercenary.AllowInBattlegrounds = 0
- Mercenary.AllowInArenas = 0
- Mercenary.AIUpdateIntervalMs = 300
- Mercenary.Debug = 0


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
#include "Player.h"
#include "Creature.h"
#include "ObjectAccessor.h"
#include "DatabaseEnv.h"
#include "Config.h"
#include "Log.h"
#include "Map.h"

#include <unordered_map>
#include <mutex>

namespace Mercenary
{
    enum Role : uint8
    {
        ROLE_TANK   = 0,
        ROLE_HEALER = 1,
        ROLE_DPS    = 2
    };

    static bool s_Enable = true;
    static uint32 s_AgentEntry = 0;
    static uint32 s_TankEntry = 0;
    static uint32 s_HealerEntry = 0;
    static uint32 s_DpsEntry = 0;

    static uint32 s_MaxPerPlayer = 1;

    static bool s_AllowInDungeons = true;
    static bool s_AllowInRaids = false;
    static bool s_AllowInBGs = false;
    static bool s_AllowInArenas = false;

    static bool s_Debug = false;

    static std::mutex s_Mtx;
    // owner_guid_raw -> merc_guid_raw (runtime only)
    static std::unordered_map<uint64, uint64> s_OwnerToMerc;

    static void LoadConfig()
    {
        s_Enable = sConfigMgr->GetOption<bool>("Mercenary.Enable", true);

        s_AgentEntry = sConfigMgr->GetOption<uint32>("Mercenary.AgentEntry", 0);
        s_TankEntry  = sConfigMgr->GetOption<uint32>("Mercenary.TankEntry", 0);
        s_HealerEntry= sConfigMgr->GetOption<uint32>("Mercenary.HealerEntry", 0);
        s_DpsEntry   = sConfigMgr->GetOption<uint32>("Mercenary.DpsEntry", 0);

        s_MaxPerPlayer = sConfigMgr->GetOption<uint32>("Mercenary.MaxPerPlayer", 1);

        s_AllowInDungeons = sConfigMgr->GetOption<bool>("Mercenary.AllowInDungeons", true);
        s_AllowInRaids    = sConfigMgr->GetOption<bool>("Mercenary.AllowInRaids", false);
        s_AllowInBGs      = sConfigMgr->GetOption<bool>("Mercenary.AllowInBattlegrounds", false);
        s_AllowInArenas   = sConfigMgr->GetOption<bool>("Mercenary.AllowInArenas", false);

        s_Debug = sConfigMgr->GetOption<bool>("Mercenary.Debug", false);

        if (s_Debug)
        {
            LOG_INFO("module", "[Mercenary] Config loaded: Enable={}, AgentEntry={}, TankEntry={}, HealerEntry={}, DpsEntry={}, MaxPerPlayer={}",
                s_Enable, s_AgentEntry, s_TankEntry, s_HealerEntry, s_DpsEntry, s_MaxPerPlayer);
        }
    }

    static bool IsAllowedHere(Player* player)
    {
        if (!player)
            return false;

        Map* map = player->GetMap();
        if (!map)
            return false;

        // Dungeons/Raids
        if (map->IsDungeon() && !map->IsRaid() && !s_AllowInDungeons)
            return false;

        if (map->IsRaid() && !s_AllowInRaids)
            return false;

        // BG / Arena separation
        if (map->IsBattlegroundOrArena())
        {
            // Conservative: if arena-like => arenas flag
            if (map->IsBattleArena())
                return s_AllowInArenas;

            // Otherwise treat as BG
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

    static void DB_SetHire(uint64 ownerGuidRaw, Role role, bool active, uint64 mercGuidRaw)
    {
        // REPLACE INTO style: keep it simple and safe for PR-1
        WorldDatabase.Execute(
            "REPLACE INTO mod_mercenary_hire (owner_guid, merc_guid, role, active) VALUES ({}, {}, {}, {})",
            ownerGuidRaw, mercGuidRaw, uint32(role), active ? 1 : 0
        );
    }

    static bool DB_GetHire(uint64 ownerGuidRaw, Role& outRole, bool& outActive)
    {
        QueryResult result = WorldDatabase.Query(
            "SELECT role, active FROM mod_mercenary_hire WHERE owner_guid = {}",
            ownerGuidRaw
        );

        if (!result)
            return false;

        Field* f = result->Fetch();
        outRole = Role(f[0].Get<uint8>());
        outActive = (f[1].Get<uint8>() != 0);
        return true;
    }

    static void DB_ClearMercGuid(uint64 ownerGuidRaw)
    {
        WorldDatabase.Execute(
            "UPDATE mod_mercenary_hire SET merc_guid = 0 WHERE owner_guid = {}",
            ownerGuidRaw
        );
    }

    static Creature* GetSpawnedMerc(Player* player)
    {
        std::lock_guard<std::mutex> g(s_Mtx);
        auto it = s_OwnerToMerc.find(player->GetGUID().GetRawValue());
        if (it == s_OwnerToMerc.end() || it->second == 0)
            return nullptr;

        ObjectGuid mercGuid(it->second);
        return ObjectAccessor::GetCreature(*player, mercGuid);
    }

    static void RememberMerc(Player* player, Creature* merc)
    {
        std::lock_guard<std::mutex> g(s_Mtx);
        s_OwnerToMerc[player->GetGUID().GetRawValue()] = merc ? merc->GetGUID().GetRawValue() : 0;
    }

    static void ForgetMerc(Player* player)
    {
        std::lock_guard<std::mutex> g(s_Mtx);
        s_OwnerToMerc.erase(player->GetGUID().GetRawValue());
    }

    static bool DespawnMerc(Player* player)
    {
        if (!player)
            return false;

        Creature* merc = GetSpawnedMerc(player);
        if (!merc)
            return false;

        merc->DespawnOrUnsummon();
        RememberMerc(player, nullptr);
        DB_ClearMercGuid(player->GetGUID().GetRawValue());
        return true;
    }

    static bool SpawnMerc(Player* player, Role role)
    {
        if (!player || !player->IsInWorld())
            return false;

        if (!s_Enable)
            return false;

        if (!IsAllowedHere(player))
            return false;

        uint32 entry = EntryForRole(role);
        if (entry == 0)
            return false;

        // PR-1: ensure only one active merc
        DespawnMerc(player);

        Position pos = player->GetPosition();
        Creature* merc = player->SummonCreature(entry, pos, TEMPSUMMON_MANUAL_DESPAWN);

        if (!merc)
            return false;

        merc->SetOwnerGUID(player->GetGUID());
        merc->SetFaction(player->GetFaction());
        merc->SetReactState(REACT_DEFENSIVE);

        RememberMerc(player, merc);

        // Persist: active=1, role, merc_guid=raw (best-effort)
        DB_SetHire(player->GetGUID().GetRawValue(), role, true, merc->GetGUID().GetRawValue());

        if (s_Debug)
        {
            LOG_INFO("module", "[Mercenary] Spawned merc entry={} role={} for player={}", entry, uint32(role), player->GetName());
        }

        return true;
    }

    static void RestoreIfActive(Player* player)
    {
        if (!player || !player->IsInWorld() || !s_Enable)
            return;

        Role role;
        bool active;
        if (!DB_GetHire(player->GetGUID().GetRawValue(), role, active))
            return;

        if (!active)
            return;

        if (!IsAllowedHere(player))
        {
            // Keep hire active, just ensure not spawned here
            DespawnMerc(player);
            return;
        }

        // Spawn placeholder for now
        SpawnMerc(player, role);
    }
}

// -----------------------------------------------------------------------------
// Scripts
// -----------------------------------------------------------------------------

class MercenarySystem_WorldScript : public WorldScript
{
public:
    MercenarySystem_WorldScript() : WorldScript("MercenarySystem_WorldScript") { }

    void OnStartup() override
    {
        Mercenary::LoadConfig();
    }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        Mercenary::LoadConfig();
    }
};

class MercenarySystem_PlayerScript : public PlayerScript
{
public:
    MercenarySystem_PlayerScript() : PlayerScript("MercenarySystem_PlayerScript") { }

    void OnLogin(Player* player) override
    {
        Mercenary::RestoreIfActive(player);
    }

    void OnLogout(Player* player) override
    {
        // Keep hire active, but despawn to be safe.
        Mercenary::DespawnMerc(player);
        Mercenary::ForgetMerc(player);
    }

    void OnMapChanged(Player* player) override
    {
        // Enforce restrictions on transitions
        if (!Mercenary::IsAllowedHere(player))
        {
            Mercenary::DespawnMerc(player);
            return;
        }

        // If hire is active, restore
        Mercenary::RestoreIfActive(player);
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
    MercenaryAgent_CreatureScript() : CreatureScript("MercenaryAgent_CreatureScript") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!player || !creature)
            return true;

        if (!Mercenary::s_Enable)
            return true;

        // Only act on configured AgentEntry
        if (Mercenary::s_AgentEntry == 0 || creature->GetEntry() != Mercenary::s_AgentEntry)
            return true;

        if (!Mercenary::IsAllowedHere(player))
        {
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Mercenaries are not allowed here.", GOSSIP_SENDER_MAIN, 999);
            SendGossipMenuFor(player, 1, creature->GetGUID());
            return true;
        }

        ClearGossipMenuFor(player);

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

        if (!Mercenary::s_Enable)
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
                Mercenary::DB_SetHire(player->GetGUID().GetRawValue(), Mercenary::ROLE_TANK /*unused*/, false, 0);
                Mercenary::DespawnMerc(player);
                break;
        }

        return true;
    }
};

void AddMercenarySystemScripts()
{
    new MercenarySystem_WorldScript();
    new MercenarySystem_PlayerScript();
    new MercenaryAgent_CreatureScript();
}
```
