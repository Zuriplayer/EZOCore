# EZOCore Consumer Integration

This document describes the current local-only integration surface for EZO
addons. It only covers functionality implemented in EZOCore now: local addon
registration, service discovery, capabilities, callbacks and the central
`Settings > EZO` service.

## Scope

EZOCore is optional infrastructure. Functional addons must keep working when it
is not installed.

Use:

```text
## OptionalDependsOn: EZOCore
```

Do not use `DependsOn: EZOCore` unless the addon truly cannot load without it.
Do not add direct dependencies between two functional EZO addons.

## Register An Addon

Register during addon initialization, after both the consumer addon and EZOCore
have loaded:

```lua
if EZOCore and type(EZOCore.RegisterAddon) == "function" then
    EZOCore:RegisterAddon({
        id = "ezotools",
        name = "EZOTools",
        version = EZOTools.ADDON_VERSION,
        addOnVersion = EZOTools.ADDON_VERSION_NUMERIC,
        apiVersion = 1,
        capabilities = {
            "group.activities",
            "group.activityState.provider",
            "group.activityState.consumer",
        },
    })
end
```

Rules:

- `id` must be stable, lowercase and safe for lookup.
- `version` is the visible SemVer release string.
- `addOnVersion` is the numeric ESO `## AddOnVersion`.
- `apiVersion` is the local API contract version exposed by that addon.
- `capabilities` should describe concrete supported behavior, not vague addon
  names.

EZOCore rejects invalid metadata and duplicate addon IDs without breaking the
caller.

## Query Capabilities

Use capability checks instead of hard-coding sibling addon assumptions:

```lua
if EZOCore and EZOCore:HasCapability("ezotools", "group.activities", 1) then
    -- A compatible local EZOTools registration is present.
end
```

`HasAddon(addonId, minimumApiVersion)` checks only the addon registration.
`HasCapability(addonId, capability, minimumApiVersion)` checks registration,
API compatibility and a concrete capability.

## Query Local Presence

The `family.presence` service exposes the same local registration data through
a service facade that future remote presence work can build on:

```lua
local presence = EZOCore and EZOCore:GetService("family.presence", 1)
if presence and presence:HasLocalCapability("ezotools", "group.activities", 1) then
    local ezotools = presence:GetLocalAddon("ezotools")
    -- Inspect ezotools.version, ezotools.addOnVersion, ezotools.capabilities.
end
```

`GetLocalAddons()` returns the current client only. It does not imply anything
about group members and does not send LibGroupBroadcast traffic.

## Register A Service

Services are explicit local tables. EZOCore does not execute functions by name.

```lua
local service = {
    GetState = function()
        return currentState
    end,
}

if EZOCore and type(EZOCore.RegisterService) == "function" then
    EZOCore:RegisterService("example.state", 1, service)
end
```

Consumers retrieve services defensively:

```lua
local service = EZOCore and EZOCore:GetService("example.state", 1)
if service and type(service.GetState) == "function" then
    local state = service:GetState()
end
```

## Register Settings

Addons with LibAddonMenu option tables should keep their normal LAM panel and
register that panel with EZOCore when it is available:

```lua
local panelData = {
    type = "panel",
    name = "EZOTools",
    displayName = "EZOTools",
    author = "@Zuriplayer",
    version = EZOTools.ADDON_VERSION,
    ezoStage = "beta",
    registerForRefresh = true,
}

local options = BuildOptions()

if EZOCore and type(EZOCore.RegisterSettingsPanel) == "function" then
    EZOCore:RegisterSettingsPanel("ezotools", "EZOTools_Panel", panelData, options)
elseif LibAddonMenu2 then
    LibAddonMenu2:RegisterAddonPanel("EZOTools_Panel", panelData)
    LibAddonMenu2:RegisterOptionControls("EZOTools_Panel", options)
end
```

The central `Settings > EZO` window renders each registered addon's LAM controls
inside its own addon view. Selecting an addon therefore stays inside the EZO
panel and does not create a duplicate entry in the standard addon settings
list. The standalone LAM panel is only the compatibility fallback when
EZOCore is unavailable.

`panelData.ezoStage` must match `addon.stage` in the repository's
`ezo-addon.json`. Supported runtime values are `development`, `beta`, `stable`,
`maintenance`, and `archived`. EZOCore owns validation, display order, group
labels, and help text. Missing or invalid values are placed in `Unclassified`;
EZOCore never infers maturity from an addon name or version.

## Local Callbacks

Callbacks are in-memory and local to one ESO client:

```lua
local function OnAddonRegistered(addon)
    -- Inspect addon.id, addon.version, addon.capabilities, etc.
end

if EZOCore and type(EZOCore.RegisterCallback) == "function" then
    EZOCore:RegisterCallback(EZOCore.EVENT_ADDON_REGISTERED, OnAddonRegistered)
end
```

Use `UnregisterCallback(eventName, callback)` when tearing down temporary
listeners.

## Not Implemented Yet

Current EZOCore does not implement:

- LibGroupBroadcast transport.
- cross-player presence;
- peer/member registry;
- reset-state synchronization;
- remote commands or automatic travel;
- SavedVariables as a bus.

Future player-to-player features must be informational first, versioned,
capability-checked and validated separately.
