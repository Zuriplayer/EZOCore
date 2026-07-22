local EZOCore = EZOCore

-- Session-only coordinator for movable EZO UI surfaces. Addons retain ownership
-- of controls, previews, positions and SavedVariables.
local LAYOUT = {}
EZOCore.Layout = LAYOUT

local SERVICE_NAME = "family.layout"
local SERVICE_API_VERSION = 1
local EVENT_NAMESPACE = "EZOCore_Layout"
local EVENT_SURFACE_REGISTERED = "EZOCore:LayoutSurfaceRegistered"
local EVENT_SURFACE_CHANGED = "EZOCore:LayoutSurfaceChanged"

local surfacesById = {}
local surfaceOrder = {}
local initialized = false
local warnedFailures = {}

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

local function ResolveArgument(first, second)
    if type(first) == "table" and type(first.RegisterSurface) == "function" then
        return second
    end
    if second ~= nil then
        return second
    end
    return first
end

local function ResolveTwoArguments(first, second, third)
    if type(first) == "table" and type(first.SetSurfaceEditMode) == "function" then
        return second, third
    end
    if third ~= nil then
        return second, third
    end
    return first, second
end

local function WarnFailureOnce(surface, action, err)
    local surfaceId = surface and surface.id or "unknown"
    local key = surfaceId .. ":" .. tostring(action)
    if warnedFailures[key] then
        EZOCore:Debug("Layout surface '%s' failed %s: %s", surfaceId, action, tostring(err))
        return
    end

    warnedFailures[key] = true
    EZOCore:Warn("Layout surface '%s' failed %s: %s", surfaceId, action, tostring(err))
end

local function CallSurfaceCallback(surface, action, callback, ...)
    local ok, result = pcall(callback, ...)
    if ok then
        return true, result
    end

    local firstError = result
    ok, result = pcall(callback, surface, ...)
    if ok then
        return true, result
    end

    WarnFailureOnce(surface, action, firstError)
    return false, result
end

local function ReadEditMode(surface)
    if not surface or type(surface.isEditMode) ~= "function" then
        return false
    end

    local ok, enabled = CallSurfaceCallback(surface, "to report edit mode", surface.isEditMode)
    if not ok then
        return false
    end
    return enabled == true
end

local function CanEnable(surface)
    if type(surface.canEdit) ~= "function" then
        return true
    end

    local ok, allowed = CallSurfaceCallback(surface, "its edit-mode availability check", surface.canEdit)
    if not ok then
        return false
    end
    return allowed ~= false
end

local function CopySurface(surface)
    return {
        id = surface.id,
        addonId = surface.addonId,
        addonName = ResolveText(surface.addonName, surface.addonId),
        name = ResolveText(surface.name, surface.id),
        tooltip = ResolveText(surface.tooltip, ""),
        sortOrder = surface.sortOrder,
        editing = ReadEditMode(surface),
        available = CanEnable(surface),
    }
end

function LAYOUT.RegisterSurface(first, second)
    local definition = ResolveArgument(first, second)
    if type(definition) ~= "table" then
        EZOCore:Warn("RegisterSurface: definition must be a table")
        return false
    end

    local surfaceId = NormalizeId(definition.id)
    local addonId = NormalizeId(definition.addonId)
    if not surfaceId or not addonId then
        EZOCore:Warn("RegisterSurface: id and addonId must be stable non-empty ids")
        return false
    end
    if type(definition.setEditMode) ~= "function" or type(definition.isEditMode) ~= "function" then
        EZOCore:Warn("RegisterSurface: '%s' requires setEditMode and isEditMode callbacks", surfaceId)
        return false
    end
    if not IsNonEmptyString(definition.addonName) and type(definition.addonName) ~= "function" then
        EZOCore:Warn("RegisterSurface: '%s' requires addonName", surfaceId)
        return false
    end
    if not IsNonEmptyString(definition.name) and type(definition.name) ~= "function" then
        EZOCore:Warn("RegisterSurface: '%s' requires a display name", surfaceId)
        return false
    end

    local existing = surfacesById[surfaceId]
    if existing and existing.addonId ~= addonId then
        EZOCore:Warn("RegisterSurface: '%s' is already owned by addon '%s'", surfaceId, existing.addonId)
        return false
    end

    if not existing then
        surfaceOrder[#surfaceOrder + 1] = surfaceId
    end
    surfacesById[surfaceId] = {
        id = surfaceId,
        addonId = addonId,
        addonName = definition.addonName,
        name = definition.name,
        tooltip = definition.tooltip,
        sortOrder = tonumber(definition.sortOrder) or 100,
        setEditMode = definition.setEditMode,
        isEditMode = definition.isEditMode,
        canEdit = definition.canEdit,
    }

    EZOCore:Debug("Layout surface registered: %s", surfaceId)
    EZOCore:FireCallback(EVENT_SURFACE_REGISTERED, surfaceId, addonId)
    return true
end

function LAYOUT.GetSurfaces()
    local result = {}
    for _, surfaceId in ipairs(surfaceOrder) do
        local surface = surfacesById[surfaceId]
        if surface then
            result[#result + 1] = CopySurface(surface)
        end
    end

    table.sort(result, function(left, right)
        local leftAddon = string.lower(left.addonName)
        local rightAddon = string.lower(right.addonName)
        if leftAddon ~= rightAddon then
            return leftAddon < rightAddon
        end
        if left.sortOrder ~= right.sortOrder then
            return left.sortOrder < right.sortOrder
        end
        return string.lower(left.name) < string.lower(right.name)
    end)
    return result
end

function LAYOUT.IsSurfaceEditMode(first, second)
    local surfaceId = ResolveArgument(first, second)
    return ReadEditMode(surfacesById[NormalizeId(surfaceId)])
end

function LAYOUT.SetSurfaceEditMode(first, second, third)
    local surfaceId, enabled = ResolveTwoArguments(first, second, third)
    local surface = surfacesById[NormalizeId(surfaceId)]
    if not surface then
        return false
    end

    enabled = enabled == true
    if enabled and not CanEnable(surface) then
        return false
    end

    local ok, result = CallSurfaceCallback(surface, "to change edit mode", surface.setEditMode, enabled)
    if not ok then
        return false
    end

    local actual = ReadEditMode(surface)
    EZOCore:FireCallback(EVENT_SURFACE_CHANGED, surface.id, actual)
    if result == false then
        return false
    end
    return actual == enabled
end

function LAYOUT.SetAllEditMode(first, second)
    local enabled = ResolveArgument(first, second)
    local success = true
    for _, surfaceId in ipairs(surfaceOrder) do
        if not LAYOUT:SetSurfaceEditMode(surfaceId, enabled == true) then
            success = false
        end
    end
    return success
end

function LAYOUT.AreAllSurfacesEditing()
    local found = false
    for _, surfaceId in ipairs(surfaceOrder) do
        local surface = surfacesById[surfaceId]
        if surface then
            found = true
            if not ReadEditMode(surface) then
                return false
            end
        end
    end
    return found
end

function LAYOUT.IsAnySurfaceEditing()
    for _, surfaceId in ipairs(surfaceOrder) do
        if ReadEditMode(surfacesById[surfaceId]) then
            return true
        end
    end
    return false
end

function LAYOUT.Initialize()
    if initialized then
        return true
    end
    initialized = true

    local playerDeactivatedEvent = _G.EVENT_PLAYER_DEACTIVATED
    if EVENT_MANAGER and playerDeactivatedEvent then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, playerDeactivatedEvent, function()
            LAYOUT:SetAllEditMode(false)
        end)
    end
    return true
end

EZOCore:RegisterService(SERVICE_NAME, SERVICE_API_VERSION, LAYOUT)
