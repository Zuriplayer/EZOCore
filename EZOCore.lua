EZOCore = EZOCore or {}
local EZOCore = EZOCore

EZOCore.name = "EZOCore"
EZOCore.version = "0.1.3"
EZOCore.addOnVersion = 103
EZOCore.apiVersion = 1

EZOCore.EVENT_INITIALIZED = "EZO_CORE_INITIALIZED"
EZOCore.EVENT_ADDON_REGISTERED = "EZO_CORE_ADDON_REGISTERED"
EZOCore.EVENT_SERVICE_REGISTERED = "EZO_CORE_SERVICE_REGISTERED"
EZOCore.EVENT_LANGUAGE_CHANGED = "EZO_CORE_LANGUAGE_CHANGED"

-- Internal state populated and consumed by modules/*.lua.
-- Session-local only: this is never stored in SavedVariables and is never used
-- as a network or cross-addon message bus.
EZOCore.internal = EZOCore.internal or {
    addons = {},
    services = {},
    callbacks = {},
}

--- Returns the current EZOCore version string.
function EZOCore:GetVersion()
    return self.version
end
