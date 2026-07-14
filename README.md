# EZOCore

Local service layer for EZO addons in *The Elder Scrolls Online*: addon registry, service discovery, capabilities, callbacks and diagnostics.

🇪🇸 Prefieres español? Lee el [README en español](README.es.md).

## Current phase

EZOCore is currently in a **local-only service preview** phase:

- It exposes a small local registry/service/callback API that runs entirely inside a single ESO client.
- It owns a central `Settings > EZO` menu for EZO-family addon settings.
- There is no group sync, no LibGroupBroadcast usage, and no communication between players yet.
- There is no remote automation triggered from inside the game; the GitHub Actions in this repo are manual, developer-triggered workflows for packaging and Discord status updates.

## Does this addon do anything by itself?

Not much on its own. EZOCore is meant to be an optional shared dependency for other EZO addons (such as EZOTools or EZOGroupFrames). Those addons keep working perfectly without EZOCore installed; when it is present, they will be able to use `## OptionalDependsOn: EZOCore` to discover shared services instead of duplicating that logic.

## API (local phase)

- `EZOCore:RegisterAddon(metadata)`
- `EZOCore:GetAddon(addonId)`
- `EZOCore:GetRegisteredAddons()`
- `EZOCore:HasAddon(addonId, minimumApiVersion)`
- `EZOCore:HasCapability(addonId, capability, minimumApiVersion)`
- `EZOCore:RegisterService(name, apiVersion, service)`
- `EZOCore:GetService(name, minimumApiVersion)`
- `EZOCore:RegisterSettingsPanel(addonId, panelId, panelData, options)`
- `EZOCore:GetSettingsPanels()`
- `EZOCore:OpenSettingsPanel(addonId)`
- `EZOCore:RefreshSettingsPanel()`
- `EZOCore:OpenSettings()`
- `EZOCore:RegisterCallback(eventName, callback)`
- `EZOCore:UnregisterCallback(eventName, callback)`
- `EZOCore:FireCallback(eventName, ...)`

All of the above run locally in memory. Nothing is persisted to SavedVariables and nothing is sent over the network.

Addons should register with stable lowercase EZO ids, visible version, numeric `AddOnVersion`, local API version and capabilities. EZOCore rejects invalid metadata without breaking the caller.

## Requirements

- The Elder Scrolls Online (PC)
- Optional: LibDebugLogger, DebugLogViewer (for diagnostics; EZOCore degrades gracefully without them)
- Optional: LibAddonMenu-2.0 (for rendering registered addon option controls in `Settings > EZO`)

## Installation

1. Download the latest version from Releases (or clone this repository).
2. Copy the `EZOCore` folder into your ESO AddOns folder: `Documents/Elder Scrolls Online/live/AddOns/`.
3. Enable the addon from the in-game Add-Ons screen.

## Roadmap (not implemented yet)

Future phases may add cross-player presence and messaging through LibGroupBroadcast. That work has not started and nothing in this repository implements it yet; this README will be updated when it does.

## Support

📢 For support, feedback, bug reports or suggestions, join our Discord: https://discord.gg/ekw8zUAcRm

## License

MIT — see [LICENSE](LICENSE).

Developed and maintained by Zuriplayer.
