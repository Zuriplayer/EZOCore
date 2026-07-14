local EZOCore = EZOCore

-- Entry point: wires up initialization once the addon has fully loaded.
-- Local phase only: no LibGroupBroadcast, no group/guild messaging here.

local function OnAddOnLoaded(_, addonName)
    if addonName ~= EZOCore.name then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(EZOCore.name, EVENT_ADD_ON_LOADED)

    if EZOCore.Language and type(EZOCore.Language.Initialize) == "function" then
        EZOCore.Language.Initialize()
    end

    EZOCore:RegisterAddon({
        id = "ezocore",
        name = EZOCore.name,
        version = EZOCore.version,
        addOnVersion = EZOCore.addOnVersion,
        apiVersion = EZOCore.apiVersion,
        capabilities = {
            "family.presence",
            "family.debug",
            "family.language",
            "family.layout",
            "family.settings",
        },
    })

    if EZOCore.DebugService then
        EZOCore:RegisterService(
            EZOCore.DebugService.name,
            EZOCore.DebugService.apiVersion,
            EZOCore.DebugService
        )
    end

    if EZOCore.GroupPresence and type(EZOCore.GroupPresence.Initialize) == "function" then
        EZOCore.GroupPresence.Initialize()
    end

    if EZOCore.Layout and type(EZOCore.Layout.Initialize) == "function" then
        EZOCore.Layout.Initialize()
    end

    if EZOCore.InitializeSettings then
        EZOCore.InitializeSettings()
    end

    EZOCore:Info("%s v%s initialized (local service phase).", EZOCore.name, EZOCore.version)
    EZOCore:FireCallback(EZOCore.EVENT_INITIALIZED, EZOCore)
    EZOCore:FireCallback("EZOCore:Initialized", EZOCore)
end

EVENT_MANAGER:RegisterForEvent(EZOCore.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
