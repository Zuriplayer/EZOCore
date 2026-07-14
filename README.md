# EZOCore

Local service layer for EZO addons in *The Elder Scrolls Online*: addon registry, service discovery, capabilities, callbacks and diagnostics.

🇪🇸 Prefieres español? Lee el [README en español](README.es.md).

## Current phase

EZOCore is currently a **public beta** in a local-only service preview phase:

- It exposes a small local registry/service/callback API that runs entirely inside a single ESO client.
- It owns a central `Settings > EZO` menu for EZO-family addon settings, using EZO-standard informational section headers.
- It provides a shared EZO-family language mode: automatic, English, Spanish, or "let each addon choose"; standalone addons keep their own fallback when EZOCore is not installed or the central mode allows local choices.
- There is no active group sync and no communication between players yet. EZOCore can detect LibGroupBroadcast and expose a disabled `family.groupPresence` service, but sending stays blocked until official protocol IDs are reserved and the compact wire format is finalized.
- There is no remote automation triggered from inside the game; the GitHub Actions in this repo are manual, developer-triggered workflows for packaging and Discord status updates.
- Public beta means the repository is visible for review/testing, but the implemented feature set is still intentionally limited to local services.

## Does this addon do anything by itself?

Not much on its own. EZOCore is meant to be an optional shared dependency for other EZO addons (such as EZOTools or EZOGroupFrames). Those addons keep working perfectly without EZOCore installed; when it is present, they will be able to use `## OptionalDependsOn: EZOCore` to discover shared services instead of duplicating that logic.

## Settings panel

EZOCore owns the central `Settings > EZO` hub. Its left index combines addon navigation with enable/disable selectors: EZOCore remains checked and locked, while other installed EZO addons can be toggled and applied with the shared `Reload UI` button. Addons are grouped by their declared lifecycle stage, from stable and maintained work to beta and development builds; archived and unclassified states remain explicit. Each group uses the EZO purple information icon and keeps its explanation in the header tooltip. Disabled addons remain listed but cannot expose their settings until they are enabled and the UI reloads. Field-specific help remains on each setting control.

## Language preference

EZOCore stores one account-wide EZO-family language mode: automatic, English, Spanish, or "let each addon choose". Automatic, English and Spanish disable integrated addon language selectors and apply the central choice. "Let each addon choose" re-enables each addon's local selector. Addons installed without EZOCore must still expose their own local language fallback.

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
- `EZOCore:GetConfiguredLanguage()`
- `EZOCore:GetLanguage()`
- `EZOCore:GetClientLanguage()`
- `EZOCore:SetLanguage(language)`
- `EZOCore:IsSupportedLanguage(language)`
- `EZOCore:IsLanguageGloballyManaged()`
- `EZOCore:RegisterCallback(eventName, callback)`
- `EZOCore:UnregisterCallback(eventName, callback)`
- `EZOCore:FireCallback(eventName, ...)`

All of the above run locally in the current client. The global language preference is stored in EZOCore SavedVariables; addon registry, services and callbacks remain session-local and nothing is sent over the network.

Addons should register with stable lowercase EZO ids, visible version, numeric `AddOnVersion`, local API version and capabilities. EZOCore rejects invalid metadata without breaking the caller.

Consumer integration examples live in [docs/consumer-integration.md](docs/consumer-integration.md). The current implemented services are:

- `family.settings` API v1: central `Settings > EZO` registration, navigation and installed-addon load controls.
- `family.presence` API v1: local presence facade over registered EZO addons, versions and capabilities.
- `family.groupPresence` API v1: remote peer presence facade, currently disabled until LibGroupBroadcast IDs and the compact protocol are reserved/finalized.
- `family.language` API v1: shared local language preference for EZO-family addons.
- local addon/capability registry: local-only discovery for consumers such as EZOTools.

## Requirements

- The Elder Scrolls Online (PC)
- Optional: LibDebugLogger, DebugLogViewer (for diagnostics; EZOCore degrades gracefully without them)
- Optional: LibAddonMenu-2.0 (for rendering registered addon option controls in `Settings > EZO`)

## Installation

1. Download the latest version from Releases (or clone this repository).
2. Copy the `EZOCore` folder into your ESO AddOns folder: `Documents/Elder Scrolls Online/live/AddOns/`.
3. Enable the addon from the in-game Add-Ons screen.

## Roadmap (not implemented yet)

Future phases may activate cross-player presence through LibGroupBroadcast after official IDs are reserved. No peer data is sent by the current build.

## Support

📢 For support, feedback, bug reports or suggestions, join our Discord: https://discord.gg/ekw8zUAcRm

## License

MIT — see [LICENSE](LICENSE).

Developed and maintained by Zuriplayer.
