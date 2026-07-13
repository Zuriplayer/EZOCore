local EZOCore = EZOCore

-- Entry point: wires up initialization once the addon has fully loaded.
-- Local phase only: no LibGroupBroadcast, no group/guild messaging here.

local function OnAddOnLoaded(_, addonName)
    if addonName ~= EZOCore.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(EZOCore.name, EVENT_ADD_ON_LOADED)

    EZOCore:RegisterAddon({
        id = "ezocore",
        name = EZOCore.name,
        version = EZOCore.version,
        addOnVersion = EZOCore.addOnVersion,
        apiVersion = EZOCore.apiVersion,
        capabilities = {
            "family.presence",
        },
    })

    EZOCore:Info("%s v%s initialized (local service phase).", EZOCore.name, EZOCore.version)
    EZOCore:FireCallback(EZOCore.EVENT_INITIALIZED, EZOCore)
    EZOCore:FireCallback("EZOCore:Initialized", EZOCore)
end

EVENT_MANAGER:RegisterForEvent(EZOCore.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
