local EZOCore = EZOCore

-- Shared diagnostics facade for the EZO family. It owns no buffers or update
-- handlers and degrades to false-returning no-ops when the optional backend is
-- unavailable.
local SERVICE = {
    name = "family.debug",
    apiVersion = 1,
}
EZOCore.DebugService = SERVICE

local loggerByTag = {}
local hasCheckedForLibrary = false
local loggerLibrary
local controllersById = {}
local controllerOrder = {}
local warnedControllerFailures = {}

local EVENT_CONTROLLER_REGISTERED = "EZOCore:DebugControllerRegistered"
local EVENT_CONTROLLERS_CHANGED = "EZOCore:DebugControllersChanged"

local LEVEL_METHODS = {
    debug = "Debug",
    info = "Info",
    warn = "Warn",
    warning = "Warn",
    error = "Error",
}

local function SafeFormat(message, ...)
    local text = tostring(message or "")
    if select("#", ...) == 0 then
        return text
    end

    local ok, formatted = pcall(string.format, text, ...)
    if ok then
        return formatted
    end

    local parts = { text }
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    return table.concat(parts, " ")
end

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function NormalizeId(value)
    if not IsNonEmptyString(value) then
        return nil
    end

    local id = string.lower(value)
    if not string.match(id, "^[%w%.%-_]+$") then
        return nil
    end
    return id
end

local function ResolveText(value, fallback)
    if type(value) == "function" then
        local ok, result = pcall(value)
        if ok and IsNonEmptyString(result) then
            return result
        end
    elseif IsNonEmptyString(value) then
        return value
    end
    return fallback
end

local function WarnControllerFailureOnce(controller, action, err)
    local controllerId = controller and controller.id or "unknown"
    local key = controllerId .. ":" .. tostring(action)
    if warnedControllerFailures[key] then
        EZOCore:Debug("Debug controller '%s' failed %s: %s", controllerId, action, tostring(err))
        return
    end

    warnedControllerFailures[key] = true
    EZOCore:Warn("Debug controller '%s' failed %s: %s", controllerId, action, tostring(err))
end

local function CallControllerCallback(controller, action, callback, ...)
    local ok, result = pcall(callback, ...)
    if ok then
        return true, result
    end

    local firstError = result
    ok, result = pcall(callback, controller, ...)
    if ok then
        return true, result
    end

    WarnControllerFailureOnce(controller, action, firstError)
    return false, result
end

local function ReadControllerEnabled(controller)
    if not controller or type(controller.isEnabled) ~= "function" then
        return false
    end

    local ok, enabled = CallControllerCallback(controller, "to report its state", controller.isEnabled)
    if not ok then
        return false
    end
    return enabled == true
end

local function GetLibrary()
    if hasCheckedForLibrary then
        return loggerLibrary
    end

    hasCheckedForLibrary = true
    local lib = _G.LibDebugLogger
    if type(lib) == "function" or type(lib) == "table" then
        loggerLibrary = lib
    end
    return loggerLibrary
end

local function GetLogger(tag)
    if type(tag) ~= "string" or tag == "" then
        return nil
    end
    if loggerByTag[tag] then
        return loggerByTag[tag]
    end

    local lib = GetLibrary()
    if not lib then
        return nil
    end

    local ok, result = false, nil
    if type(lib) == "function" then
        ok, result = pcall(lib, tag)
    elseif type(lib.Create) == "function" then
        ok, result = pcall(function()
            return lib:Create(tag)
        end)
    end

    if ok and result then
        loggerByTag[tag] = result
        return result
    end
    return nil
end

local function Log(tag, level, message, ...)
    local methodName = LEVEL_METHODS[string.lower(tostring(level or ""))]
    if not methodName then
        return false
    end

    local logger = GetLogger(tag)
    if not logger or type(logger[methodName]) ~= "function" then
        return false
    end

    local text = SafeFormat(message, ...)
    return pcall(function()
        logger[methodName](logger, text)
    end)
end

function SERVICE.IsAvailable()
    return GetLibrary() ~= nil
end

function SERVICE.Log(_, tag, level, message, ...)
    return Log(tag, level, message, ...)
end

function SERVICE.Debug(_, tag, message, ...)
    return Log(tag, "debug", message, ...)
end

function SERVICE.Info(_, tag, message, ...)
    return Log(tag, "info", message, ...)
end

function SERVICE.Warn(_, tag, message, ...)
    return Log(tag, "warning", message, ...)
end

function SERVICE.Error(_, tag, message, ...)
    return Log(tag, "error", message, ...)
end

function SERVICE.IsViewerAvailable()
    local viewer = _G.DebugLogViewer
    return viewer ~= nil
        and (type(viewer.ShowWindow) == "function" or type(viewer.ToggleWindow) == "function")
end

function SERVICE.ShowViewer()
    local viewer = _G.DebugLogViewer
    if not viewer then
        return false
    end

    if type(viewer.ShowWindow) == "function" then
        return pcall(viewer.ShowWindow)
    end
    if type(viewer.ToggleWindow) == "function" then
        return pcall(viewer.ToggleWindow)
    end
    return false
end

function SERVICE.RegisterController(_, definition)
    if type(definition) ~= "table" then
        EZOCore:Warn("RegisterController: definition must be a table")
        return false
    end

    local controllerId = NormalizeId(definition.id)
    local addonId = NormalizeId(definition.addonId)
    if not controllerId or not addonId then
        EZOCore:Warn("RegisterController: id and addonId must be stable non-empty ids")
        return false
    end
    if type(definition.isEnabled) ~= "function" or type(definition.setEnabled) ~= "function" then
        EZOCore:Warn("RegisterController: '%s' requires isEnabled and setEnabled callbacks", controllerId)
        return false
    end
    if not IsNonEmptyString(definition.addonName) and type(definition.addonName) ~= "function" then
        EZOCore:Warn("RegisterController: '%s' requires addonName", controllerId)
        return false
    end

    local existing = controllersById[controllerId]
    if existing and existing.addonId ~= addonId then
        EZOCore:Warn("RegisterController: '%s' is already owned by addon '%s'", controllerId, existing.addonId)
        return false
    end

    if not existing then
        controllerOrder[#controllerOrder + 1] = controllerId
    end
    controllersById[controllerId] = {
        id = controllerId,
        addonId = addonId,
        addonName = definition.addonName,
        name = definition.name,
        isEnabled = definition.isEnabled,
        setEnabled = definition.setEnabled,
    }

    EZOCore:FireCallback(EVENT_CONTROLLER_REGISTERED, controllerId, addonId)
    return true
end

function SERVICE.GetControllers()
    local result = {}
    for _, controllerId in ipairs(controllerOrder) do
        local controller = controllersById[controllerId]
        if controller then
            result[#result + 1] = {
                id = controller.id,
                addonId = controller.addonId,
                addonName = ResolveText(controller.addonName, controller.addonId),
                name = ResolveText(controller.name, controller.id),
                enabled = ReadControllerEnabled(controller),
            }
        end
    end

    table.sort(result, function(left, right)
        local leftAddon = string.lower(left.addonName)
        local rightAddon = string.lower(right.addonName)
        if leftAddon ~= rightAddon then
            return leftAddon < rightAddon
        end
        return string.lower(left.name) < string.lower(right.name)
    end)
    return result
end

function SERVICE.IsAnyControllerEnabled()
    for _, controllerId in ipairs(controllerOrder) do
        if ReadControllerEnabled(controllersById[controllerId]) then
            return true
        end
    end
    return false
end

function SERVICE.DisableAllControllers()
    local disabled = 0
    local failures = 0

    for _, controllerId in ipairs(controllerOrder) do
        local controller = controllersById[controllerId]
        if controller then
            local wasEnabled = ReadControllerEnabled(controller)
            if wasEnabled then
                local ok, result = CallControllerCallback(controller, "to disable", controller.setEnabled, false)
                if not ok or result == false then
                    failures = failures + 1
                else
                    disabled = disabled + 1
                end
            end
        end
    end

    EZOCore:FireCallback(EVENT_CONTROLLERS_CHANGED, disabled, failures)
    return failures == 0, disabled, failures
end

function EZOCore.Debug(_, message, ...)
    return SERVICE:Debug(EZOCore.name, message, ...)
end

function EZOCore.Info(_, message, ...)
    return SERVICE:Info(EZOCore.name, message, ...)
end

function EZOCore.Warn(_, message, ...)
    return SERVICE:Warn(EZOCore.name, message, ...)
end

function EZOCore.Error(_, message, ...)
    return SERVICE:Error(EZOCore.name, message, ...)
end
