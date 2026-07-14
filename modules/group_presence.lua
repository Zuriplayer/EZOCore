local EZOCore = EZOCore

-- Remote/group state for future LibGroupBroadcast transport.
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
local LGB_PROTOCOL_NAME = "EZO_CORE_GROUP_V1"
local LGB_REQUEST_EVENT_ID = nil
local LGB_REQUEST_EVENT_NAME = "EZO_CORE_GROUP_REQUEST_V1"

local WIRE_MESSAGE_TYPES = {
    presence = 1,
    activityState = 2,
}

local WIRE_ACTIVITY_TYPES = {
    unknown = 0,
    trial = 1,
    dungeon = 2,
    arena = 3,
}

local WIRE_ACTIVITY_STAGES = {
    idle = 0,
    staging = 1,
    returning = 2,
    waitingMembers = 3,
    complete = 4,
    failed = 5,
}

local CAPABILITY_BITS = {
    ["family.presence"] = 1,
    ["family.groupPresence"] = 2,
    ["family.language"] = 3,
    ["family.language.consumer"] = 4,
    ["family.settings.consumer"] = 5,
    ["family.debug"] = 6,
    ["family.layout"] = 7,
    ["group.activities"] = 8,
    ["group.activityState.provider"] = 9,
    ["group.activityState.consumer"] = 10,
    ["group.frames.visualHints"] = 11,
    ["alerts.screen"] = 12,
    ["alerts.groupChat"] = 13,
    ["automation.groupInvites"] = 14,
    ["combat.metrics"] = 15,
    ["hud.visualOverlay"] = 16,
    ["pvp.travel"] = 17,
}

local CAPABILITY_BY_BIT = {}
for capability, bit in pairs(CAPABILITY_BITS) do
    CAPABILITY_BY_BIT[bit] = capability
end

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
        capabilityMask = tonumber(addon.capabilityMask) or 0,
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

local function DecodeCapabilityMask(mask)
    local capabilities = {}
    mask = tonumber(mask) or 0
    for bit = 1, 32 do
        local capability = CAPABILITY_BY_BIT[bit]
        local bitValue = 2 ^ (bit - 1)
        if capability and math.floor(mask / bitValue) % 2 == 1 then
            capabilities[#capabilities + 1] = capability
        end
    end
    return capabilities
end

local function BuildCapabilityMask(capabilities)
    local mask = 0
    if type(capabilities) ~= "table" then
        return mask
    end

    for index = 1, #capabilities do
        local bit = CAPABILITY_BITS[capabilities[index]]
        if bit then
            local bitValue = 2 ^ (bit - 1)
            if math.floor(mask / bitValue) % 2 == 0 then
                mask = mask + bitValue
            end
        end
    end
    return mask
end

local function NormalizeRemoteAddons(addons)
    local out = {}
    if type(addons) ~= "table" then
        return out
    end

    for index = 1, #addons do
        local addon = CopyAddon(addons[index])
        if addon and type(addon.id) == "string" and addon.id ~= "" then
            if type(addon.capabilities) ~= "table" and tonumber(addon.capabilityMask) then
                addon.capabilities = DecodeCapabilityMask(addon.capabilityMask)
            end
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

local function GetProtocolFieldClasses(lgb)
    local class = lgb and lgb.internal and lgb.internal.class
    if type(class) ~= "table" then
        return nil
    end

    local required = {
        "ArrayField",
        "NumericField",
        "StringField",
        "TableField",
        "VariantField",
    }
    for index = 1, #required do
        if type(class[required[index]]) ~= "table" then
            return nil
        end
    end
    return class
end

local function AddGroupProtocolFields(targetProtocol, lgb)
    local class = GetProtocolFieldClasses(lgb)
    if not class then
        return false
    end

    local addonRecord = class.TableField:New("addons", {
        class.StringField:New("id", { minLength = 3, maxLength = 32 }),
        class.StringField:New("version", { minLength = 1, maxLength = 16 }),
        class.NumericField:New("addOnVersion", { minValue = 0, maxValue = 999999 }),
        class.NumericField:New("apiVersion", { minValue = 0, maxValue = 255 }),
        class.NumericField:New("capabilityMask", { numBits = 32 }),
    })

    targetProtocol:AddField(class.VariantField:New({
        class.TableField:New("presence", {
            class.NumericField:New("protocolVersion", { minValue = 1, maxValue = 15 }),
            class.NumericField:New("sequence", { minValue = 0, maxValue = 65535 }),
            class.NumericField:New("coreApiVersion", { minValue = 0, maxValue = 255 }),
            class.StringField:New("coreVersion", { minLength = 1, maxLength = 16 }),
            class.NumericField:New("coreAddOnVersion", { minValue = 0, maxValue = 999999 }),
            class.NumericField:New("ttlSeconds", { minValue = 15, maxValue = 300 }),
            class.ArrayField:New(addonRecord, { minLength = 0, maxLength = 16 }),
        }),
        class.TableField:New("activityState", {
            class.NumericField:New("protocolVersion", { minValue = 1, maxValue = 15 }),
            class.NumericField:New("sequence", { minValue = 0, maxValue = 65535 }),
            class.NumericField:New("sourceAddonKey", { minValue = 0, maxValue = 255 }),
            class.NumericField:New("activityType", { minValue = 0, maxValue = 15 }),
            class.NumericField:New("stage", { minValue = 0, maxValue = 31 }),
            class.NumericField:New("result", { minValue = 0, maxValue = 31 }),
            class.NumericField:New("sessionId", { minValue = 0, maxValue = 4294967295 }),
            class.NumericField:New("ttlSeconds", { minValue = 15, maxValue = 300 }),
            class.StringField:New("targetKey", { minLength = 0, maxLength = 32 }),
        }),
    }, { maxNumVariants = 8 }))
    return true
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
    local wireAddons = {}
    for index = 1, #addons do
        local addon = addons[index]
        wireAddons[#wireAddons + 1] = {
            id = tostring(addon.id or ""),
            version = tostring(addon.version or ""),
            addOnVersion = tonumber(addon.addOnVersion) or 0,
            apiVersion = tonumber(addon.apiVersion) or 0,
            capabilityMask = BuildCapabilityMask(addon.capabilities),
        }
    end

    return { presence = {
        coreApiVersion = EZOCore.apiVersion,
        coreVersion = EZOCore.version,
        coreAddOnVersion = EZOCore.addOnVersion,
        protocolVersion = PRESENCE_PROTOCOL_VERSION,
        sequence = sequence,
        ttlSeconds = PEER_TTL_SECONDS,
        addons = wireAddons,
    } }
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

local function HandleRemoteGroupMessage(unitTag, data)
    if type(data) ~= "table" then
        return false
    end
    if type(data.presence) == "table" then
        return HandleRemotePresence(unitTag, data.presence)
    end
    if type(data.activityState) == "table" then
        EZOCore:FireCallback("EZO_CORE_GROUP_ACTIVITY_STATE_UPDATED", unitTag, data.activityState)
        EZOCore:FireCallback("EZOCore:GroupActivityStateUpdated", unitTag, data.activityState)
        return true
    end
    return false
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
        handler:SetDescription("EZO family group presence and informational state")
        protocol = handler:DeclareProtocol(LGB_PROTOCOL_ID, LGB_PROTOCOL_NAME)
        if not AddGroupProtocolFields(protocol, lgb) then
            error("LibGroupBroadcast field classes unavailable")
        end
        protocol:OnData(HandleRemoteGroupMessage)
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
        protocolName = LGB_PROTOCOL_NAME,
        requestEventName = LGB_REQUEST_EVENT_NAME,
    }
end

function GROUP_PRESENCE.GetProtocolSpec()
    return {
        serviceName = SERVICE_NAME,
        serviceApiVersion = SERVICE_API_VERSION,
        protocolVersion = PRESENCE_PROTOCOL_VERSION,
        protocolName = LGB_PROTOCOL_NAME,
        requestEventName = LGB_REQUEST_EVENT_NAME,
        protocolReady = LGB_PROTOCOL_READY,
        protocolId = LGB_PROTOCOL_ID,
        requestEventId = LGB_REQUEST_EVENT_ID,
        ttlSeconds = PEER_TTL_SECONDS,
        messageTypes = {
            presence = WIRE_MESSAGE_TYPES.presence,
            activityState = WIRE_MESSAGE_TYPES.activityState,
        },
        activityTypes = WIRE_ACTIVITY_TYPES,
        activityStages = WIRE_ACTIVITY_STAGES,
        capabilityBits = CAPABILITY_BITS,
    }
end

function GROUP_PRESENCE.GetReservationDraft()
    return {
        addon = "EZOCore",
        author = "@Zuriplayer",
        protocolName = LGB_PROTOCOL_NAME,
        protocolId = "TBD",
        protocolDescription = "EZO family group presence and small informational activity state messages.",
        customEventName = LGB_REQUEST_EVENT_NAME,
        customEventId = "TBD",
        customEventDescription = "Requests an EZO group presence/state resync from compatible group members.",
        status = "pending official LibGroupBroadcast ID reservation",
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

function GROUP_PRESENCE._HandleRemoteGroupMessage(unitTag, data)
    return HandleRemoteGroupMessage(unitTag, data)
end

EZOCore:RegisterService(SERVICE_NAME, SERVICE_API_VERSION, GROUP_PRESENCE)
