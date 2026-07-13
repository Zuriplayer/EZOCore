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
    if type(LibDebugLogger) == "function" then
        local ok, result = pcall(LibDebugLogger, EZOCore.name)
        if ok then
            logger = result
        end
    end

    return logger
end

function EZOCore.Debug(_, message, ...)
    local log = GetLogger()
    if log and type(log.Debug) == "function" then
        log:Debug(SafeFormat(message, ...))
    end
end

function EZOCore.Info(_, message, ...)
    local log = GetLogger()
    if log and type(log.Info) == "function" then
        log:Info(SafeFormat(message, ...))
    end
end

function EZOCore.Warn(_, message, ...)
    local log = GetLogger()
    if log and type(log.Warn) == "function" then
        log:Warn(SafeFormat(message, ...))
    end
end

function EZOCore.Error(_, message, ...)
    local log = GetLogger()
    if log and type(log.Error) == "function" then
        log:Error(SafeFormat(message, ...))
    end
end
