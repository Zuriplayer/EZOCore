# EZO Core Group Protocol

Status: IDs reserved on the official ESOUI LibGroupBroadcast registry. The
transport can register when LibGroupBroadcast is available and enabled.

EZOCore uses one LibGroupBroadcast protocol for EZO-family group presence
and small informational activity-state messages. Functional EZO addons continue
to work without EZOCore and without LibGroupBroadcast.

## Reserved IDs

Official registry: https://wiki.esoui.com/LibGroupBroadcast_IDs

| Field | Value |
| --- | --- |
| Addon | EZOCore |
| Author | @Zuriplayer |
| Protocol name | `EZO_CORE_GROUP_V1` |
| Protocol ID | `513` |
| Description | EZO family group presence and small informational activity state messages. |
| Custom event name | `EZO_CORE_GROUP_REQUEST_V1` |
| Custom event ID | `3` |
| Custom event description | Requests an EZO group presence/state resync from compatible group members. |

## Protocol Shape

Protocol: `EZO_CORE_GROUP_V1`

Top-level field:

```text
VariantField:
  presence
  activityState
```

### `presence`

Sent by EZOCore to announce installed EZO-family addons, numeric builds and
compact capability bits. Stable numeric addon keys avoid repeatedly sending
addon names and visible version strings. Compatibility comparisons use numeric
`AddOnVersion`, not the display version.

| Field | Range / format |
| --- | --- |
| `protocolVersion` | 1-15 |
| `sessionId` | ephemeral sender session, 0-16777215 |
| `sequence` | 1-65535, wrap-aware |
| `ttlSeconds` | 15-300 |
| `addons` | array, 0-16 records |

Addon record:

| Field | Range / format |
| --- | --- |
| `addonKey` | stable EZO addon key, 1-63 |
| `addOnVersion` | 0-1048575 |
| `apiVersion` | 0-255 |
| `capabilityMask` | 32-bit mask |

Unknown addon keys are ignored. A malformed record, a duplicate known key, an
unsupported protocol version, a stale sequence or a sender that is no longer a
current group unit causes the complete presence message to be rejected.
Sequence freshness is evaluated within the same ephemeral sender session so a
`/reloadui` can start a new sequence immediately without waiting for the old
peer TTL to expire.

### `activityState`

Reserved for small informational state such as EZOTools Group Activities. It is
not a remote-command channel.

| Field | Range / format |
| --- | --- |
| `protocolVersion` | 1-15 |
| `sequence` | 1-65535, wrap-aware |
| `sourceAddonKey` | stable EZO addon key, 1-63 |
| `activityType` | 0-15 |
| `stage` | 0-31 |
| `result` | 0-31 |
| `sessionId` | 0-4294967295 |
| `ttlSeconds` | 15-300 |
| `targetKey` | string, 0-32 |

Accepted enum values in protocol v1:

| Field | Values |
| --- | --- |
| `activityType` | `0 unknown`, `1 trial`, `2 dungeon`, `3 arena` |
| `stage` | `0 idle`, `1 staging`, `2 returning`, `3 waitingMembers`, `4 complete`, `5 failed` |
| `result` | `0 unknown`, `1 active`, `2 complete`, `3 cancelled`, `4 failed`, `5 interrupted` |

The first consumer is expected to be EZOTools. The prepared receiver accepts
activity state only from the current group leader, after a valid presence from
that peer proves that the source addon exposes
`group.activityState.provider`. It also validates sequence freshness, TTL,
known enum values and payload bounds before firing local callbacks. This is
informational state only and never authorizes a remote action.

## Stable Addon Keys

Keys are append-only and must never be reassigned to another addon.

| Key | Addon ID |
| --- | --- |
| 1 | `ezocore` |
| 2 | `ezoalerts` |
| 3 | `ezoauto` |
| 4 | `ezocamsens` |
| 5 | `ezochat` |
| 6 | `ezocombat` |
| 7 | `ezocursor` |
| 8 | `ezocustomsupporticons` |
| 9 | `ezogroupframes` |
| 10 | `ezohud` |
| 11 | `ezokeybinds` |
| 12 | `ezometter` |
| 13 | `ezopvp` |
| 14 | `ezota` |
| 15 | `ezotools` |

## Initial Capability Bits

Capability names remain the public local API. The bitmask is only the compact
wire representation.

| Bit | Capability |
| --- | --- |
| 1 | `family.presence` |
| 2 | `family.groupPresence` |
| 3 | `family.language` |
| 4 | `family.language.consumer` |
| 5 | `family.settings.consumer` |
| 6 | `family.debug` |
| 7 | `family.layout` |
| 8 | `group.activities` |
| 9 | `group.activityState.provider` |
| 10 | `group.activityState.consumer` |
| 11 | `group.frames.visualHints` |
| 12 | `alerts.screen` |
| 13 | `alerts.groupChat` |
| 14 | `automation.groupInvites` |
| 15 | `combat.metrics` |
| 16 | `hud.visualOverlay` |
| 17 | `pvp.travel` |

## Current Runtime Contract

Builds can still report normal unavailable states such as
`libGroupBroadcastMissing`, `transportNotInitialized`, `protocolDisabled`,
`requestEventDisabled` or `notGrouped`. Consumers must treat those as normal and
avoid unsolicited chat warnings.

The implementation uses only LibGroupBroadcast's public field factories. The
protocol and request event use the numeric IDs reserved in the official
registry.
