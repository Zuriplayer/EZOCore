local EZOCore = EZOCore

-- Thin diagnostics wrapper around LibDebugLogger.
-- Degrades to no-ops (or simple d() output) when the library is not installed,
-- so EZOCore never hard-depends on it.
local logger
local hasCheckedForLogger = false

local function GetLogger()
    if hasCheckedForLogger then
        return logger
    end

    hasCheckedForLogger = true
    if LibDebugLogger then
        logger = LibDebugLogger(EZOCore.name)
    end

    return logger
end

function EZOCore:Debug(message, ...)
    local log = GetLogger()
    if log then
        log:Debug(string.format(message, ...))
    end
end

function EZOCore:Info(message, ...)
    local log = GetLogger()
    if log then
        log:Info(string.format(message, ...))
    end
end

function EZOCore:Warn(message, ...)
    local log = GetLogger()
    local formatted = string.format(message, ...)
    if log then
        log:Warn(formatted)
    else
        d("[EZOCore] Warning: " .. formatted)
    end
end

function EZOCore:Error(message, ...)
    local log = GetLogger()
    local formatted = string.format(message, ...)
    if log then
        log:Error(formatted)
    else
        d("[EZOCore] Error: " .. formatted)
    end
end
