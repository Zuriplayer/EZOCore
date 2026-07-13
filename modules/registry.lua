local EZOCore = EZOCore

-- Local-only addon and service registry.
-- No SavedVariables, no cross-client messages: this is purely an in-memory
-- lookup table shared between addons that are loaded in the same ESO client.

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function IsPositiveNumber(value)
    return type(value) == "number" and value >= 0
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

local function CopyTable(value)
    if type(value) ~= "table" then
        return nil
    end

    local copy = {}
    for key, entry in pairs(value) do
        copy[key] = entry
    end
    return copy
end

local function NormalizeCapabilities(value)
    if type(value) ~= "table" then
        return nil
    end

    local capabilities = {}
    for key, entry in pairs(value) do
        if type(key) == "number" and IsNonEmptyString(entry) then
            capabilities[entry] = true
        elseif IsNonEmptyString(key) and entry == true then
            capabilities[key] = true
        end
    end

    return capabilities
end

local function CopyAddonRecord(addon)
    if not addon then
        return nil
    end

    return {
        id = addon.id,
        name = addon.name,
        version = addon.version,
        addOnVersion = addon.addOnVersion,
        apiVersion = addon.apiVersion,
        capabilities = CopyTable(addon.capabilities),
        debugName = addon.debugName,
        build = addon.build,
    }
end

local function MeetsMinimumApiVersion(addon, minimumApiVersion)
    if not addon then
        return false
    end
    if minimumApiVersion == nil then
        return true
    end
    if type(minimumApiVersion) ~= "number" then
        return false
    end
    return type(addon.apiVersion) == "number" and addon.apiVersion >= minimumApiVersion
end

--- Registers metadata describing an installed addon so other addons can
--- discover it.
function EZOCore:RegisterAddon(metadata)
    if type(metadata) ~= "table" then
        self:Warn("RegisterAddon: metadata must be a table")
        return false
    end

    local addonId = NormalizeId(metadata.id)
    if not addonId then
        self:Warn("RegisterAddon: metadata.id must be a stable non-empty id")
        return false
    end
    if not IsNonEmptyString(metadata.name) then
        self:Warn("RegisterAddon: metadata.name must be a non-empty string (addon '%s')", addonId)
        return false
    end
    if not IsNonEmptyString(metadata.version) then
        self:Warn("RegisterAddon: metadata.version must be a non-empty string (addon '%s')", addonId)
        return false
    end
    if not IsPositiveNumber(metadata.addOnVersion) then
        self:Warn("RegisterAddon: metadata.addOnVersion must be a number (addon '%s')", addonId)
        return false
    end
    if not IsPositiveNumber(metadata.apiVersion) then
        self:Warn("RegisterAddon: metadata.apiVersion must be a number (addon '%s')", addonId)
        return false
    end

    local capabilities = NormalizeCapabilities(metadata.capabilities)
    if not capabilities then
        self:Warn("RegisterAddon: metadata.capabilities must be a table (addon '%s')", addonId)
        return false
    end

    local addons = self.internal.addons
    if addons[addonId] then
        self:Warn("RegisterAddon: '%s' is already registered", addonId)
        return false
    end

    addons[addonId] = {
        id = addonId,
        name = metadata.name,
        version = metadata.version,
        addOnVersion = metadata.addOnVersion,
        apiVersion = metadata.apiVersion,
        capabilities = capabilities,
        debugName = metadata.debugName,
        build = metadata.build,
    }

    local record = CopyAddonRecord(addons[addonId])
    self:Info("Addon registered: %s v%s", addonId, metadata.version)
    self:FireCallback(self.EVENT_ADDON_REGISTERED, record)
    self:FireCallback("EZOCore:AddonRegistered", record)
    return true
end

--- Returns the registration record for a given addon id, or nil.
function EZOCore:GetAddon(addonId)
    local normalizedId = NormalizeId(addonId)
    if not normalizedId then
        return nil
    end
    return CopyAddonRecord(self.internal.addons[normalizedId])
end

--- Returns a plain array with every currently registered addon record.
function EZOCore:GetRegisteredAddons()
    local list = {}
    for _, addon in pairs(self.internal.addons) do
        list[#list + 1] = CopyAddonRecord(addon)
    end
    return list
end

--- Returns true if `addonId` is registered and meets the optional API floor.
function EZOCore:HasAddon(addonId, minimumApiVersion)
    local normalizedId = NormalizeId(addonId)
    if not normalizedId then
        return false
    end
    return MeetsMinimumApiVersion(self.internal.addons[normalizedId], minimumApiVersion)
end

--- Returns true if `addonId` has `capability` and meets the optional API floor.
function EZOCore:HasCapability(addonId, capability, minimumApiVersion)
    local normalizedId = NormalizeId(addonId)
    if not normalizedId or not IsNonEmptyString(capability) then
        return false
    end

    local addon = self.internal.addons[normalizedId]
    if not MeetsMinimumApiVersion(addon, minimumApiVersion) then
        return false
    end

    return addon.capabilities and addon.capabilities[capability] == true
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
    self:FireCallback(self.EVENT_SERVICE_REGISTERED, name, apiVersion)
    self:FireCallback("EZOCore:ServiceRegistered", name, apiVersion)
    return true
end

--- Looks up a previously registered service. If minimumApiVersion is given
--- and the registered service is older, returns nil instead of the service.
function EZOCore:GetService(name, minimumApiVersion)
    if not IsNonEmptyString(name) then
        return nil
    end
    if minimumApiVersion ~= nil and type(minimumApiVersion) ~= "number" then
        self:Warn("GetService: minimumApiVersion must be a number (service '%s')", name)
        return nil
    end

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
