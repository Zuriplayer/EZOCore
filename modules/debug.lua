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
