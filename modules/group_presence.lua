local EZOCore = EZOCore

-- Remote group presence over the single LibGroupBroadcast protocol owned by EZOCore.

local GROUP_PRESENCE = {}
EZOCore.GroupPresence = GROUP_PRESENCE

local SERVICE_NAME = "family.groupPresence"
local SERVICE_API_VERSION = 1

local PRESENCE_PROTOCOL_VERSION = 2
local PEER_TTL_SECONDS = 90
local PRESENCE_HEARTBEAT_MS = 45000
local MAX_WIRE_ADDONS = 16
local SEQUENCE_MODULUS = 65536
local SEQUENCE_HALF_RANGE = SEQUENCE_MODULUS / 2
local SESSION_ID_MODULUS = 16777216

local LGB_PROTOCOL_READY = true
local LGB_PROTOCOL_ID = 511
local LGB_PROTOCOL_ID_MAX = 511
local LGB_PROTOCOL_IS_TEST_ID = true
local LGB_PROTOCOL_NAME = "EZO_CORE_GROUP_V2"
local LGB_REQUEST_EVENT_ID = 39
local LGB_REQUEST_EVENT_ID_MAX = 39
local LGB_REQUEST_EVENT_IS_TEST_ID = true
local LGB_REQUEST_EVENT_NAME = "EZO_CORE_GROUP_REQUEST_V1"

local WIRE_MESSAGE_TYPES = {
    presence = 1,
    activityState = 2,
    performanceState = 3,
    alertEvent = 4,
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

local WIRE_ACTIVITY_RESULTS = {
    unknown = 0,
    active = 1,
    complete = 2,
    cancelled = 3,
    failed = 4,
    interrupted = 5,
}

local WIRE_ACTIVITY_DIFFICULTIES = {
    unknown = 0,
    normal = 1,
    veteran = 2,
}

local WIRE_PRIVACY_STATES = {
    unknown = 0,
    public = 1,
    private = 2,
    hidden = 3,
}

local WIRE_ALERT_EVENT_TYPES = {
    unknown = 0,
    chest = 1,
    heavySack = 2,
}

local WIRE_ALERT_QUALITIES = {
    unknown = 0,
    simple = 1,
    intermediate = 2,
    advanced = 3,
    master = 4,
    impossible = 5,
}

-- Stable wire keys keep presence messages compact. Never reuse a retired key.
local ADDON_KEYS = {
    ezocore = 1,
    ezoalerts = 2,
    ezoauto = 3,
    ezocamsens = 4,
    ezochat = 5,
    ezocombat = 6,
    ezocursor = 7,
    ezocustomsupporticons = 8,
    ezogroupframes = 9,
    ezohud = 10,
    ezokeybinds = 11,
    ezometter = 12,
    ezopvp = 13,
    ezota = 14,
    ezotools = 15,
}

local ADDON_ID_BY_KEY = {}
for addonId, addonKey in pairs(ADDON_KEYS) do
    ADDON_ID_BY_KEY[addonKey] = addonId
end

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
    ["group.performanceState.provider"] = 18,
    ["group.performanceState.consumer"] = 19,
    ["alerts.groupEvent.provider"] = 20,
    ["alerts.groupEvent.consumer"] = 21,
}

local CAPABILITY_BY_BIT = {}
for capability, bit in pairs(CAPABILITY_BITS) do
    CAPABILITY_BY_BIT[bit] = capability
end

local peersByUnitTag = {}
local activitySequenceByUnitTag = {}
local activityStateByUnitTag = {}
local performanceSequenceByUnitTag = {}
local performanceStateByUnitTag = {}
local pendingPerformanceByUnitTag = {}
local alertSequenceByUnitTag = {}
local performancePublishedAtBySourceKey = {}
local performanceNonPublicPublishedAtBySourceKey = {}
local performancePrivacyStateBySourceKey = {}
local sequence = 0
local presenceSessionId = math.random(0, SESSION_ID_MODULUS - 1)
if type(_G.GetFrameTimeMilliseconds) == "function" then
    presenceSessionId = (presenceSessionId + _G.GetFrameTimeMilliseconds()) % SESSION_ID_MODULUS
end
local announceGeneration = 0
local initialized = false
local HEARTBEAT_UPDATE_NAME = "EZOCore_GroupPresenceHeartbeat"
local handler
local protocol
local firePresenceRequest
local HandleRemotePerformanceState
local status = {
    available = false,
    configured = false,
    active = false,
    reason = "notInitialized",
    detail = nil,
}

local function NowSeconds()
    if type(_G.GetFrameTimeSeconds) == "function" then
        return _G.GetFrameTimeSeconds()
    end
    return 0
end

local function IsIntegerInRange(value, minimum, maximum)
    return type(value) == "number"
        and value == math.floor(value)
        and value >= minimum
        and value <= maximum
end

local function IsCurrentGroupUnit(unitTag)
    if type(unitTag) ~= "string" or not string.match(unitTag, "^group%d+$") then
        return false
    end
    if type(_G.IsUnitGrouped) == "function" and not _G.IsUnitGrouped(unitTag) then
        return false
    end
    if type(_G.DoesUnitExist) == "function" and not _G.DoesUnitExist(unitTag) then
        return false
    end
    return true
end

local function IsLocalPlayerGrouped()
    return type(_G.IsUnitGrouped) == "function" and _G.IsUnitGrouped("player") == true
end

local function SchedulePresenceAnnouncement(minimumDelayMs, maximumDelayMs)
    if not status.active or not IsLocalPlayerGrouped() or type(_G.zo_callLater) ~= "function" then
        return false
    end

    local minimum = math.max(0, math.floor(tonumber(minimumDelayMs) or 250))
    local maximum = math.max(minimum, math.floor(tonumber(maximumDelayMs) or minimum))
    local delay = minimum
    if maximum > minimum then
        delay = minimum + math.random(0, maximum - minimum)
    end

    announceGeneration = announceGeneration + 1
    local scheduledGeneration = announceGeneration
    _G.zo_callLater(function()
        if scheduledGeneration == announceGeneration then
            GROUP_PRESENCE.AnnounceLocalPresence()
        end
    end, delay)
    return true
end

local function IsNewerSequence(incoming, previous)
    if not IsIntegerInRange(incoming, 1, SEQUENCE_MODULUS - 1) then
        return false
    end
    if not IsIntegerInRange(previous, 1, SEQUENCE_MODULUS - 1) then
        return true
    end

    local distance = (incoming - previous) % SEQUENCE_MODULUS
    return distance > 0 and distance < SEQUENCE_HALF_RANGE
end

local function IsKnownEnumValue(enumValues, value)
    for _, knownValue in pairs(enumValues) do
        if value == knownValue then
            return true
        end
    end
    return false
end

local function NormalizeEnumValue(enumValues, value)
    if type(value) == "string" then
        return enumValues[value]
    end
    if IsKnownEnumValue(enumValues, value) then
        return value
    end
    return nil
end

local function GetEnumName(enumValues, value)
    for name, enumValue in pairs(enumValues) do
        if enumValue == value then
            return name
        end
    end
    return nil
end

local function NextSequence()
    sequence = (sequence % (SEQUENCE_MODULUS - 1)) + 1
    return sequence
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
        protocolVersion = peer.protocolVersion,
        sessionId = peer.sessionId,
        sequence = peer.sequence,
        receivedAt = peer.receivedAt,
        expiresAt = peer.expiresAt,
        addons = addons,
        activityState = nil,
        performanceState = nil,
    }
end

local function CopyActivityState(state)
    if type(state) ~= "table" then
        return nil
    end
    return {
        unitTag = state.unitTag,
        protocolVersion = state.protocolVersion,
        sequence = state.sequence,
        sourceAddonKey = state.sourceAddonKey,
        sourceAddonId = state.sourceAddonId,
        activityType = state.activityType,
        activityTypeCode = state.activityTypeCode,
        stage = state.stage,
        stageCode = state.stageCode,
        result = state.result,
        resultCode = state.resultCode,
        difficulty = state.difficulty,
        difficultyCode = state.difficultyCode,
        sessionId = state.sessionId,
        progressCurrent = state.progressCurrent,
        progressTotal = state.progressTotal,
        pendingCount = state.pendingCount,
        expectedCount = state.expectedCount,
        ttlSeconds = state.ttlSeconds,
        targetKey = state.targetKey,
        receivedAt = state.receivedAt,
        expiresAt = state.expiresAt,
    }
end

local function CopyPerformanceState(state)
    if type(state) ~= "table" then
        return nil
    end
    return {
        unitTag = state.unitTag,
        protocolVersion = state.protocolVersion,
        sequence = state.sequence,
        sourceAddonKey = state.sourceAddonKey,
        sourceAddonId = state.sourceAddonId,
        pingMs = state.pingMs,
        fps = state.fps,
        privacyState = state.privacyState,
        ttlSeconds = state.ttlSeconds,
        receivedAt = state.receivedAt,
        expiresAt = state.expiresAt,
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
    if type(addons) ~= "table" or #addons > MAX_WIRE_ADDONS then
        return nil
    end

    for index = 1, #addons do
        local wireAddon = addons[index]
        if type(wireAddon) ~= "table"
            or not IsIntegerInRange(wireAddon.addonKey, 1, 63)
            or not IsIntegerInRange(wireAddon.addOnVersion, 0, 1048575)
            or not IsIntegerInRange(wireAddon.apiVersion, 0, 255)
            or not IsIntegerInRange(wireAddon.capabilityMask, 0, 4294967295) then
            return nil
        end

        local addonId = ADDON_ID_BY_KEY[wireAddon.addonKey]
        if addonId then
            if out[addonId] then
                return nil
            end
            local capabilities = DecodeCapabilityMask(wireAddon.capabilityMask)
            out[addonId] = {
                id = addonId,
                addOnVersion = wireAddon.addOnVersion,
                apiVersion = wireAddon.apiVersion,
                capabilities = capabilities,
                capabilitySet = BuildCapabilitySet(capabilities),
                capabilityMask = wireAddon.capabilityMask,
            }
        end
    end
    return out
end

local function ResolveAddonKey(addonIdOrKey)
    if IsIntegerInRange(addonIdOrKey, 1, 63) and ADDON_ID_BY_KEY[addonIdOrKey] then
        return addonIdOrKey
    end
    if type(addonIdOrKey) == "string" then
        return ADDON_KEYS[string.lower(addonIdOrKey)]
    end
    return nil
end

local function NormalizeTtlSeconds(value, defaultValue)
    local ttl = tonumber(value) or defaultValue or 30
    ttl = math.floor(ttl)
    if ttl < 15 then
        ttl = 15
    elseif ttl > 300 then
        ttl = 300
    end
    return ttl
end

local function IsPeerExpired(peer, now)
    return type(peer) ~= "table" or (tonumber(peer.expiresAt) or 0) <= now
end

local function IsStateExpired(state, now)
    return type(state) ~= "table" or (tonumber(state.expiresAt) or 0) <= now
end

local function ClearPeerTransientState(unitTag)
    activitySequenceByUnitTag[unitTag] = nil
    activityStateByUnitTag[unitTag] = nil
    performanceSequenceByUnitTag[unitTag] = nil
    performanceStateByUnitTag[unitTag] = nil
    pendingPerformanceByUnitTag[unitTag] = nil
    alertSequenceByUnitTag[unitTag] = nil
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

local function HasProtocolFieldFactories(lgb)
    local required = {
        "CreateArrayField",
        "CreateNumericField",
        "CreateStringField",
        "CreateTableField",
        "CreateVariantField",
    }
    for index = 1, #required do
        if type(lgb and lgb[required[index]]) ~= "function" then
            return false
        end
    end
    return true
end

local function AddGroupProtocolFields(targetProtocol, lgb)
    if not HasProtocolFieldFactories(lgb) then
        return false
    end

    local addonRecord = lgb.CreateTableField("addons", {
        lgb.CreateNumericField("addonKey", { minValue = 1, maxValue = 63 }),
        lgb.CreateNumericField("addOnVersion", { minValue = 0, maxValue = 1048575 }),
        lgb.CreateNumericField("apiVersion", { minValue = 0, maxValue = 255 }),
        lgb.CreateNumericField("capabilityMask", {
            numBits = 32,
            minValue = 0,
            maxValue = 4294967295,
        }),
    })

    targetProtocol:AddField(lgb.CreateVariantField({
        lgb.CreateTableField("presence", {
            lgb.CreateNumericField("protocolVersion", { minValue = 1, maxValue = 15 }),
            lgb.CreateNumericField("sessionId", { minValue = 0, maxValue = SESSION_ID_MODULUS - 1 }),
            lgb.CreateNumericField("sequence", { minValue = 1, maxValue = 65535 }),
            lgb.CreateNumericField("ttlSeconds", { minValue = 15, maxValue = 300 }),
            lgb.CreateArrayField(addonRecord, { minLength = 0, maxLength = MAX_WIRE_ADDONS }),
        }),
        lgb.CreateTableField("activityState", {
            lgb.CreateNumericField("protocolVersion", { minValue = 1, maxValue = 15 }),
            lgb.CreateNumericField("sequence", { minValue = 1, maxValue = 65535 }),
            lgb.CreateNumericField("sourceAddonKey", { minValue = 1, maxValue = 63 }),
            lgb.CreateNumericField("activityType", { minValue = 0, maxValue = 15 }),
            lgb.CreateNumericField("stage", { minValue = 0, maxValue = 31 }),
            lgb.CreateNumericField("result", { minValue = 0, maxValue = 31 }),
            lgb.CreateNumericField("difficulty", { minValue = 0, maxValue = 3 }),
            lgb.CreateNumericField("sessionId", { minValue = 0, maxValue = 4294967295 }),
            lgb.CreateNumericField("progressCurrent", { minValue = 0, maxValue = 15 }),
            lgb.CreateNumericField("progressTotal", { minValue = 0, maxValue = 15 }),
            lgb.CreateNumericField("pendingCount", { minValue = 0, maxValue = 12 }),
            lgb.CreateNumericField("expectedCount", { minValue = 0, maxValue = 12 }),
            lgb.CreateNumericField("ttlSeconds", { minValue = 15, maxValue = 300 }),
            lgb.CreateStringField("targetKey", { minLength = 0, maxLength = 32 }),
        }),
        lgb.CreateTableField("performanceState", {
            lgb.CreateNumericField("protocolVersion", { minValue = 1, maxValue = 15 }),
            lgb.CreateNumericField("sequence", { minValue = 1, maxValue = 65535 }),
            lgb.CreateNumericField("sourceAddonKey", { minValue = 1, maxValue = 63 }),
            lgb.CreateNumericField("pingMs", { minValue = 0, maxValue = 4095 }),
            lgb.CreateNumericField("fps", { minValue = 0, maxValue = 255 }),
            lgb.CreateNumericField("privacyState", { minValue = 0, maxValue = 7 }),
            lgb.CreateNumericField("ttlSeconds", { minValue = 15, maxValue = 300 }),
        }),
        lgb.CreateTableField("alertEvent", {
            lgb.CreateNumericField("protocolVersion", { minValue = 1, maxValue = 15 }),
            lgb.CreateNumericField("sequence", { minValue = 1, maxValue = 65535 }),
            lgb.CreateNumericField("sourceAddonKey", { minValue = 1, maxValue = 63 }),
            lgb.CreateNumericField("eventType", { minValue = 0, maxValue = 15 }),
            lgb.CreateNumericField("quality", { minValue = 0, maxValue = 15 }),
            lgb.CreateNumericField("ttlSeconds", { minValue = 15, maxValue = 60 }),
            lgb.CreateStringField("actorName", { minLength = 0, maxLength = 40 }),
        }),
    }, { maxNumVariants = 8 }))
    return true
end

local function RefreshStatus()
    local lgb = GetLibGroupBroadcast()
    status.available = lgb ~= nil
    status.configured = LGB_PROTOCOL_READY == true
        and type(LGB_PROTOCOL_ID) == "number"
        and LGB_PROTOCOL_ID >= 0
        and LGB_PROTOCOL_ID <= LGB_PROTOCOL_ID_MAX
        and type(LGB_REQUEST_EVENT_ID) == "number"
        and LGB_REQUEST_EVENT_ID >= 0
        and LGB_REQUEST_EVENT_ID <= LGB_REQUEST_EVENT_ID_MAX
    local protocolEnabled = false
    if protocol and type(protocol.IsEnabled) == "function" then
        local ok, enabled = pcall(protocol.IsEnabled, protocol)
        protocolEnabled = ok and enabled == true
    end
    status.enabled = protocolEnabled
    status.active = status.available and status.configured and protocolEnabled

    if not status.available then
        status.reason = "libGroupBroadcastMissing"
    elseif LGB_PROTOCOL_READY ~= true then
        status.reason = "protocolDefinitionPending"
    elseif not status.configured then
        status.reason = "reservedIdsMissing"
    elseif not protocol then
        status.reason = "transportNotInitialized"
    elseif not protocolEnabled then
        status.reason = "protocolDisabled"
    else
        status.reason = "active"
    end
end

local function GetLocalPresencePayload()
    local presence = EZOCore.Presence
    local addons = presence and presence.GetLocalAddons and presence.GetLocalAddons() or {}
    local wireAddons = {}
    for index = 1, #addons do
        local addon = addons[index]
        local addonKey = ADDON_KEYS[string.lower(tostring(addon.id or ""))]
        if addonKey and #wireAddons < MAX_WIRE_ADDONS then
            wireAddons[#wireAddons + 1] = {
                addonKey = addonKey,
                addOnVersion = math.floor(math.max(0,
                    math.min(tonumber(addon.addOnVersion) or 0, 1048575))),
                apiVersion = math.floor(math.max(0,
                    math.min(tonumber(addon.apiVersion) or 0, 255))),
                capabilityMask = BuildCapabilityMask(addon.capabilities),
            }
        end
    end

    return { presence = {
        protocolVersion = PRESENCE_PROTOCOL_VERSION,
        sessionId = presenceSessionId,
        sequence = NextSequence(),
        ttlSeconds = PEER_TTL_SECONDS,
        addons = wireAddons,
    } }
end

local function HandleRemotePresence(unitTag, data)
    if not IsCurrentGroupUnit(unitTag) or type(data) ~= "table" then
        return false
    end
    if data.protocolVersion ~= PRESENCE_PROTOCOL_VERSION
        or not IsIntegerInRange(data.sessionId, 0, SESSION_ID_MODULUS - 1)
        or not IsIntegerInRange(data.ttlSeconds, 15, 300) then
        return false
    end

    local now = NowSeconds()
    local previous = peersByUnitTag[unitTag]
    local pendingPerformance = pendingPerformanceByUnitTag[unitTag]
    local incomingSequence = data.sequence
    local previousSequence = previous and previous.sessionId == data.sessionId and previous.sequence or nil
    if not IsNewerSequence(incomingSequence, previousSequence) then
        return false
    end

    local addons = NormalizeRemoteAddons(data.addons)
    if not addons then
        return false
    end

    if previous and previous.sessionId ~= data.sessionId then
        ClearPeerTransientState(unitTag)
    end

    local ttl = data.ttlSeconds
    peersByUnitTag[unitTag] = {
        unitTag = unitTag,
        displayName = ResolveDisplayName(unitTag),
        protocolVersion = data.protocolVersion,
        sessionId = data.sessionId,
        sequence = incomingSequence,
        receivedAt = now,
        expiresAt = now + ttl,
        addons = addons,
    }

    EZOCore:FireCallback("EZO_CORE_GROUP_PRESENCE_UPDATED", CopyPeer(peersByUnitTag[unitTag]))
    EZOCore:FireCallback("EZOCore:GroupPresenceUpdated", CopyPeer(peersByUnitTag[unitTag]))

    pendingPerformanceByUnitTag[unitTag] = nil
    if pendingPerformance and not IsStateExpired(pendingPerformance, now) then
        HandleRemotePerformanceState(unitTag, pendingPerformance.data, false)
    end
    return true
end

local function HandleRemoteActivityState(unitTag, data)
    if not IsCurrentGroupUnit(unitTag) or type(data) ~= "table" then
        return false
    end
    if type(_G.IsUnitGroupLeader) ~= "function" or not _G.IsUnitGroupLeader(unitTag) then
        return false
    end
    local now = NowSeconds()
    local previousActivity = activitySequenceByUnitTag[unitTag]
    if previousActivity and IsStateExpired(previousActivity, now) then
        activitySequenceByUnitTag[unitTag] = nil
        activityStateByUnitTag[unitTag] = nil
        previousActivity = nil
    end
    local previousActivitySequence = previousActivity
        and previousActivity.sessionId == data.sessionId
        and previousActivity.sequence
        or nil
    if data.protocolVersion ~= PRESENCE_PROTOCOL_VERSION
        or not IsNewerSequence(data.sequence, previousActivitySequence)
        or not IsIntegerInRange(data.ttlSeconds, 15, 300)
        or not IsKnownEnumValue(WIRE_ACTIVITY_TYPES, data.activityType)
        or not IsKnownEnumValue(WIRE_ACTIVITY_STAGES, data.stage)
        or not IsKnownEnumValue(WIRE_ACTIVITY_RESULTS, data.result)
        or not IsKnownEnumValue(WIRE_ACTIVITY_DIFFICULTIES, data.difficulty)
        or not IsIntegerInRange(data.sessionId, 0, 4294967295)
        or not IsIntegerInRange(data.progressCurrent, 0, 15)
        or not IsIntegerInRange(data.progressTotal, 0, 15)
        or data.progressCurrent > data.progressTotal
        or not IsIntegerInRange(data.pendingCount, 0, 12)
        or not IsIntegerInRange(data.expectedCount, 0, 12)
        or data.pendingCount > data.expectedCount
        or type(data.targetKey) ~= "string"
        or #data.targetKey > 32 then
        return false
    end

    local peer = peersByUnitTag[unitTag]
    local sourceAddonId = ADDON_ID_BY_KEY[data.sourceAddonKey]
    local sourceAddon = peer and sourceAddonId and peer.addons[sourceAddonId]
    if IsPeerExpired(peer, NowSeconds())
        or not sourceAddon
        or not sourceAddon.capabilitySet
        or sourceAddon.capabilitySet["group.activityState.provider"] ~= true then
        return false
    end

    activitySequenceByUnitTag[unitTag] = {
        sessionId = data.sessionId,
        sequence = data.sequence,
        expiresAt = now + data.ttlSeconds,
    }
    activityStateByUnitTag[unitTag] = {
        unitTag = unitTag,
        protocolVersion = data.protocolVersion,
        sequence = data.sequence,
        sourceAddonKey = data.sourceAddonKey,
        sourceAddonId = sourceAddonId,
        activityType = GetEnumName(WIRE_ACTIVITY_TYPES, data.activityType),
        activityTypeCode = data.activityType,
        stage = GetEnumName(WIRE_ACTIVITY_STAGES, data.stage),
        stageCode = data.stage,
        result = GetEnumName(WIRE_ACTIVITY_RESULTS, data.result),
        resultCode = data.result,
        difficulty = GetEnumName(WIRE_ACTIVITY_DIFFICULTIES, data.difficulty),
        difficultyCode = data.difficulty,
        sessionId = data.sessionId,
        progressCurrent = data.progressCurrent,
        progressTotal = data.progressTotal,
        pendingCount = data.pendingCount,
        expectedCount = data.expectedCount,
        ttlSeconds = data.ttlSeconds,
        targetKey = data.targetKey,
        receivedAt = now,
        expiresAt = now + data.ttlSeconds,
    }
    EZOCore:FireCallback(
        "EZO_CORE_GROUP_ACTIVITY_STATE_UPDATED",
        unitTag,
        CopyActivityState(activityStateByUnitTag[unitTag]))
    EZOCore:FireCallback(
        "EZOCore:GroupActivityStateUpdated",
        unitTag,
        CopyActivityState(activityStateByUnitTag[unitTag]))
    return true
end

local function HandleRemoteAlertEvent(unitTag, data)
    if not IsCurrentGroupUnit(unitTag) or type(data) ~= "table" then
        return false
    end

    local now = NowSeconds()
    local previousAlert = alertSequenceByUnitTag[unitTag]
    if previousAlert and IsStateExpired(previousAlert, now) then
        alertSequenceByUnitTag[unitTag] = nil
        previousAlert = nil
    end

    if data.protocolVersion ~= PRESENCE_PROTOCOL_VERSION
        or not IsNewerSequence(data.sequence, previousAlert and previousAlert.sequence)
        or not IsIntegerInRange(data.ttlSeconds, 15, 60)
        or not IsKnownEnumValue(WIRE_ALERT_EVENT_TYPES, data.eventType)
        or not IsKnownEnumValue(WIRE_ALERT_QUALITIES, data.quality)
        or not ResolveAddonKey(data.sourceAddonKey)
        or type(data.actorName) ~= "string"
        or #data.actorName > 40 then
        return false
    end

    local sourceAddonId = ADDON_ID_BY_KEY[data.sourceAddonKey]
    local peer = peersByUnitTag[unitTag]
    local sourceAddon = peer and sourceAddonId and peer.addons[sourceAddonId]
    if peer and not IsPeerExpired(peer, now) then
        if not sourceAddon
            or not sourceAddon.capabilitySet
            or sourceAddon.capabilitySet["alerts.groupEvent.provider"] ~= true then
            return false
        end
    end

    local event = {
        unitTag = unitTag,
        protocolVersion = data.protocolVersion,
        sequence = data.sequence,
        sourceAddonKey = data.sourceAddonKey,
        sourceAddonId = sourceAddonId,
        eventType = GetEnumName(WIRE_ALERT_EVENT_TYPES, data.eventType),
        eventTypeCode = data.eventType,
        quality = GetEnumName(WIRE_ALERT_QUALITIES, data.quality),
        qualityCode = data.quality,
        actorName = data.actorName,
        ttlSeconds = data.ttlSeconds,
        receivedAt = now,
        expiresAt = now + data.ttlSeconds,
    }

    alertSequenceByUnitTag[unitTag] = {
        sequence = data.sequence,
        expiresAt = event.expiresAt,
    }
    EZOCore:FireCallback("EZO_CORE_GROUP_ALERT_EVENT_RECEIVED", unitTag, event)
    EZOCore:FireCallback("EZOCore:GroupAlertEventReceived", unitTag, event)
    return true
end

HandleRemotePerformanceState = function(unitTag, data, allowPending)
    if not IsCurrentGroupUnit(unitTag) or type(data) ~= "table" then
        return false
    end

    local now = NowSeconds()
    if data.protocolVersion ~= PRESENCE_PROTOCOL_VERSION
        or not IsIntegerInRange(data.sequence, 1, SEQUENCE_MODULUS - 1)
        or not IsIntegerInRange(data.ttlSeconds, 15, 300)
        or not IsIntegerInRange(data.pingMs, 0, 4095)
        or not IsIntegerInRange(data.fps, 0, 255)
        or not IsKnownEnumValue(WIRE_PRIVACY_STATES, data.privacyState)
        or not ResolveAddonKey(data.sourceAddonKey) then
        return false
    end

    local peer = peersByUnitTag[unitTag]
    local sourceAddonId = ADDON_ID_BY_KEY[data.sourceAddonKey]
    local sourceAddon = peer and sourceAddonId and peer.addons[sourceAddonId]
    if IsPeerExpired(peer, NowSeconds())
        or not sourceAddon
        or not sourceAddon.capabilitySet
        or sourceAddon.capabilitySet["group.performanceState.provider"] ~= true then
        local queuedPerformance = pendingPerformanceByUnitTag[unitTag]
        if allowPending ~= false
            and (not queuedPerformance
                or IsStateExpired(queuedPerformance, now)
                or IsNewerSequence(data.sequence, queuedPerformance.data and queuedPerformance.data.sequence)) then
            pendingPerformanceByUnitTag[unitTag] = {
                data = {
                    protocolVersion = data.protocolVersion,
                    sequence = data.sequence,
                    sourceAddonKey = data.sourceAddonKey,
                    pingMs = data.pingMs,
                    fps = data.fps,
                    privacyState = data.privacyState,
                    ttlSeconds = data.ttlSeconds,
                },
                expiresAt = now + math.min(data.ttlSeconds, 15),
            }
        end
        return false
    end

    local previousPerformance = performanceSequenceByUnitTag[unitTag]
    if previousPerformance and IsStateExpired(previousPerformance, now) then
        performanceSequenceByUnitTag[unitTag] = nil
        performanceStateByUnitTag[unitTag] = nil
        previousPerformance = nil
    end
    local previousPerformanceSequence = previousPerformance and previousPerformance.sequence or nil
    if not IsNewerSequence(data.sequence, previousPerformanceSequence) then
        return false
    end

    local publicMetrics = data.privacyState == WIRE_PRIVACY_STATES.public
    pendingPerformanceByUnitTag[unitTag] = nil
    performanceSequenceByUnitTag[unitTag] = {
        sequence = data.sequence,
        expiresAt = now + data.ttlSeconds,
    }
    performanceStateByUnitTag[unitTag] = {
        unitTag = unitTag,
        protocolVersion = data.protocolVersion,
        sequence = data.sequence,
        sourceAddonKey = data.sourceAddonKey,
        sourceAddonId = sourceAddonId,
        pingMs = publicMetrics and data.pingMs or 0,
        fps = publicMetrics and data.fps or 0,
        privacyState = data.privacyState,
        ttlSeconds = data.ttlSeconds,
        receivedAt = now,
        expiresAt = now + data.ttlSeconds,
    }

    EZOCore:FireCallback(
        "EZO_CORE_GROUP_PERFORMANCE_STATE_UPDATED",
        unitTag,
        CopyPerformanceState(performanceStateByUnitTag[unitTag]))
    EZOCore:FireCallback(
        "EZOCore:GroupPerformanceStateUpdated",
        unitTag,
        CopyPerformanceState(performanceStateByUnitTag[unitTag]))
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
        return HandleRemoteActivityState(unitTag, data.activityState)
    end
    if type(data.performanceState) == "table" then
        return HandleRemotePerformanceState(unitTag, data.performanceState)
    end
    if type(data.alertEvent) == "table" then
        return HandleRemoteAlertEvent(unitTag, data.alertEvent)
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

    local ok, registerError = pcall(function()
        handler = lgb:RegisterHandler("EZOCore")
        handler:SetDisplayName("EZOCore")
        handler:SetDescription("EZO family group presence and informational state")
        protocol = handler:DeclareProtocol(LGB_PROTOCOL_ID, LGB_PROTOCOL_NAME)
        if not AddGroupProtocolFields(protocol, lgb) then
            error("LibGroupBroadcast field classes unavailable")
        end
        protocol:OnData(HandleRemoteGroupMessage)
        if protocol:Finalize({ replaceQueuedMessages = false, isRelevantInCombat = false }) ~= true then
            error("LibGroupBroadcast protocol could not be finalized")
        end
        firePresenceRequest = handler:DeclareCustomEvent(LGB_REQUEST_EVENT_ID, LGB_REQUEST_EVENT_NAME, {
            displayName = "EZOCore presence request",
            description = "Requests EZO family presence from group members.",
            isRelevantInCombat = false,
        })
        if lgb:RegisterForCustomEvent(LGB_REQUEST_EVENT_NAME, function(unitTag)
            if IsCurrentGroupUnit(unitTag) then
                SchedulePresenceAnnouncement(250, 750)
                EZOCore:FireCallback("EZO_CORE_GROUP_PRESENCE_REQUESTED", unitTag)
                EZOCore:FireCallback("EZOCore:GroupPresenceRequested", unitTag)
            end
        end) ~= true then
            error("LibGroupBroadcast custom event callback could not be registered")
        end
    end)

    if not ok then
        handler = nil
        protocol = nil
        firePresenceRequest = nil
        status.detail = tostring(registerError or "unknown registration error")
        EZOCore:Warn("Group presence transport initialization failed: %s", status.detail)
    else
        status.detail = nil
        EZOCore:Info(
            "Group presence transport active: protocol %s (%d), request event %d%s",
            LGB_PROTOCOL_NAME,
            LGB_PROTOCOL_ID,
            LGB_REQUEST_EVENT_ID,
            (LGB_PROTOCOL_IS_TEST_ID or LGB_REQUEST_EVENT_IS_TEST_ID) and " [beta test IDs]" or ""
        )
    end

    RefreshStatus()
    return status.active == true
end

local function CanSendProtocolMessage()
    GROUP_PRESENCE.Initialize()
    if not protocol or type(protocol.IsEnabled) ~= "function" then
        return false, status.reason
    end
    if not IsLocalPlayerGrouped() then
        return false, "notGrouped"
    end
    if not protocol:IsEnabled() then
        return false, "protocolDisabled"
    end
    return true
end

local function SendProtocolMessage(payload, isRelevantInCombat)
    local canSend, reason = CanSendProtocolMessage()
    if not canSend then
        return false, reason
    end
    return protocol:Send(payload, {
        replaceQueuedMessages = false,
        isRelevantInCombat = isRelevantInCombat == true,
    })
end

local function ResolveStateArgument(first, second)
    if second ~= nil then
        return second
    end
    return first
end

function GROUP_PRESENCE.Initialize()
    if initialized then
        return status.active == true
    end

    initialized = true
    RefreshStatus()
    RegisterLibGroupBroadcast()
    if _G.EVENT_MANAGER and _G.EVENT_GROUP_UPDATE then
        _G.EVENT_MANAGER:RegisterForEvent("EZOCore_GroupPresence", _G.EVENT_GROUP_UPDATE, function()
            GROUP_PRESENCE.PrunePeers(true)
            SchedulePresenceAnnouncement(500, 1000)
        end)
    end
    if type(EZOCore.RegisterCallback) == "function" and EZOCore.EVENT_ADDON_REGISTERED then
        EZOCore:RegisterCallback(EZOCore.EVENT_ADDON_REGISTERED, function()
            SchedulePresenceAnnouncement(500, 1000)
        end)
    end
    if protocol
        and _G.EVENT_MANAGER
        and type(_G.EVENT_MANAGER.RegisterForUpdate) == "function" then
        if type(_G.EVENT_MANAGER.UnregisterForUpdate) == "function" then
            _G.EVENT_MANAGER:UnregisterForUpdate(HEARTBEAT_UPDATE_NAME)
        end
        _G.EVENT_MANAGER:RegisterForUpdate(HEARTBEAT_UPDATE_NAME, PRESENCE_HEARTBEAT_MS, function()
            RefreshStatus()
            if status.active and IsLocalPlayerGrouped() then
                GROUP_PRESENCE.AnnounceLocalPresence()
            end
        end)
    end
    SchedulePresenceAnnouncement(500, 1000)
    return status.active == true
end

function GROUP_PRESENCE.GetStatus()
    RefreshStatus()
    return {
        available = status.available,
        configured = status.configured,
        enabled = status.enabled,
        active = status.active,
        reason = status.reason,
        detail = status.detail,
        protocolVersion = PRESENCE_PROTOCOL_VERSION,
        ttlSeconds = PEER_TTL_SECONDS,
        heartbeatMilliseconds = PRESENCE_HEARTBEAT_MS,
        protocolName = LGB_PROTOCOL_NAME,
        requestEventName = LGB_REQUEST_EVENT_NAME,
        protocolId = LGB_PROTOCOL_ID,
        requestEventId = LGB_REQUEST_EVENT_ID,
        protocolTestId = LGB_PROTOCOL_IS_TEST_ID,
        requestEventTestId = LGB_REQUEST_EVENT_IS_TEST_ID,
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
        protocolTestId = LGB_PROTOCOL_IS_TEST_ID,
        requestEventId = LGB_REQUEST_EVENT_ID,
        requestEventTestId = LGB_REQUEST_EVENT_IS_TEST_ID,
        ttlSeconds = PEER_TTL_SECONDS,
        heartbeatMilliseconds = PRESENCE_HEARTBEAT_MS,
        messageTypes = {
            presence = WIRE_MESSAGE_TYPES.presence,
            activityState = WIRE_MESSAGE_TYPES.activityState,
            performanceState = WIRE_MESSAGE_TYPES.performanceState,
            alertEvent = WIRE_MESSAGE_TYPES.alertEvent,
        },
        activityTypes = WIRE_ACTIVITY_TYPES,
        activityStages = WIRE_ACTIVITY_STAGES,
        activityResults = WIRE_ACTIVITY_RESULTS,
        activityDifficulties = WIRE_ACTIVITY_DIFFICULTIES,
        privacyStates = WIRE_PRIVACY_STATES,
        alertEventTypes = WIRE_ALERT_EVENT_TYPES,
        alertQualities = WIRE_ALERT_QUALITIES,
        addonKeys = ADDON_KEYS,
        capabilityBits = CAPABILITY_BITS,
    }
end

function GROUP_PRESENCE.GetReservationDraft()
    return {
        addon = "EZOCore",
        author = "@Zuriplayer",
        protocolName = LGB_PROTOCOL_NAME,
        protocolId = LGB_PROTOCOL_ID,
        protocolDescription = "EZO family group presence and small informational activity state messages.",
        customEventName = LGB_REQUEST_EVENT_NAME,
        customEventId = LGB_REQUEST_EVENT_ID,
        customEventDescription = "Requests an EZO group presence/state resync from compatible group members.",
        status = (LGB_PROTOCOL_IS_TEST_ID or LGB_REQUEST_EVENT_IS_TEST_ID)
            and "temporary beta test IDs; permanent valid reservations pending"
            or "reserved on the official ESOUI LibGroupBroadcast ID registry",
    }
end

function GROUP_PRESENCE.PrunePeers(checkCurrentGroup)
    local now = NowSeconds()
    for unitTag, peer in pairs(peersByUnitTag) do
        local currentDisplayName = checkCurrentGroup == true and ResolveDisplayName(unitTag) or nil
        local identityChanged = currentDisplayName and peer.displayName
            and currentDisplayName ~= peer.displayName
        if IsPeerExpired(peer, now)
            or (checkCurrentGroup == true and not IsCurrentGroupUnit(unitTag))
            or identityChanged then
            peersByUnitTag[unitTag] = nil
            ClearPeerTransientState(unitTag)
        end
    end
    for unitTag, pendingState in pairs(pendingPerformanceByUnitTag) do
        if IsStateExpired(pendingState, now)
            or (checkCurrentGroup == true and not IsCurrentGroupUnit(unitTag)) then
            pendingPerformanceByUnitTag[unitTag] = nil
        end
    end
end

function GROUP_PRESENCE.GetRemotePeers()
    GROUP_PRESENCE.PrunePeers()
    local out = {}
    for _, peer in pairs(peersByUnitTag) do
        local copiedPeer = CopyPeer(peer)
        local activityState = activityStateByUnitTag[peer.unitTag]
        local performanceState = performanceStateByUnitTag[peer.unitTag]
        if copiedPeer and not IsStateExpired(activityState, NowSeconds()) then
            copiedPeer.activityState = CopyActivityState(activityState)
        end
        if copiedPeer and not IsStateExpired(performanceState, NowSeconds()) then
            copiedPeer.performanceState = CopyPerformanceState(performanceState)
        end
        out[#out + 1] = copiedPeer
    end
    table.sort(out, function(left, right)
        return tostring(left.unitTag or "") < tostring(right.unitTag or "")
    end)
    return out
end

function GROUP_PRESENCE.GetRemotePeer(_, unitTag)
    GROUP_PRESENCE.PrunePeers()
    local peer = CopyPeer(peersByUnitTag[unitTag])
    local activityState = activityStateByUnitTag[unitTag]
    local performanceState = performanceStateByUnitTag[unitTag]
    if peer and not IsStateExpired(activityState, NowSeconds()) then
        peer.activityState = CopyActivityState(activityState)
    end
    if peer and not IsStateExpired(performanceState, NowSeconds()) then
        peer.performanceState = CopyPerformanceState(performanceState)
    end
    return peer
end

function GROUP_PRESENCE.GetPeerActivityState(_, unitTag)
    GROUP_PRESENCE.PrunePeers()
    local state = activityStateByUnitTag[unitTag]
    if IsStateExpired(state, NowSeconds()) then
        activityStateByUnitTag[unitTag] = nil
        activitySequenceByUnitTag[unitTag] = nil
        return nil
    end
    return CopyActivityState(state)
end

function GROUP_PRESENCE.GetPeerPerformanceState(_, unitTag)
    GROUP_PRESENCE.PrunePeers()
    local state = performanceStateByUnitTag[unitTag]
    if IsStateExpired(state, NowSeconds()) then
        performanceStateByUnitTag[unitTag] = nil
        performanceSequenceByUnitTag[unitTag] = nil
        return nil
    end
    return CopyPerformanceState(state)
end

function GROUP_PRESENCE.GetPeerAddon(_, unitTag, addonId)
    local peer = GROUP_PRESENCE.GetRemotePeer(nil, unitTag)
    if not peer or type(addonId) ~= "string" then
        return nil
    end
    return peer.addons[string.lower(addonId)]
end

function GROUP_PRESENCE.HasPeerCapability(_, unitTag, addonId, capability, minimumApiVersion, minimumAddOnVersion)
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
    if type(minimumAddOnVersion) == "number"
        and (tonumber(addon.addOnVersion) or 0) < minimumAddOnVersion then
        return false
    end
    return addon.capabilitySet and addon.capabilitySet[capability] == true
end

function GROUP_PRESENCE.GetPeerCompatibility(_, unitTag, addonId, capability, minimumApiVersion, minimumAddOnVersion)
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
    if type(minimumAddOnVersion) == "number"
        and (tonumber(addon.addOnVersion) or 0) < minimumAddOnVersion then
        return "incompatible"
    end
    return "compatible"
end

function GROUP_PRESENCE.AnnounceLocalPresence()
    return SendProtocolMessage(GetLocalPresencePayload(), true)
end

function GROUP_PRESENCE.PublishActivityState(first, second)
    local state = ResolveStateArgument(first, second)
    if type(state) ~= "table" then
        return false, "invalidState"
    end

    local sourceAddonKey = ResolveAddonKey(state.sourceAddonKey or state.sourceAddonId or state.addonId)
    local activityType = NormalizeEnumValue(WIRE_ACTIVITY_TYPES, state.activityType)
    local stage = NormalizeEnumValue(WIRE_ACTIVITY_STAGES, state.stage)
    local result = NormalizeEnumValue(WIRE_ACTIVITY_RESULTS, state.result)
    local difficulty = NormalizeEnumValue(WIRE_ACTIVITY_DIFFICULTIES, state.difficulty or "unknown")
    local sessionId = math.floor(tonumber(state.sessionId) or 0)
    local progressCurrent = math.floor(tonumber(state.progressCurrent) or 0)
    local progressTotal = math.floor(tonumber(state.progressTotal) or 0)
    local pendingCount = math.floor(tonumber(state.pendingCount) or 0)
    local expectedCount = math.floor(tonumber(state.expectedCount) or 0)
    local targetKey = tostring(state.targetKey or "")
    if not sourceAddonKey then
        return false, "invalidSourceAddon"
    end
    if not activityType or not stage or not result or not difficulty then
        return false, "invalidActivityState"
    end
    if not IsIntegerInRange(sessionId, 0, 4294967295) then
        return false, "invalidSessionId"
    end
    if #targetKey > 32 then
        return false, "invalidTargetKey"
    end
    if not IsIntegerInRange(progressCurrent, 0, 15)
        or not IsIntegerInRange(progressTotal, 0, 15)
        or progressCurrent > progressTotal then
        return false, "invalidActivityProgress"
    end
    if not IsIntegerInRange(pendingCount, 0, 12)
        or not IsIntegerInRange(expectedCount, 0, 12)
        or pendingCount > expectedCount then
        return false, "invalidActivityCounts"
    end
    local sourceAddonId = ADDON_ID_BY_KEY[sourceAddonKey]
    local presence = EZOCore.Presence
    if not sourceAddonId
        or not presence
        or type(presence.HasLocalCapability) ~= "function"
        or not presence.HasLocalCapability(
            presence,
            sourceAddonId,
            "group.activityState.provider",
            1
        ) then
        return false, "providerCapabilityMissing"
    end
    if not IsLocalPlayerGrouped() then
        return false, "notGrouped"
    end
    if type(_G.IsUnitGroupLeader) == "function" and not _G.IsUnitGroupLeader("player") then
        return false, "notGroupLeader"
    end

    return SendProtocolMessage({ activityState = {
        protocolVersion = PRESENCE_PROTOCOL_VERSION,
        sequence = NextSequence(),
        sourceAddonKey = sourceAddonKey,
        activityType = activityType,
        stage = stage,
        result = result,
        difficulty = difficulty,
        sessionId = sessionId,
        progressCurrent = progressCurrent,
        progressTotal = progressTotal,
        pendingCount = pendingCount,
        expectedCount = expectedCount,
        ttlSeconds = NormalizeTtlSeconds(state.ttlSeconds, 60),
        targetKey = targetKey,
    } }, false)
end

function GROUP_PRESENCE.PublishAlertEvent(first, second)
    local event = ResolveStateArgument(first, second)
    if type(event) ~= "table" then
        return false, "invalidEvent"
    end

    local sourceAddonKey = ResolveAddonKey(event.sourceAddonKey or event.sourceAddonId or event.addonId)
    local eventType = NormalizeEnumValue(WIRE_ALERT_EVENT_TYPES, event.eventType or event.type)
    local quality = NormalizeEnumValue(WIRE_ALERT_QUALITIES, event.quality or "unknown")
    local ttlSeconds = NormalizeTtlSeconds(event.ttlSeconds, 15)
    if ttlSeconds > 60 then
        ttlSeconds = 60
    end
    local actorName = tostring(event.actorName or "")

    if not sourceAddonKey then
        return false, "invalidSourceAddon"
    end
    if not eventType or not quality then
        return false, "invalidAlertEvent"
    end
    if actorName == "" or #actorName > 40 then
        return false, "invalidActorName"
    end

    local sourceAddonId = ADDON_ID_BY_KEY[sourceAddonKey]
    local presence = EZOCore.Presence
    if not sourceAddonId
        or not presence
        or type(presence.HasLocalCapability) ~= "function"
        or not presence.HasLocalCapability(
            presence,
            sourceAddonId,
            "alerts.groupEvent.provider",
            1
        ) then
        return false, "providerCapabilityMissing"
    end
    if not IsLocalPlayerGrouped() then
        return false, "notGrouped"
    end

    return SendProtocolMessage({ alertEvent = {
        protocolVersion = PRESENCE_PROTOCOL_VERSION,
        sequence = NextSequence(),
        sourceAddonKey = sourceAddonKey,
        eventType = eventType,
        quality = quality,
        ttlSeconds = ttlSeconds,
        actorName = actorName,
    } }, true)
end

function GROUP_PRESENCE.PublishPerformanceState(first, second)
    local state = ResolveStateArgument(first, second)
    if type(state) ~= "table" then
        return false, "invalidState"
    end

    local sourceAddonKey = ResolveAddonKey(state.sourceAddonKey or state.sourceAddonId or state.addonId)
    local privacyState = NormalizeEnumValue(WIRE_PRIVACY_STATES, state.privacyState or state.privacy)
    if not sourceAddonKey then
        return false, "invalidSourceAddon"
    end
    if not privacyState then
        return false, "invalidPrivacyState"
    end
    local pingMs = math.floor(tonumber(state.pingMs) or tonumber(state.ping) or -1)
    local fps = math.floor(tonumber(state.fps) or -1)
    if privacyState == WIRE_PRIVACY_STATES.public then
        if not IsIntegerInRange(pingMs, 0, 4095) then
            return false, "invalidPing"
        end
        if not IsIntegerInRange(fps, 0, 255) then
            return false, "invalidFps"
        end
    else
        pingMs = 0
        fps = 0
    end
    local sourceAddonId = ADDON_ID_BY_KEY[sourceAddonKey]
    local presence = EZOCore.Presence
    if not sourceAddonId
        or not presence
        or type(presence.HasLocalCapability) ~= "function"
        or not presence.HasLocalCapability(
            presence,
            sourceAddonId,
            "group.performanceState.provider",
            1
        ) then
        return false, "providerCapabilityMissing"
    end

    local isPublic = privacyState == WIRE_PRIVACY_STATES.public
    local now = NowSeconds()
    local lastPublishedAt = performancePublishedAtBySourceKey[sourceAddonKey]
    if isPublic and now > 0 and lastPublishedAt and (now - lastPublishedAt) < 10 then
        return false, "throttled"
    end
    local lastPrivacyState = performancePrivacyStateBySourceKey[sourceAddonKey]
    local lastNonPublicPublishedAt = performanceNonPublicPublishedAtBySourceKey[sourceAddonKey]
    if not isPublic
        and lastPrivacyState == privacyState
        and now > 0
        and lastNonPublicPublishedAt
        and (now - lastNonPublicPublishedAt) < 10 then
        return false, "throttled"
    end

    local sent, reason = SendProtocolMessage({ performanceState = {
        protocolVersion = PRESENCE_PROTOCOL_VERSION,
        sequence = NextSequence(),
        sourceAddonKey = sourceAddonKey,
        pingMs = pingMs,
        fps = fps,
        privacyState = privacyState,
        ttlSeconds = NormalizeTtlSeconds(state.ttlSeconds, 30),
    } }, true)
    if sent then
        performancePrivacyStateBySourceKey[sourceAddonKey] = privacyState
        if isPublic then
            performancePublishedAtBySourceKey[sourceAddonKey] = now
        else
            performanceNonPublicPublishedAtBySourceKey[sourceAddonKey] = now
        end
    end
    return sent, reason
end

function GROUP_PRESENCE.RequestPresence()
    GROUP_PRESENCE.Initialize()
    if not firePresenceRequest or not handler then
        return false, status.reason
    end
    if not IsLocalPlayerGrouped() then
        return false, "notGrouped"
    end
    if not handler:IsCustomEventEnabled(LGB_REQUEST_EVENT_NAME) then
        return false, "requestEventDisabled"
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
