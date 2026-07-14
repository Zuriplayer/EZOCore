# Changelog

All notable changes to EZOCore are documented in this file.

## Unreleased

## [0.1.3] - 2026-07-14

### Fixed

- Loads the callback bus before presence services so service registration can fire callbacks without a startup error.

### Added

- Local `family.presence` service facade for registered EZO addons, versions and capabilities.
- Disabled `family.groupPresence` service facade with LibGroupBroadcast readiness/status checks and an ephemeral remote peer registry for the next protocol phase.

## [0.1.2] - 2026-07-14

### Added

- Lifecycle groups in `Settings > EZO`, ordered from mature addons to experimental work, with standard purple information tooltips and an explicit unclassified fallback.
- `panelData.ezoStage` support for consumer settings registration.
- Enable/disable selectors beside installed EZO addons in the native `Settings > EZO` navigation list.
- A shared `Reload UI` button for applying addon load changes without duplicating controls in the EZOCore panel.
- A fourth language mode, "let each addon choose", plus `EZOCore:IsLanguageGloballyManaged()` so integrated addons can disable or re-enable their local language selectors consistently.

### Fixed

- Resolves ESO's current `GetAddOnManager()` API before legacy manager globals, restoring installed-addon discovery and load controls.
- Keeps EZOCore permanently enabled and prevents installed but unloaded addons from opening unavailable settings.

## [0.1.1] - 2026-07-14

### Added

- Public beta repository metadata and README wording while keeping the implemented scope local-only.
- Consumer integration docs in English and Spanish for local registry, capabilities, services, callbacks and `Settings > EZO`.
- Repo-level `luacheck` configuration for ESO/EZOCore globals.
- Central `Settings > EZO` service and native settings entry for EZO-family addon panels.
- `EZOCore:RegisterSettingsPanel`, `EZOCore:GetSettingsPanels`, `EZOCore:OpenSettingsPanel`, `EZOCore:RefreshSettingsPanel`, and `EZOCore:OpenSettings`.
- Installed EZO addon status view with enable/disable controls, excluding EZOCore itself.
- EZO-standard purple informational section headers for EZOCore's own settings hub sections.
- Account-wide EZO-family language preference with `family.language` API v1 and `EZO_CORE_LANGUAGE_CHANGED`.

### Fixed

- Uses a real native `Settings > EZO` scene fragment instead of redirecting to LibAddonMenu's standard AddOns list.
- Adds the standard colored EZO panel header, author, version and permanent Discord feedback link.
- Keeps the LibAddonMenu hub registration only as a compatibility fallback when native settings registration is unavailable.
- Renders registered LibAddonMenu panels through a full LAM-compatible host in `Settings > EZO`.
- Caches each addon settings view after first use instead of recreating controls while navigating.
- Preserves LibAddonMenu half-width controls in their normal two-column layout inside the EZO host.

## [0.1.0] - 2026-07-13

### Added

- Initial local-only service preview: addon registry, service registry, callback bus and diagnostics helpers.
- `EZOCore:RegisterAddon`, `EZOCore:GetAddon`, `EZOCore:GetRegisteredAddons`.
- `EZOCore:HasAddon`, `EZOCore:HasCapability`.
- Local addon metadata validation for stable IDs, visible version, numeric `AddOnVersion`, API version and capabilities.
- EZOCore self-registration with the `family.presence` capability.
- `EZOCore:RegisterService`, `EZOCore:GetService`.
- `EZOCore:RegisterCallback`, `EZOCore:UnregisterCallback`, `EZOCore:FireCallback`.
- Optional LibDebugLogger-based diagnostics that degrade gracefully when the library is absent.
- Repository scaffolding: manifest, packaging config, bump-version helper, and manual Discord publishing workflows (status/beta/release), all defaulting to a dry run.
