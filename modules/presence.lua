local EZOCore = EZOCore

-- Local presence facade over the addon registry.
-- This is intentionally local-only; no LibGroupBroadcast traffic is sent here.

local PRESENCE = {}
EZOCore.Presence = PRESENCE

local SERVICE_NAME = "family.presence"
local SERVICE_API_VERSION = 1

local function CopyCapabilities(capabilities)
    local out = {}
    if type(capabilities) ~= "table" then
        return out
    end

    for capability, enabled in pairs(capabilities) do
        if enabled == true then
            out[#out + 1] = capability
        end
    end
    table.sort(out)
    return out
end

local function BuildPresenceRecord(addon)
    if type(addon) ~= "table" then
        return nil
    end

    return {
        id = addon.id,
        name = addon.name,
        version = addon.version,
        addOnVersion = addon.addOnVersion,
        apiVersion = addon.apiVersion,
        capabilities = CopyCapabilities(addon.capabilities),
        debugName = addon.debugName,
        build = addon.build,
    }
end

function PRESENCE.GetLocalAddons()
    local addons = EZOCore:GetRegisteredAddons()
    local out = {}

    for index = 1, #addons do
        out[#out + 1] = BuildPresenceRecord(addons[index])
    end

    table.sort(out, function(left, right)
        return tostring(left.id or "") < tostring(right.id or "")
    end)
    return out
end

function PRESENCE.GetLocalAddon(_, addonId)
    return BuildPresenceRecord(EZOCore:GetAddon(addonId))
end

function PRESENCE.HasLocalAddon(_, addonId, minimumApiVersion)
    return EZOCore:HasAddon(addonId, minimumApiVersion)
end

function PRESENCE.HasLocalCapability(_, addonId, capability, minimumApiVersion)
    return EZOCore:HasCapability(addonId, capability, minimumApiVersion)
end

function PRESENCE.GetLocalSummary()
    return {
        core = {
            id = "ezocore",
            version = EZOCore.version,
            addOnVersion = EZOCore.addOnVersion,
            apiVersion = EZOCore.apiVersion,
        },
        addons = PRESENCE.GetLocalAddons(),
    }
end

EZOCore:RegisterService(SERVICE_NAME, SERVICE_API_VERSION, PRESENCE)
