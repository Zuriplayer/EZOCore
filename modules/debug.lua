local EZOCore = EZOCore

-- Thin diagnostics wrapper around LibDebugLogger.
-- Degrades to no-ops when the library is not installed, so EZOCore never
-- hard-depends on it and never leaks technical diagnostics into player chat.
local logger
local hasCheckedForLogger = false

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

local function GetLogger()
    if hasCheckedForLogger then
        return logger
    end

    hasCheckedForLogger = true
    local lib = _G.LibDebugLogger
    if type(lib) == "function" then
        local ok, result = pcall(lib, EZOCore.name)
        if ok then
            logger = result
        end
    elseif type(lib) == "table" and type(lib.Create) == "function" then
        local ok, result = pcall(function()
            return lib:Create(EZOCore.name)
        end)
        if ok then
            logger = result
        end
    end

    return logger
end

function EZOCore.Debug(_, message, ...)
    local log = GetLogger()
    if log and type(log.Debug) == "function" then
        local text = SafeFormat(message, ...)
        pcall(function()
            log:Debug(text)
        end)
    end
end

function EZOCore.Info(_, message, ...)
    local log = GetLogger()
    if log and type(log.Info) == "function" then
        local text = SafeFormat(message, ...)
        pcall(function()
            log:Info(text)
        end)
    end
end

function EZOCore.Warn(_, message, ...)
    local log = GetLogger()
    if log and type(log.Warn) == "function" then
        local text = SafeFormat(message, ...)
        pcall(function()
            log:Warn(text)
        end)
    end
end

function EZOCore.Error(_, message, ...)
    local log = GetLogger()
    if log and type(log.Error) == "function" then
        local text = SafeFormat(message, ...)
        pcall(function()
            log:Error(text)
        end)
    end
end
