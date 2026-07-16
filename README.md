# EZOCore

Local service layer for EZO addons in *The Elder Scrolls Online*: addon registry, service discovery, capabilities, callbacks and diagnostics.

🇪🇸 Prefieres español? Lee el [README en español](README.es.md).

## Current phase

EZOCore is currently a **public beta** shared-service layer:

- It exposes a small local registry/service/callback API that runs entirely inside a single ESO client.
- It owns a central `Settings > EZO` menu for EZO-family addon settings, using EZO-standard informational section headers.
- It provides a shared EZO-family language mode: automatic, English, Spanish, or "let each addon choose"; standalone addons keep their own fallback when EZOCore is not installed or the central mode allows local choices.
- It coordinates temporary global and per-window movement modes for EZO addons that register compatible HUD surfaces; previews remain hidden in Settings and appear after returning to the main HUD.
- It owns the only EZO-family LibGroupBroadcast transport: `EZO_CORE_GROUP_V2` (temporary beta test ID `511`) and `EZO_CORE_GROUP_REQUEST_V1` (temporary beta test event `39`). While grouped, clients with EZOCore and an enabled LibGroupBroadcast protocol can exchange compact addon presence, numeric builds, capabilities, activity state and optional performance status. See [docs/group-presence-protocol.md](docs/group-presence-protocol.md).
- There is no remote automation triggered from inside the game; the GitHub Actions in this repo are manual, developer-triggered workflows for packaging and Discord status updates.
- Public beta means the repository is visible for review/testing and the group-presence transport still requires multi-client testing before other addons depend on it for player-facing behavior.

## Does this addon do anything by itself?

Not much on its own. EZOCore is meant to be an optional shared dependency for other EZO addons (such as EZOTools or EZOGroupFrames). Those addons keep working perfectly without EZOCore installed; when it is present, they will be able to use `## OptionalDependsOn: EZOCore` to discover shared services instead of duplicating that logic.

## Settings panel

EZOCore owns the central `Settings > EZO` hub. The native Settings entry uses the EZO family branding with its purple Z. Programmatic openings from an integrated addon select that addon's own EZO settings view directly. Its left index combines addon navigation with enable/disable selectors: EZOCore remains checked and locked, while other installed EZO addons can be toggled and applied with the shared `Reload UI` button. Addons are grouped by their declared lifecycle stage in maturity order: Stable, Maintenance, Beta, Development, Unclassified and Archived. Archived addons therefore remain visible at the end of the list. Newly discovered Development and Unclassified addons start disabled and require reload before their already loaded code is removed; enabling one manually is remembered and is not overridden later. The first upgrade to this policy preserves all currently installed addon states. Each group uses the EZO purple information icon and keeps its explanation in the header tooltip. Disabled addons remain listed but cannot expose their settings until they are enabled and the UI reloads. Field-specific help remains on each setting control.

The Interface layout section can unlock every registered EZO surface at once or one surface at a time. Close Settings to see and arrange the previews in HUD/HUD_UI, then return to the same section to disable movement. Edit state is never persisted; each consumer addon continues to own its position, scale and standalone movement control.

## Language preference

EZOCore stores one account-wide EZO-family language mode: automatic, English, Spanish, or "let each addon choose". Automatic, English and Spanish disable integrated addon language selectors and apply the central choice. "Let each addon choose" re-enables each addon's local selector. Addons installed without EZOCore must still expose their own local language fallback.

## API

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

The registry, local state, settings, language, layout, diagnostics and callback APIs run locally in the current client. The global language preference and first-seen addon policy are stored in EZOCore SavedVariables. Only `family.groupPresence` uses LibGroupBroadcast, and only while grouped and permitted by the library's user settings.

Addons should register with stable lowercase EZO ids, visible version, numeric `AddOnVersion`, local API version and capabilities. EZOCore rejects invalid metadata without breaking the caller.

Consumer integration examples live in [docs/consumer-integration.md](docs/consumer-integration.md). The current implemented services are:

- `family.settings` API v1: central `Settings > EZO` registration, navigation and installed-addon load controls.
- `family.presence` API v1: local presence facade over registered EZO addons, versions and capabilities.
- `family.localState` API v1: session-only local state exchange between EZO addons in the same client.
- `family.groupPresence` API v1: remote peer presence facade using LibGroupBroadcast protocol `EZO_CORE_GROUP_V2` (temporary beta test ID `511`) and request event `EZO_CORE_GROUP_REQUEST_V1` (temporary beta test event `39`). It caches validated activity state until TTL expiry for late-opening consumers.
- `family.language` API v1: shared local language preference for EZO-family addons.
- `family.debug` API v1: optional shared LibDebugLogger and DebugLogViewer access with no chat fallback or runtime work when the backend is unavailable.
- `family.layout` API v1: session-only registration plus global and individual movement coordination for compatible EZO HUD surfaces.
- local addon/capability registry: local-only discovery for consumers such as EZOTools.

The `family.groupPresence` service exposes readiness/specification
queries, remote peer/addon lookups, capability/build compatibility checks,
presence announcement, activity/performance publication, remote performance
lookup and resync requests. Announcement and request methods return a reason
without sending when the transport, group or corresponding LibGroupBroadcast
user setting is unavailable. Active grouped clients renew presence every 45
seconds; non-public performance states never expose ping or FPS values.

## Requirements

- The Elder Scrolls Online (PC)
- Optional: LibDebugLogger, DebugLogViewer (for diagnostics; EZOCore degrades gracefully without them)
- Optional: LibAddonMenu-2.0 (for rendering registered addon option controls in `Settings > EZO`)
- Optional: LibGroupBroadcast 2.0.0 (required only for cross-player EZO group presence; all local EZOCore services continue without it)

## Installation

1. Download the latest version from Releases (or clone this repository).
2. Copy the `EZOCore` folder into your ESO AddOns folder: `Documents/Elder Scrolls Online/live/AddOns/`.
3. Enable the addon from the in-game Add-Ons screen.

## Roadmap (not implemented yet)

EZOTools can publish and display compact Group Activities state through this service. Its consumer may optionally react locally by requesting one trip to the current leader after the player has manually accepted the group invitation; EZOCore still exposes information only and never executes the trip. Future phases may connect EZOGroupFrames. Informational activity and performance state do not grant remote travel, invitation, group-change or automation authority.

## Support

📢 For support, feedback, bug reports or suggestions, join our Discord: https://discord.gg/ekw8zUAcRm

## License

MIT — see [LICENSE](LICENSE).

Developed and maintained by Zuriplayer.
