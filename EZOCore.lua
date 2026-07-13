EZOCore = EZOCore or {}
local EZOCore = EZOCore

EZOCore.name = "EZOCore"
EZOCore.version = "0.1.0"

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
