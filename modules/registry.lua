local EZOCore = EZOCore

-- Local-only addon and service registry.
-- No SavedVariables, no cross-client messages: this is purely an in-memory
-- lookup table shared between addons that are loaded in the same ESO client.

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

--- Registers metadata describing an installed addon so other addons can
--- discover it. metadata must at least contain an `id` field.
function EZOCore:RegisterAddon(metadata)
    if type(metadata) ~= "table" or not IsNonEmptyString(metadata.id) then
        self:Warn("RegisterAddon: metadata.id must be a non-empty string")
        return false
    end

    local addons = self.internal.addons
    if addons[metadata.id] then
        self:Warn("RegisterAddon: '%s' is already registered, overwriting", metadata.id)
    end

    addons[metadata.id] = {
        id = metadata.id,
        name = metadata.name or metadata.id,
        version = metadata.version,
        apiVersion = metadata.apiVersion,
    }

    self:Info("Addon registered: %s", metadata.id)
    self:FireCallback("EZOCore:AddonRegistered", addons[metadata.id])
    return true
end

--- Returns the registration record for a given addon id, or nil.
function EZOCore:GetAddon(addonId)
    if not IsNonEmptyString(addonId) then
        return nil
    end
    return self.internal.addons[addonId]
end

--- Returns a plain array with every currently registered addon record.
function EZOCore:GetRegisteredAddons()
    local list = {}
    for _, addon in pairs(self.internal.addons) do
        list[#list + 1] = addon
    end
    return list
end

--- Registers a service implementation under `name` at a given API version.
--- `service` should be a plain table of functions/fields; EZOCore never
--- calls into it except to hand the reference back via GetService.
function EZOCore:RegisterService(name, apiVersion, service)
    if not IsNonEmptyString(name) then
        self:Warn("RegisterService: name must be a non-empty string")
        return false
    end
    if type(apiVersion) ~= "number" then
        self:Warn("RegisterService: apiVersion must be a number (service '%s')", name)
        return false
    end
    if type(service) ~= "table" then
        self:Warn("RegisterService: service must be a table (service '%s')", name)
        return false
    end

    self.internal.services[name] = {
        name = name,
        apiVersion = apiVersion,
        service = service,
    }

    self:Info("Service registered: %s (API v%d)", name, apiVersion)
    self:FireCallback("EZOCore:ServiceRegistered", name, apiVersion)
    return true
end

--- Looks up a previously registered service. If minimumApiVersion is given
--- and the registered service is older, returns nil instead of the service.
function EZOCore:GetService(name, minimumApiVersion)
    local entry = self.internal.services[name]
    if not entry then
        return nil
    end

    if minimumApiVersion and entry.apiVersion < minimumApiVersion then
        self:Warn("GetService: '%s' requires API v%d but only v%d is registered",
            name, minimumApiVersion, entry.apiVersion)
        return nil
    end

    return entry.service, entry.apiVersion
end
