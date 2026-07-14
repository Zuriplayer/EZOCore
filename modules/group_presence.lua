local EZOCore = EZOCore

-- Remote/group presence state for future LibGroupBroadcast transport.
-- The transport stays disabled until EZO reserves official LibGroupBroadcast IDs.

local GROUP_PRESENCE = {}
EZOCore.GroupPresence = GROUP_PRESENCE

local SERVICE_NAME = "family.groupPresence"
local SERVICE_API_VERSION = 1

local PRESENCE_PROTOCOL_VERSION = 1
local PEER_TTL_SECONDS = 90

-- Do not publish traffic with invented IDs. Fill these only after reserving
-- official values on https://wiki.esoui.com/LibGroupBroadcast_IDs.
local LGB_HANDLER_NAME = "EZOCore"
local LGB_PROTOCOL_READY = false
local LGB_PROTOCOL_ID = nil
local LGB_PROTOCOL_NAME = "EZO_CORE_PRESENCE_V1"
local LGB_REQUEST_EVENT_ID = nil
local LGB_REQUEST_EVENT_NAME = "EZO_CORE_PRESENCE_REQUEST_V1"

local peersByUnitTag = {}
local sequence = 0
local initialized = false
local handler
local protocol
local firePresenceRequest
local status = {
    available = false,
    configured = false,
    active = false,
    reason = "notInitialized",
}

local function NowSeconds()
    if type(_G.GetFrameTimeSeconds) == "function" then
        return _G.GetFrameTimeSeconds()
    end
    return os.time()
end

local function CopyArray(value)
    local out = {}
    if type(value) ~= "table" then
        return out
    end

    for index = 1, #value do
        out[index] = value[index]
    end
    return out
end

local function CopyAddon(addon)
    if type(addon) ~= "table" then
        return nil
    end

    return {
        id = addon.id,
        name = addon.name,
        version = addon.version,
        addOnVersion = addon.addOnVersion,
        apiVersion = addon.apiVersion,
        capabilities = CopyArray(addon.capabilities),
    }
end

local function CopyPeer(peer)
    if type(peer) ~= "table" then
        return nil
    end

    local addons = {}
    for addonId, addon in pairs(peer.addons or {}) do
        addons[addonId] = CopyAddon(addon)
    end

    return {
        unitTag = peer.unitTag,
        displayName = peer.displayName,
        coreApiVersion = peer.coreApiVersion,
        coreVersion = peer.coreVersion,
        coreAddOnVersion = peer.coreAddOnVersion,
        protocolVersion = peer.protocolVersion,
        sequence = peer.sequence,
        receivedAt = peer.receivedAt,
        expiresAt = peer.expiresAt,
        addons = addons,
    }
end

local function BuildCapabilitySet(capabilities)
    local out = {}
    if type(capabilities) ~= "table" then
        return out
    end

    for index = 1, #capabilities do
        local capability = capabilities[index]
        if type(capability) == "string" and capability ~= "" then
            out[capability] = true
        end
    end
    return out
end

local function NormalizeRemoteAddons(addons)
    local out = {}
    if type(addons) ~= "table" then
        return out
    end

    for index = 1, #addons do
        local addon = CopyAddon(addons[index])
        if addon and type(addon.id) == "string" and addon.id ~= "" then
            addon.capabilitySet = BuildCapabilitySet(addon.capabilities)
            out[string.lower(addon.id)] = addon
        end
    end
    return out
end

local function IsPeerExpired(peer, now)
    return type(peer) ~= "table" or (tonumber(peer.expiresAt) or 0) <= now
end

local function ResolveDisplayName(unitTag)
    if type(_G.GetUnitDisplayName) == "function" then
        local displayName = _G.GetUnitDisplayName(unitTag)
        if type(displayName) == "string" and displayName ~= "" then
            return displayName
        end
    end
    return nil
end

local function GetLibGroupBroadcast()
    local lgb = _G.LibGroupBroadcast
    if type(lgb) ~= "table" or type(lgb.RegisterHandler) ~= "function" then
        return nil
    end
    return lgb
end

local function RefreshStatus()
    local lgb = GetLibGroupBroadcast()
    status.available = lgb ~= nil
    status.configured = LGB_PROTOCOL_READY == true
        and type(LGB_PROTOCOL_ID) == "number"
        and type(LGB_REQUEST_EVENT_ID) == "number"
    status.active = status.available and status.configured and protocol ~= nil

    if not status.available then
        status.reason = "libGroupBroadcastMissing"
    elseif LGB_PROTOCOL_READY ~= true then
        status.reason = "protocolDefinitionPending"
    elseif not status.configured then
        status.reason = "reservedIdsMissing"
    elseif not status.active then
        status.reason = "transportNotInitialized"
    else
        status.reason = "active"
    end
end

local function GetLocalPresencePayload()
    sequence = (sequence % 65535) + 1
    local presence = EZOCore.Presence
    local addons = presence and presence.GetLocalAddons and presence.GetLocalAddons() or {}

    return {
        coreApiVersion = EZOCore.apiVersion,
        coreVersion = EZOCore.version,
        coreAddOnVersion = EZOCore.addOnVersion,
        protocolVersion = PRESENCE_PROTOCOL_VERSION,
        sequence = sequence,
        ttlSeconds = PEER_TTL_SECONDS,
        addons = addons,
    }
end

local function HandleRemotePresence(unitTag, data)
    if type(unitTag) ~= "string" or unitTag == "" or type(data) ~= "table" then
        return false
    end

    local now = NowSeconds()
    local previous = peersByUnitTag[unitTag]
    local incomingSequence = tonumber(data.sequence) or 0
    if previous and incomingSequence > 0 and incomingSequence <= (tonumber(previous.sequence) or 0) then
        return false
    end

    local ttl = math.max(15, math.min(tonumber(data.ttlSeconds) or PEER_TTL_SECONDS, 300))
    peersByUnitTag[unitTag] = {
        unitTag = unitTag,
        displayName = ResolveDisplayName(unitTag),
        coreApiVersion = tonumber(data.coreApiVersion) or 0,
        coreVersion = tostring(data.coreVersion or ""),
        coreAddOnVersion = tonumber(data.coreAddOnVersion) or 0,
        protocolVersion = tonumber(data.protocolVersion) or 0,
        sequence = incomingSequence,
        receivedAt = now,
        expiresAt = now + ttl,
        addons = NormalizeRemoteAddons(data.addons),
    }

    EZOCore:FireCallback("EZO_CORE_GROUP_PRESENCE_UPDATED", CopyPeer(peersByUnitTag[unitTag]))
    EZOCore:FireCallback("EZOCore:GroupPresenceUpdated", CopyPeer(peersByUnitTag[unitTag]))
    return true
end

local function RegisterLibGroupBroadcast()
    local lgb = GetLibGroupBroadcast()
    if not lgb then
        RefreshStatus()
        return false
    end

    if not status.configured then
        RefreshStatus()
        return false
    end

    local ok = pcall(function()
        handler = lgb:RegisterHandler("EZOCore", LGB_HANDLER_NAME)
        handler:SetDisplayName("EZOCore")
        handler:SetDescription("EZO family presence")
        protocol = handler:DeclareProtocol(LGB_PROTOCOL_ID, LGB_PROTOCOL_NAME)
        protocol:OnData(HandleRemotePresence)
        protocol:Finalize({ replaceQueuedMessages = true, isRelevantInCombat = false })
        firePresenceRequest = handler:DeclareCustomEvent(LGB_REQUEST_EVENT_ID, LGB_REQUEST_EVENT_NAME, {
            displayName = "EZOCore presence request",
            description = "Requests EZO family presence from group members.",
            isRelevantInCombat = false,
        })
        lgb:RegisterForCustomEvent(LGB_REQUEST_EVENT_NAME, function()
            GROUP_PRESENCE.AnnounceLocalPresence()
        end)
    end)

    if not ok then
        handler = nil
        protocol = nil
        firePresenceRequest = nil
    end

    RefreshStatus()
    return status.active == true
end

function GROUP_PRESENCE.Initialize()
    if initialized then
        return status.active == true
    end

    initialized = true
    RefreshStatus()
    RegisterLibGroupBroadcast()
    return status.active == true
end

function GROUP_PRESENCE.GetStatus()
    RefreshStatus()
    return {
        available = status.available,
        configured = status.configured,
        active = status.active,
        reason = status.reason,
        protocolVersion = PRESENCE_PROTOCOL_VERSION,
        ttlSeconds = PEER_TTL_SECONDS,
    }
end

function GROUP_PRESENCE.PrunePeers()
    local now = NowSeconds()
    for unitTag, peer in pairs(peersByUnitTag) do
        if IsPeerExpired(peer, now) then
            peersByUnitTag[unitTag] = nil
        end
    end
end

function GROUP_PRESENCE.GetRemotePeers()
    GROUP_PRESENCE.PrunePeers()
    local out = {}
    for _, peer in pairs(peersByUnitTag) do
        out[#out + 1] = CopyPeer(peer)
    end
    table.sort(out, function(left, right)
        return tostring(left.unitTag or "") < tostring(right.unitTag or "")
    end)
    return out
end

function GROUP_PRESENCE.GetRemotePeer(_, unitTag)
    GROUP_PRESENCE.PrunePeers()
    return CopyPeer(peersByUnitTag[unitTag])
end

function GROUP_PRESENCE.GetPeerAddon(_, unitTag, addonId)
    local peer = GROUP_PRESENCE.GetRemotePeer(nil, unitTag)
    if not peer or type(addonId) ~= "string" then
        return nil
    end
    return peer.addons[string.lower(addonId)]
end

function GROUP_PRESENCE.HasPeerCapability(_, unitTag, addonId, capability, minimumApiVersion)
    local peer = peersByUnitTag[unitTag]
    if not peer or IsPeerExpired(peer, NowSeconds()) or type(addonId) ~= "string" then
        return false
    end

    local addon = peer.addons[string.lower(addonId)]
    if not addon then
        return false
    end
    if type(minimumApiVersion) == "number" and (tonumber(addon.apiVersion) or 0) < minimumApiVersion then
        return false
    end
    return addon.capabilitySet and addon.capabilitySet[capability] == true
end

function GROUP_PRESENCE.GetPeerCompatibility(_, unitTag, addonId, capability, minimumApiVersion)
    local peer = peersByUnitTag[unitTag]
    if not peer or IsPeerExpired(peer, NowSeconds()) then
        return "unknown"
    end

    local addon = type(addonId) == "string" and peer.addons[string.lower(addonId)] or nil
    if not addon then
        return "incompatible"
    end
    if capability and not (addon.capabilitySet and addon.capabilitySet[capability] == true) then
        return "incompatible"
    end
    if type(minimumApiVersion) == "number" and (tonumber(addon.apiVersion) or 0) < minimumApiVersion then
        return "incompatible"
    end
    return "compatible"
end

function GROUP_PRESENCE.AnnounceLocalPresence()
    GROUP_PRESENCE.Initialize()
    if not protocol or not protocol.IsEnabled or not protocol:IsEnabled() then
        return false, status.reason
    end
    return protocol:Send(GetLocalPresencePayload(), { replaceQueuedMessages = true, isRelevantInCombat = false })
end

function GROUP_PRESENCE.RequestPresence()
    GROUP_PRESENCE.Initialize()
    if not firePresenceRequest then
        return false, status.reason
    end
    firePresenceRequest()
    return true
end

function GROUP_PRESENCE._HandleRemotePresence(unitTag, data)
    return HandleRemotePresence(unitTag, data)
end

EZOCore:RegisterService(SERVICE_NAME, SERVICE_API_VERSION, GROUP_PRESENCE)
