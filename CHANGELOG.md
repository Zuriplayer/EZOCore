# Changelog

All notable changes to EZOCore are documented in this file.

## Unreleased

### Added

- Consumer integration docs in English and Spanish for local registry, capabilities, services, callbacks and `Settings > EZO`.
- Repo-level `luacheck` configuration for ESO/EZOCore globals.
- Central `Settings > EZO` service and native settings entry for EZO-family addon panels.
- `EZOCore:RegisterSettingsPanel`, `EZOCore:GetSettingsPanels`, `EZOCore:OpenSettingsPanel`, `EZOCore:RefreshSettingsPanel`, and `EZOCore:OpenSettings`.
- Installed EZO addon status view with enable/disable controls, excluding EZOCore itself.

### Fixed

- Renders registered LibAddonMenu panels through a full LAM-compatible host in `Settings > EZO`.
- Keeps the native `Settings > EZO` entry visible even if ESO's keyboard options panel switch rejects the custom panel id.
- Opens a LibAddonMenu-backed central `EZO` hub from the native `Settings > EZO` entry, avoiding the empty custom panel path.

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
