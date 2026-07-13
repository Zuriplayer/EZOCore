local EZOCore = EZOCore

-- Local in-memory callback bus. Addons register plain function references
-- for named events; EZOCore never calls a function by name string and never
-- sends anything over the network or to other clients/players.

--- Registers `callback` to run whenever `eventName` is fired locally.
function EZOCore:RegisterCallback(eventName, callback)
    if type(eventName) ~= "string" or eventName == "" then
        self:Warn("RegisterCallback: eventName must be a non-empty string")
        return false
    end
    if type(callback) ~= "function" then
        self:Warn("RegisterCallback: callback must be a function (event '%s')", eventName)
        return false
    end

    local callbacks = self.internal.callbacks
    callbacks[eventName] = callbacks[eventName] or {}
    table.insert(callbacks[eventName], callback)
    return true
end

--- Removes a previously registered callback for `eventName`.
--- Returns true if a matching callback was found and removed.
function EZOCore:UnregisterCallback(eventName, callback)
    if type(eventName) ~= "string" or eventName == "" then
        return false
    end
    if type(callback) ~= "function" then
        return false
    end

    local list = self.internal.callbacks[eventName]
    if not list then
        return false
    end

    for i = #list, 1, -1 do
        if list[i] == callback then
            table.remove(list, i)
            return true
        end
    end

    return false
end

--- Fires `eventName` locally, calling every registered callback with the
--- given arguments. Errors inside a callback are caught and logged so one
--- broken listener cannot break the others.
function EZOCore:FireCallback(eventName, ...)
    if type(eventName) ~= "string" or eventName == "" then
        self:Warn("FireCallback: eventName must be a non-empty string")
        return
    end

    local list = self.internal.callbacks[eventName]
    if not list or #list == 0 then
        return
    end

    -- Snapshot so callbacks can safely (un)register during iteration.
    local snapshot = {}
    for i = 1, #list do
        snapshot[i] = list[i]
    end

    for _, callback in ipairs(snapshot) do
        local ok, err = pcall(callback, ...)
        if not ok then
            self:Error("Callback error for '%s': %s", eventName, tostring(err))
        end
    end
end
