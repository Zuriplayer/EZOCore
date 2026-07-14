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

## Query Group Presence Readiness

The `family.groupPresence` service is present before remote traffic is enabled.
It lets consumers check whether the transport is available and query remote peer
state once the protocol is activated:

```lua
local groupPresence = EZOCore and EZOCore:GetService("family.groupPresence", 1)
local status = groupPresence and groupPresence:GetStatus()
if status and status.active then
    local state = groupPresence:GetPeerCompatibility(
        "group1", "ezotools", "group.activities", 1, 10145)
end
```

The final two arguments are the minimum local API version and optional minimum
numeric `AddOnVersion`. Use the latter for build compatibility; do not compare
display-version strings.

Transport can still be unavailable when LibGroupBroadcast is missing, the user
has disabled the protocol, or the player is not grouped. Do not show
unsolicited warnings for those normal states.

When transport is enabled, compatibility is based on stable addon
IDs, numeric `AddOnVersion`, local API version and declared capability bits.
Unknown or expired peers must remain `unknown`; consumers must not infer that an
addon is absent until a valid presence for that current group member exists.

The reserved IDs and wire format are documented in
[group-presence-protocol.md](group-presence-protocol.md). The protocol is
`EZO_CORE_GROUP_V1` (`513`) and the resync custom event is
`EZO_CORE_GROUP_REQUEST_V1` (`3`).

## Use Shared Diagnostics

The `family.debug` service centralizes optional LibDebugLogger access without
making diagnostics a hard dependency:

```lua
local diagnostics = EZOCore and EZOCore:GetService("family.debug", 1)
if diagnostics then
    diagnostics:Debug("EZOTools", "Selected activity: %s", activityName)
end
```

Available methods are `Log(tag, level, message, ...)`, `Debug`, `Info`, `Warn`,
`Error`, `IsAvailable`, `IsViewerAvailable` and `ShowViewer`. Logging methods
return `false` without formatting or retaining the message when LibDebugLogger
is unavailable. Viewer methods also return `false` without printing to chat.

Functional addons must retain their standalone optional LibDebugLogger path
while EZOCore remains optional. Do not use `Error` for ordinary diagnostics;
reserve it for errors caught and suppressed by addon code.

## Register A Movable Surface

Use `family.layout` only for free-position HUD surfaces that already have a
standalone move mode:

```lua
local layout = EZOCore and EZOCore:GetService("family.layout", 1)
if layout then
    layout:RegisterSurface({
        id = "example.alert",
        addonId = "example",
        addonName = "Example",
        name = "Alert window",
        setEditMode = function(enabled)
            Example.SetMoveMode(enabled)
            return Example.IsMoveMode() == enabled
        end,
        isEditMode = Example.IsMoveMode,
    })
end
```

Movement state must remain session-only. The addon owns its preview, HUD/HUD_UI
visibility, position saving and local fallback when EZOCore is unavailable.
Do not register reticles, unit-attached markers, native ESO controls or Settings
panels.

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

- active group-presence transmission;
- cross-player presence;
- peer/member registry;
- reset-state synchronization;
- remote commands or automatic travel;
- SavedVariables as a bus.

Future player-to-player features must be informational first, versioned,
capability-checked and validated separately.
