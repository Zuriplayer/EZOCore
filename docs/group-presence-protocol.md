# EZO Core Group Protocol

Status: reserved-ID preparation. No traffic is enabled in the current build.

EZOCore uses one future LibGroupBroadcast protocol for EZO-family group presence
and small informational activity-state messages. Functional EZO addons continue
to work without EZOCore and without LibGroupBroadcast.

## Reservation Draft

Copy this into the official LibGroupBroadcast ID registry after choosing free
numeric IDs:

| Field | Value |
| --- | --- |
| Addon | EZOCore |
| Author | @Zuriplayer |
| Protocol name | `EZO_CORE_GROUP_V1` |
| Protocol ID | `TBD` |
| Description | EZO family group presence and small informational activity state messages. |
| Custom event name | `EZO_CORE_GROUP_REQUEST_V1` |
| Custom event ID | `TBD` |
| Custom event description | Requests an EZO group presence/state resync from compatible group members. |

Do not replace `TBD` in code until the IDs are reserved on the official ESOUI
wiki. `modules/group_presence.lua` intentionally keeps `LGB_PROTOCOL_READY =
false` until then.

## Protocol Shape

Protocol: `EZO_CORE_GROUP_V1`

Top-level field:

```text
VariantField:
  presence
  activityState
```

### `presence`

Sent by EZOCore to announce installed EZO-family addons and compact capability
bits.

| Field | Range / format |
| --- | --- |
| `protocolVersion` | 1-15 |
| `sequence` | 0-65535 |
| `coreApiVersion` | 0-255 |
| `coreVersion` | string, 1-16 |
| `coreAddOnVersion` | 0-999999 |
| `ttlSeconds` | 15-300 |
| `addons` | array, 0-16 records |

Addon record:

| Field | Range / format |
| --- | --- |
| `id` | string, 3-32 |
| `version` | string, 1-16 |
| `addOnVersion` | 0-999999 |
| `apiVersion` | 0-255 |
| `capabilityMask` | 32-bit mask |

### `activityState`

Reserved for small informational state such as EZOTools Group Activities. It is
not a remote-command channel.

| Field | Range / format |
| --- | --- |
| `protocolVersion` | 1-15 |
| `sequence` | 0-65535 |
| `sourceAddonKey` | 0-255 |
| `activityType` | 0-15 |
| `stage` | 0-31 |
| `result` | 0-31 |
| `sessionId` | 0-4294967295 |
| `ttlSeconds` | 15-300 |
| `targetKey` | string, 0-32 |

The first consumer is expected to be EZOTools. Receivers must validate current
group membership, leader authority when relevant, sequence freshness, TTL,
known enum values and required capabilities before displaying the state.

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

Current builds return `protocolDefinitionPending` or `reservedIdsMissing` and
do not send LibGroupBroadcast data. Consumers must treat that as normal and
avoid unsolicited chat warnings.
