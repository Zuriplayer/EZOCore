# EZO Core Group Protocol

Status: beta transport validation. Protocol ID `511` is the official local-test
slot. Custom event ID `39` is the equivalent official test slot. Both must be
replaced by valid permanent registrations before public release.

EZOCore uses one LibGroupBroadcast protocol for EZO-family group presence
and small informational activity-state or alert messages. Functional EZO addons continue
to work without EZOCore and without LibGroupBroadcast.

## Beta IDs

Official registry: https://wiki.esoui.com/LibGroupBroadcast_IDs

| Field | Value |
| --- | --- |
| Addon | EZOCore |
| Author | @Zuriplayer |
| Protocol name | `EZO_CORE_GROUP_V2` |
| Protocol ID | `511` (temporary local beta test ID) |
| Description | EZO family group presence and compact informational group state, including activity, alert and optional performance status. |
| Custom event name | `EZO_CORE_GROUP_REQUEST_V1` |
| Custom event ID | `39` (temporary local beta test event) |
| Custom event description | Requests an EZO group presence/state resync from compatible group members. |

## Protocol Shape

Protocol: `EZO_CORE_GROUP_V2`

Top-level field:

```text
VariantField:
  presence
  activityState
  performanceState
  alertEvent
```

The `performanceState` variant is optional. Producers must expose an explicit
opt-in and must not send it more often than the EZOCore service throttle allows.

### `presence`

Sent by EZOCore to announce installed EZO-family addons, numeric builds and
compact capability bits. Stable numeric addon keys avoid repeatedly sending
addon names and visible version strings. Compatibility comparisons use numeric
`AddOnVersion`, not the display version.

While grouped and the transport is active, EZOCore renews presence every 45
seconds. The heartbeat is half the current 90-second peer TTL.

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
| `capabilityMask` | unsigned 32-bit mask |

Unknown addon keys are ignored. A malformed record, a duplicate known key, an
unsupported protocol version, a stale sequence or a sender that is no longer a
current group unit causes the complete presence message to be rejected.
Sequence freshness is evaluated within the same ephemeral sender session so a
`/reloadui` can start a new sequence immediately without waiting for the old
peer TTL to expire. A sender-session change also clears cached activity and
performance sequence guards for that peer.

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
| `difficulty` | 0-3 |
| `sessionId` | 0-4294967295 |
| `progressCurrent` | 0-15 |
| `progressTotal` | 0-15 |
| `pendingCount` | 0-12 |
| `expectedCount` | 0-12 |
| `ttlSeconds` | 15-300 |
| `targetKey` | string, 0-32 |

Accepted enum values in protocol v2:

| Field | Values |
| --- | --- |
| `activityType` | `0 unknown`, `1 trial`, `2 dungeon`, `3 arena` |
| `stage` | `0 idle`, `1 staging`, `2 returning`, `3 waitingMembers`, `4 complete`, `5 failed` |
| `result` | `0 unknown`, `1 active`, `2 complete`, `3 cancelled`, `4 failed`, `5 interrupted` |
| `difficulty` | `0 unknown`, `1 normal`, `2 veteran` |

The first consumer is expected to be EZOTools. The prepared receiver accepts
activity state only from the current group leader, after a valid presence from
that peer proves that the source addon exposes
`group.activityState.provider`. It also validates sequence freshness, TTL,
known enum values and payload bounds before firing local callbacks. This is
informational state only and never authorizes a remote action.

EZOCore retains the last validated activity state until its TTL expires and
exposes it through `GetPeerActivityState(unitTag)`. This prevents consumers
that register after the callback from inventing fallback state while waiting
for a resynchronization.

### `performanceState`

Reserved for compact player performance/status hints such as EZOGroupFrames
display badges. It is informational only.

| Field | Range / format |
| --- | --- |
| `protocolVersion` | 1-15 |
| `sequence` | 1-65535, wrap-aware |
| `sourceAddonKey` | stable EZO addon key, 1-63 |
| `pingMs` | 0-4095 |
| `fps` | 0-255 |
| `privacyState` | 0-7 |
| `ttlSeconds` | 15-300 |

Accepted privacy values in protocol v2:

| Value | Meaning |
| --- | --- |
| `0` | unknown; metrics are transmitted as zero |
| `1` | public/shared |
| `2` | private; metrics are transmitted as zero |
| `3` | hidden; metrics are transmitted as zero |

The receiver accepts performance state only after a valid presence from that
peer proves that the source addon exposes `group.performanceState.provider`.
EZOCore exposes `PublishPerformanceState(...)` and throttles publication to at
most once every 10 seconds per source addon key. Only the public state carries
the supplied ping and FPS. Other privacy states accept omitted metrics and both
the sender and receiver normalize them to zero. Non-public states bypass the
public-metric throttle so a producer can promptly replace shared metrics with a
`hidden` withdrawal when the user disables its opt-in. Repeated identical
non-public states are throttled independently, and they do not reset the public
publication timestamp.

A structurally valid performance sample may arrive before the sender's larger
presence payload. EZOCore holds at most the newest such sample per unit tag for
15 seconds and exposes it only after a valid presence proves the provider
capability. It is discarded if that validation does not arrive in time.

### `alertEvent`

Reserved for short structured EZO-family alert events such as EZOAlerts chest
and heavy-sack notices. It is informational only and is not free chat text.

| Field | Range / format |
| --- | --- |
| `protocolVersion` | 1-15 |
| `sequence` | 1-65535, wrap-aware |
| `sourceAddonKey` | stable EZO addon key, 1-63 |
| `eventType` | 0-15 |
| `quality` | 0-15 |
| `ttlSeconds` | 15-60 |
| `actorName` | string, 0-40 |

Accepted event types in protocol v2:

| Value | Meaning |
| --- | --- |
| `0` | unknown |
| `1` | chest |
| `2` | heavySack |

Accepted quality values in protocol v2:

| Value | Meaning |
| --- | --- |
| `0` | unknown |
| `1` | simple |
| `2` | intermediate |
| `3` | advanced |
| `4` | master |
| `5` | impossible |

The receiver validates sender unit, protocol version, sequence, TTL, event type,
quality, source addon key and actor name length. If compatible peer presence is
already known, the source addon must expose `alerts.groupEvent.provider`.
Validated events fire `EZO_CORE_GROUP_ALERT_EVENT_RECEIVED` and
`EZOCore:GroupAlertEventReceived`. EZOCore does not localize or render the
alert; the receiving addon owns visibility, text and UI behavior.

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
| 18 | `group.performanceState.provider` |
| 19 | `group.performanceState.consumer` |
| 20 | `alerts.groupEvent.provider` |
| 21 | `alerts.groupEvent.consumer` |

## Current Runtime Contract

Builds can still report normal unavailable states such as
`libGroupBroadcastMissing`, `transportNotInitialized`, `protocolDisabled`,
`requestEventDisabled` or `notGrouped`. Consumers must treat those as normal and
avoid unsolicited chat warnings.

The implementation uses only LibGroupBroadcast's public field factories.
Protocol ID `511` and custom event ID `39` are temporary test slots and must be
replaced by valid permanent registrations before release.

Presence, activity, performance and alert events share one VariantField protocol. Sends do
not use LibGroupBroadcast's protocol-wide queued-message replacement because a
new variant would otherwise delete a different queued variant with the same
protocol ID. Presence and optional performance messages are marked relevant in
combat; activity messages retain the non-combat default; alert events are marked
relevant in combat so short loot-related notices are not delayed.

Public `family.groupPresence` producer methods:

- `PublishActivityState(state)`
- `PublishPerformanceState(state)`
- `PublishAlertEvent(state)`

Public consumer helpers:

- `GetRemotePeer(unitTag)`
- `GetRemotePeers()`
- `GetPeerActivityState(unitTag)`
- `GetPeerPerformanceState(unitTag)`
