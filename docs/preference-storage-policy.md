# EZO Preference Storage Policy

EZOCore owns the shared policy for ordinary EZO addon preferences. The policy is
stored account-wide in `EZOCoreSavedVariables` so every character sees the same
family decision.

## Default Scope

The default scope is `character`. Integrated addons can use
`EZOCore:GetPreferenceScope(addonId, preferenceKey)` to decide whether a
preference should be loaded from character or account storage.

## Always Account-Wide

These addons are global-only and must remain account-wide even when the default
scope is `character`:

| Addon | Reason |
| --- | --- |
| EZORaidPlanner | Raid planning data is shared account/family state. |
| EZOTools | Tool data and module state are account/family state. |
| EZOTest | Test state remains account-wide; the addon is not integrated in EZOCore yet. |

These individual preferences are also global-only:

| Addon | Preference key | Reason |
| --- | --- | --- |
| EZOCore | `language` | Shared family language policy. |
| EZOCore | `preferences.defaultScope` | The storage policy itself must be common. |
| EZOCore | `settings.addonLifecycleDefaults` | Installed-addon lifecycle policy is not character-specific. |
| EZOcamsens | `meta.settingsScope` | Storage-scope metadata controls where the addon loads settings. |
| EZOChat | `history.messages` | Chat history is a shared account log. |

## Current Exclusions

These addons are intentionally outside this migration pass:

| Addon | Decision |
| --- | --- |
| EZOChat | Leave unchanged for now except for known global-only history policy. |
| EZOTakingAim / EZOta | Ignore for now. |
| EZOAuto | Keep character-specific. |
| EZOMetter | Keep character-specific. |

## Migration Direction

Addons should migrate gradually. HUD positions, camera/combat preferences and
character role behavior should generally follow the default scope. Shared
planning data, account routing data, central language/policy and long-lived
history should remain account-wide.

The policy does not move data by itself. Each consumer addon must migrate its
own SavedVariables and preserve old account-wide data until `/reloadui` and
multi-character checks confirm the result.
