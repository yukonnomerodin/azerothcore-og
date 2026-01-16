// modules/mod-mercenary-system/src/mod-mercenary-system.cpp

#include "ScriptMgr.h"

// PR-0: Skeleton only.
// No gameplay logic, no hooks yet.
// Next PR will add config load + gossip entrypoints.

class MercenarySystem_WorldScript : public WorldScript
{
public:
    MercenarySystem_WorldScript() : WorldScript("MercenarySystem_WorldScript") { }

    void OnStartup() override
    {
        // PR-0: no-op
    }
};

void AddMercenarySystemScripts()
{
    new MercenarySystem_WorldScript();
}
