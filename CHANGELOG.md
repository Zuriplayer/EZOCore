# Changelog

All notable changes to EZOCore are documented in this file.

## Unreleased

## [0.1.13] - 2026-07-15

### Fixed

- Added a grouped presence heartbeat at half the peer TTL so stable members do
  not disappear from the remote cache.
- Preserved queued presence, activity and performance variants independently
  instead of replacing every queued message sharing the protocol ID.
- Reset and expire activity/performance sequence guards across sender sessions
  and state TTL boundaries.
- Declared the capability mask as a true unsigned 32-bit field.
- Zeroed ping and FPS whenever performance privacy is not public.
- Isolated local-state subscriber payload copies and kept the clear helper
  internal to the service.

## [0.1.12] - 2026-07-15

### Added

- `family.localState` API v1 for session-only local state exchange between EZO
  addons loaded in the same client.
- Public `family.groupPresence:PublishActivityState(...)` and `PublishPerformanceState(...)` producer APIs.
- Optional `performanceState` protocol variant with ping, FPS and privacy status plus remote performance lookup helpers.
- Named, validated activity-state callbacks plus a local presence-request callback so providers can resynchronize current informational state without owning LibGroupBroadcast registrations.

## [0.1.11] - 2026-07-15

### Added

- Activated reserved LibGroupBroadcast IDs for `EZO_CORE_GROUP_V1` (`513`) and
  `EZO_CORE_GROUP_REQUEST_V1` (`3`).

### Changed

- Reworked the inactive `family.groupPresence` wire scaffold to use only public
  LibGroupBroadcast field factories and compact stable addon keys.
- Added strict validation for current group membership, protocol version,
  wrap-aware sequences, TTL, addon records and leader activity-state authority.
- Prunes cached remote peers when the current group roster changes.

## [0.1.10] - 2026-07-15

### Added

- Reserved-ID preparation docs and inactive wire-format scaffold for
  `EZO_CORE_GROUP_V1` / `EZO_CORE_GROUP_REQUEST_V1`.

## [0.1.9] - 2026-07-15

### Added

- Session-only `family.layout` API v1 for registering and coordinating movable EZO interface surfaces.
- Global and per-surface movement controls in `Settings > EZO`, with previews remaining restricted to HUD/HUD_UI.

## [0.1.8] - 2026-07-14

### Added

- Local `family.debug` API v1 for shared LibDebugLogger logging and safe DebugLogViewer access.
- No-op behavior with no chat output, buffers, timers or event handlers when the optional diagnostics backend is unavailable.

## [0.1.7] - 2026-07-14

### Changed

- Orders lifecycle groups by maturity and keeps Archived addons at the end of the EZO settings list.

### Fixed

- Opens the native `Settings > EZO` node reliably by consuming the tree node list returned by `GetChildren()` directly, so integrated addons can land on their requested EZO settings view.

## [0.1.6] - 2026-07-14

### Fixed

- Skips non-tree controls while selecting the native `Settings > EZO` node, preventing a startup error on ESO clients where menu children do not all expose `GetData()`.

## [0.1.5] - 2026-07-14

### Added

- New Development and Unclassified EZO addons default to disabled on first detection.
- Existing addon states are preserved when migrating to the policy, and later manual choices remain authoritative.

## [0.1.4] - 2026-07-14

### Changed

- Applied the EZO purple-Z branding to the native Settings menu entry.

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
