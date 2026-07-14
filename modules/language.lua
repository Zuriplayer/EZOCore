local EZOCore = EZOCore

-- Local account-wide language preference for the EZO family.
-- Addons still own their own string tables and must keep standalone fallbacks.

local LANGUAGE = {}
EZOCore.Language = LANGUAGE

local SERVICE_NAME = "family.language"
local SERVICE_API_VERSION = 1
local SAVED_VARIABLES_NAME = "EZOCoreSavedVariables"
local SAVED_VARIABLES_VERSION = 1

local DEFAULTS = {
    language = "auto",
}

local SUPPORTED_LANGUAGES = {
    auto = true,
    en = true,
    es = true,
}

local sv

local function NormalizeLanguage(language)
    local value = string.lower(tostring(language or "auto"))
    if SUPPORTED_LANGUAGES[value] then
        return value
    end
    return nil
end

local function GetClientLanguage()
    if type(GetCVar) == "function" then
        local value = GetCVar("Language.2")
        if type(value) == "string" and string.lower(value) == "es" then
            return "es"
        end
    end
    return "en"
end

local function EnsureSavedVariables()
    if sv then
        return sv
    end

    if type(ZO_SavedVars) == "table" and type(ZO_SavedVars.NewAccountWide) == "function" then
        sv = ZO_SavedVars:NewAccountWide(SAVED_VARIABLES_NAME, SAVED_VARIABLES_VERSION, nil, DEFAULTS)
    else
        sv = {
            language = DEFAULTS.language,
        }
        EZOCore:Warn("Language preference is session-only because ZO_SavedVars is unavailable")
    end

    sv.language = NormalizeLanguage(sv.language) or DEFAULTS.language
    return sv
end

function LANGUAGE.Initialize()
    EnsureSavedVariables()
    return true
end

function LANGUAGE.GetConfiguredLanguage()
    return EZOCore:GetConfiguredLanguage()
end

function LANGUAGE.GetLanguage()
    return EZOCore:GetLanguage()
end

function LANGUAGE.GetClientLanguage()
    return EZOCore:GetClientLanguage()
end

function LANGUAGE.SetLanguage(first, second)
    local language = second ~= nil and second or first
    return EZOCore:SetLanguage(language)
end

function LANGUAGE.IsSupportedLanguage(first, second)
    local language = second ~= nil and second or first
    return EZOCore:IsSupportedLanguage(language)
end

function EZOCore.IsSupportedLanguage(first, second)
    local language = second ~= nil and second or first
    return NormalizeLanguage(language) ~= nil
end

function EZOCore.GetClientLanguage()
    return GetClientLanguage()
end

function EZOCore.GetConfiguredLanguage()
    return (NormalizeLanguage((sv and sv.language) or DEFAULTS.language) or DEFAULTS.language)
end

function EZOCore:GetLanguage()
    local configured = self:GetConfiguredLanguage()
    if configured == "auto" then
        return self:GetClientLanguage()
    end
    return configured
end

function EZOCore:SetLanguage(language)
    local normalized = NormalizeLanguage(language)
    if not normalized then
        self:Warn("SetLanguage: unsupported language '%s'", tostring(language))
        return false
    end

    local store = EnsureSavedVariables()
    local previousEffective = self:GetLanguage()
    local previousConfigured = self:GetConfiguredLanguage()
    if previousConfigured == normalized then
        return true
    end

    store.language = normalized
    local effective = self:GetLanguage()
    self:FireCallback(self.EVENT_LANGUAGE_CHANGED, effective, normalized, previousEffective)
    self:FireCallback("EZOCore:LanguageChanged", effective, normalized, previousEffective)
    return true
end

EZOCore:RegisterService(SERVICE_NAME, SERVICE_API_VERSION, LANGUAGE)
