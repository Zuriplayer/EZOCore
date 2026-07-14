local EZOCore = EZOCore

-- Session-only local state exchange between EZO addons loaded in this client.
-- This is not persistence and never sends data to other players.

local LOCAL_STATE = {}
EZOCore.LocalState = LOCAL_STATE

local SERVICE_NAME = "family.localState"
local SERVICE_API_VERSION = 1
local EVENT_CHANGED = EZOCore.EVENT_LOCAL_STATE_CHANGED or "EZO_CORE_LOCAL_STATE_CHANGED"
local EVENT_CLEARED = EZOCore.EVENT_LOCAL_STATE_CLEARED or "EZO_CORE_LOCAL_STATE_CLEARED"

local entries = {}
local subscriptions = {}

local function NowSeconds()
    if type(_G.GetFrameTimeSeconds) == "function" then
        return _G.GetFrameTimeSeconds()
    end
    return 0
end

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function NormalizeKey(value)
    if not IsNonEmptyString(value) then
        return nil
    end
    local key = string.lower(value)
    if not string.match(key, "^[%w][%w%.%-_]*%.[%w%.%-_]+$") then
        return nil
    end
    return key
end

local function NormalizeAddonId(value)
    if not IsNonEmptyString(value) then
        return nil
    end
    local addonId = string.lower(value)
    if not string.match(addonId, "^[%w%-_]+$") then
        return nil
    end
    return addonId
end

local function CopyValue(value, depth)
    local valueType = type(value)
    if valueType ~= "table" then
        if valueType == "function" or valueType == "thread" or valueType == "userdata" then
            return nil
        end
        return value
    end

    depth = (depth or 0) + 1
    if depth > 4 then
        return nil
    end

    local copy = {}
    for key, entry in pairs(value) do
        local keyType = type(key)
        if keyType ~= "string" and keyType ~= "number" and keyType ~= "boolean" then
            return nil
        end
        local copiedEntry = CopyValue(entry, depth)
        if copiedEntry == nil and entry ~= nil then
            return nil
        end
        copy[key] = copiedEntry
    end
    return copy
end

local function CopyEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end
    return {
        key = entry.key,
        value = CopyValue(entry.value),
        publisherAddonId = entry.publisherAddonId,
        version = entry.version,
        publishedAt = entry.publishedAt,
        expiresAt = entry.expiresAt,
    }
end

local function IsExpired(entry, now)
    return type(entry) == "table"
        and type(entry.expiresAt) == "number"
        and entry.expiresAt <= now
end

function LOCAL_STATE.FireCleared(key, previousEntry, reason)
    local copiedPrevious = CopyEntry(previousEntry)
    EZOCore:FireCallback(EVENT_CLEARED, key, copiedPrevious, reason)
    EZOCore:FireCallback("EZOCore:LocalStateCleared", key, copiedPrevious, reason)

    local listeners = subscriptions[key]
    if not listeners or #listeners == 0 then
        return
    end

    local snapshot = {}
    for index = 1, #listeners do
        snapshot[index] = listeners[index]
    end

    for _, callback in ipairs(snapshot) do
        local ok, err = pcall(callback, nil, copiedPrevious, reason)
        if not ok then
            EZOCore:Error("LocalState subscriber error for '%s': %s", key, tostring(err))
        end
    end
end

local function PruneExpired()
    local now = NowSeconds()
    for key, entry in pairs(entries) do
        if IsExpired(entry, now) then
            entries[key] = nil
            LOCAL_STATE.FireCleared(key, entry, "expired")
        end
    end
end

local function FireSubscribers(key, entry, previousEntry)
    local listeners = subscriptions[key]
    if not listeners or #listeners == 0 then
        return
    end

    local snapshot = {}
    for index = 1, #listeners do
        snapshot[index] = listeners[index]
    end

    local copiedEntry = CopyEntry(entry)
    local copiedPrevious = CopyEntry(previousEntry)
    for _, callback in ipairs(snapshot) do
        local ok, err = pcall(callback, copiedEntry, copiedPrevious)
        if not ok then
            EZOCore:Error("LocalState subscriber error for '%s': %s", key, tostring(err))
        end
    end
end

function LOCAL_STATE.Publish(_, key, value, options)
    local normalizedKey = NormalizeKey(key)
    if not normalizedKey then
        EZOCore:Warn("LocalState.Publish: key must be namespaced, e.g. 'ezotools.groupActivity'")
        return false, "invalidKey"
    end

    local copiedValue = CopyValue(value)
    if copiedValue == nil and value ~= nil then
        EZOCore:Warn("LocalState.Publish: value for '%s' must be plain serializable data", normalizedKey)
        return false, "invalidValue"
    end

    options = type(options) == "table" and options or {}
    local publisherAddonId = NormalizeAddonId(options.publisherAddonId or options.addonId)
    local version = tonumber(options.version) or 1
    local ttlSeconds = tonumber(options.ttlSeconds)
    local now = NowSeconds()

    local previousEntry = entries[normalizedKey]
    local entry = {
        key = normalizedKey,
        value = copiedValue,
        publisherAddonId = publisherAddonId,
        version = version,
        publishedAt = now,
        expiresAt = ttlSeconds and ttlSeconds > 0 and (now + ttlSeconds) or nil,
    }
    entries[normalizedKey] = entry

    local copiedEntry = CopyEntry(entry)
    local copiedPrevious = CopyEntry(previousEntry)
    EZOCore:FireCallback(EVENT_CHANGED, normalizedKey, copiedEntry, copiedPrevious)
    EZOCore:FireCallback("EZOCore:LocalStateChanged", normalizedKey, copiedEntry, copiedPrevious)
    FireSubscribers(normalizedKey, entry, previousEntry)
    return true
end

function LOCAL_STATE.Get(_, key)
    local normalizedKey = NormalizeKey(key)
    if not normalizedKey then
        return nil
    end
    PruneExpired()
    return CopyEntry(entries[normalizedKey])
end

function LOCAL_STATE.GetValue(_, key)
    local entry = LOCAL_STATE:Get(key)
    return entry and entry.value or nil
end

function LOCAL_STATE.GetPublisher(_, key)
    local entry = LOCAL_STATE:Get(key)
    return entry and entry.publisherAddonId or nil
end

function LOCAL_STATE.Clear(_, key, reason)
    local normalizedKey = NormalizeKey(key)
    if not normalizedKey then
        return false, "invalidKey"
    end

    local previousEntry = entries[normalizedKey]
    if not previousEntry then
        return true
    end
    entries[normalizedKey] = nil
    LOCAL_STATE.FireCleared(normalizedKey, previousEntry, reason or "cleared")
    return true
end

function LOCAL_STATE.Subscribe(_, key, callback)
    local normalizedKey = NormalizeKey(key)
    if not normalizedKey then
        EZOCore:Warn("LocalState.Subscribe: key must be namespaced")
        return false, "invalidKey"
    end
    if type(callback) ~= "function" then
        EZOCore:Warn("LocalState.Subscribe: callback must be a function")
        return false, "invalidCallback"
    end

    subscriptions[normalizedKey] = subscriptions[normalizedKey] or {}
    for index = 1, #subscriptions[normalizedKey] do
        if subscriptions[normalizedKey][index] == callback then
            return true
        end
    end
    table.insert(subscriptions[normalizedKey], callback)
    return true
end

function LOCAL_STATE.Unsubscribe(_, key, callback)
    local normalizedKey = NormalizeKey(key)
    if not normalizedKey or type(callback) ~= "function" then
        return false
    end

    local listeners = subscriptions[normalizedKey]
    if not listeners then
        return false
    end

    for index = #listeners, 1, -1 do
        if listeners[index] == callback then
            table.remove(listeners, index)
            return true
        end
    end
    return false
end

function LOCAL_STATE.GetKeys()
    PruneExpired()
    local keys = {}
    for key in pairs(entries) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

function LOCAL_STATE.GetStatus()
    PruneExpired()
    local count = 0
    for _ in pairs(entries) do
        count = count + 1
    end
    return {
        serviceName = SERVICE_NAME,
        serviceApiVersion = SERVICE_API_VERSION,
        entries = count,
    }
end

EZOCore:RegisterService(SERVICE_NAME, SERVICE_API_VERSION, LOCAL_STATE)
