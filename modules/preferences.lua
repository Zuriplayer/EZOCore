local EZOCore = EZOCore

-- Account-wide family preference policy. Consumer addons keep ownership of
-- their own SavedVariables and can use this service to choose a storage scope.

local PREFERENCES = {}
EZOCore.Preferences = PREFERENCES

local SERVICE_NAME = "family.preferences"
local SERVICE_API_VERSION = 1
local SAVED_VARIABLES_NAME = "EZOCoreSavedVariables"
local SAVED_VARIABLES_VERSION = 1

local DEFAULT_SCOPE = "character"
local ACCOUNT_WIDE_ADDONS = {
    ezoraidplanner = true,
    ezotest = true,
    ezotools = true,
}
local ACCOUNT_WIDE_PREFERENCE_KEYS = {
    ["ezocamsens.meta.settingsScope"] = true,
    ["ezocore.language"] = true,
    ["ezocore.preferences.defaultScope"] = true,
    ["ezocore.settings.addonLifecycleDefaults"] = true,
    ["ezochat.history.messages"] = true,
    ["ezoraidplanner.events"] = true,
    ["ezoraidplanner.nextEventId"] = true,
    ["ezotools.friends"] = true,
    ["ezotools.raidLeaderActivitySession.lastActivity"] = true,
}
local DEFAULTS = {
    preferences = {
        defaultScope = DEFAULT_SCOPE,
        accountWideAddons = ACCOUNT_WIDE_ADDONS,
        accountWideKeys = ACCOUNT_WIDE_PREFERENCE_KEYS,
    },
}

local SUPPORTED_SCOPES = {
    account = true,
    character = true,
}

local sv

local function NormalizeScope(scope)
    local value = string.lower(tostring(scope or DEFAULT_SCOPE))
    if value == "accountwide" or value == "account_wide" or value == "global" then
        value = "account"
    elseif value == "char" or value == "characterid" or value == "character_id" then
        value = "character"
    end
    if SUPPORTED_SCOPES[value] then
        return value
    end
    return nil
end

local function NormalizePreferenceKey(addonId, preferenceKey)
    if type(addonId) ~= "string" or addonId == "" then
        return nil
    end
    if type(preferenceKey) ~= "string" or preferenceKey == "" then
        return nil
    end
    return string.lower(addonId) .. "." .. preferenceKey
end

local function NormalizeAddonId(addonId)
    if type(addonId) ~= "string" or addonId == "" then
        return nil
    end
    return string.lower(addonId)
end

local function ApplyAccountWideAddonCatalog(accountWideAddons)
    if type(accountWideAddons) ~= "table" then
        return
    end
    for addonId in pairs(ACCOUNT_WIDE_ADDONS) do
        accountWideAddons[addonId] = true
    end
end

local function ApplyAccountWidePreferenceCatalog(accountWideKeys)
    if type(accountWideKeys) ~= "table" then
        return
    end
    for key in pairs(ACCOUNT_WIDE_PREFERENCE_KEYS) do
        accountWideKeys[key] = true
    end
end

local function EnsureSavedVariables()
    if sv then
        return sv
    end

    if type(ZO_SavedVars) == "table" and type(ZO_SavedVars.NewAccountWide) == "function" then
        sv = ZO_SavedVars:NewAccountWide(SAVED_VARIABLES_NAME, SAVED_VARIABLES_VERSION, nil, DEFAULTS)
    else
        sv = {
            preferences = {
                defaultScope = DEFAULT_SCOPE,
                accountWideKeys = {},
            },
        }
        EZOCore:Warn("Preference storage policy is session-only because ZO_SavedVars is unavailable")
    end

    if type(sv.preferences) ~= "table" then
        sv.preferences = {}
    end
    local preferences = sv.preferences
    preferences.defaultScope = NormalizeScope(preferences.defaultScope) or DEFAULT_SCOPE
    if type(preferences.accountWideAddons) ~= "table" then
        preferences.accountWideAddons = {}
    end
    if type(preferences.accountWideKeys) ~= "table" then
        preferences.accountWideKeys = {}
    end
    ApplyAccountWideAddonCatalog(preferences.accountWideAddons)
    ApplyAccountWidePreferenceCatalog(preferences.accountWideKeys)
    return sv
end

local function GetPreferencesStore()
    return EnsureSavedVariables().preferences
end

local function ResolvePreferenceArguments(first, second, third)
    if third ~= nil then
        return second, third
    end
    return first, second
end

function PREFERENCES.Initialize()
    EnsureSavedVariables()
    return true
end

function PREFERENCES.GetDefaultScope()
    return EZOCore:GetDefaultPreferenceScope()
end

function PREFERENCES.SetDefaultScope(first, second)
    local scope = second ~= nil and second or first
    return EZOCore:SetDefaultPreferenceScope(scope)
end

function PREFERENCES.GetScope(first, second, third)
    local addonId, preferenceKey = ResolvePreferenceArguments(first, second, third)
    return EZOCore:GetPreferenceScope(addonId, preferenceKey)
end

function PREFERENCES.RegisterAccountWide(first, second, third)
    local addonId, preferenceKey = ResolvePreferenceArguments(first, second, third)
    return EZOCore:RegisterAccountWidePreference(addonId, preferenceKey)
end

function PREFERENCES.RegisterAccountWideAddon(first, second)
    local addonId = second ~= nil and second or first
    return EZOCore:RegisterAccountWideAddon(addonId)
end

function PREFERENCES.IsAddonAccountWide(first, second)
    local addonId = second ~= nil and second or first
    return EZOCore:IsAddonAccountWide(addonId)
end

function PREFERENCES.IsAccountWide(first, second, third)
    local addonId, preferenceKey = ResolvePreferenceArguments(first, second, third)
    return EZOCore:IsPreferenceAccountWide(addonId, preferenceKey)
end

function EZOCore.IsSupportedPreferenceScope(first, second)
    local scope = second ~= nil and second or first
    return NormalizeScope(scope) ~= nil
end

function EZOCore.GetDefaultPreferenceScope()
    return GetPreferencesStore().defaultScope
end

function EZOCore.SetDefaultPreferenceScope(first, second)
    local scope = second ~= nil and second or first
    local normalized = NormalizeScope(scope)
    if not normalized then
        EZOCore:Warn("SetDefaultPreferenceScope: unsupported scope '%s'", tostring(scope))
        return false
    end

    local store = GetPreferencesStore()
    local previous = store.defaultScope
    if previous == normalized then
        return true
    end

    store.defaultScope = normalized
    EZOCore:FireCallback(EZOCore.EVENT_PREFERENCE_SCOPE_CHANGED, normalized, previous)
    EZOCore:FireCallback("EZOCore:PreferenceScopeChanged", normalized, previous)
    return true
end

function EZOCore.RegisterAccountWidePreference(first, second, third)
    local addonId, preferenceKey = ResolvePreferenceArguments(first, second, third)
    local key = NormalizePreferenceKey(addonId, preferenceKey)
    if not key then
        EZOCore:Warn("RegisterAccountWidePreference: addonId and preferenceKey must be non-empty strings")
        return false
    end

    GetPreferencesStore().accountWideKeys[key] = true
    return true
end

function EZOCore.RegisterAccountWideAddon(first, second)
    local addonId = NormalizeAddonId(second ~= nil and second or first)
    if not addonId then
        EZOCore:Warn("RegisterAccountWideAddon: addonId must be a non-empty string")
        return false
    end

    GetPreferencesStore().accountWideAddons[addonId] = true
    return true
end

function EZOCore.IsAddonAccountWide(first, second)
    local addonId = NormalizeAddonId(second ~= nil and second or first)
    if not addonId then
        return false
    end
    return GetPreferencesStore().accountWideAddons[addonId] == true
end

function EZOCore.IsPreferenceAccountWide(first, second, third)
    local addonId, preferenceKey = ResolvePreferenceArguments(first, second, third)
    if EZOCore:IsAddonAccountWide(addonId) then
        return true
    end

    local key = NormalizePreferenceKey(addonId, preferenceKey)
    if key and GetPreferencesStore().accountWideKeys[key] == true then
        return true
    end
    return EZOCore:GetDefaultPreferenceScope() == "account"
end

function EZOCore.GetPreferenceScope(first, second, third)
    local addonId, preferenceKey = ResolvePreferenceArguments(first, second, third)
    if EZOCore:IsPreferenceAccountWide(addonId, preferenceKey) then
        return "account"
    end
    return "character"
end

EZOCore:RegisterService(SERVICE_NAME, SERVICE_API_VERSION, PREFERENCES)
