# Changelog

All notable changes to EZOCore are documented in this file.

## Unreleased

### Added

- Public beta repository metadata and README wording while keeping the implemented scope local-only.
- Consumer integration docs in English and Spanish for local registry, capabilities, services, callbacks and `Settings > EZO`.
- Repo-level `luacheck` configuration for ESO/EZOCore globals.
- Central `Settings > EZO` service and native settings entry for EZO-family addon panels.
- `EZOCore:RegisterSettingsPanel`, `EZOCore:GetSettingsPanels`, `EZOCore:OpenSettingsPanel`, `EZOCore:RefreshSettingsPanel`, and `EZOCore:OpenSettings`.
- Installed EZO addon status view with enable/disable controls, excluding EZOCore itself.

### Fixed

- Uses a real native `Settings > EZO` scene fragment instead of redirecting to LibAddonMenu's standard AddOns list.
- Adds the standard colored EZO panel header, author, version and permanent Discord feedback link.
- Keeps the LibAddonMenu hub registration only as a compatibility fallback when native settings registration is unavailable.
- Renders registered LibAddonMenu panels through a full LAM-compatible host in `Settings > EZO`.
- Caches each addon settings view after first use instead of recreating controls while navigating.

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
