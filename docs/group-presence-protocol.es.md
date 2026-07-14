# Protocolo De Grupo De EZOCore

Estado: IDs reservados en el registro oficial de LibGroupBroadcast de ESOUI. El
transporte puede registrarse cuando LibGroupBroadcast esta disponible y activo.

EZOCore usa un unico protocolo de LibGroupBroadcast para presencia de
grupo de la familia EZO y mensajes pequenos de estado informativo. Los addons
funcionales de EZO siguen funcionando sin EZOCore y sin LibGroupBroadcast.

## IDs Reservados

Registro oficial: https://wiki.esoui.com/LibGroupBroadcast_IDs

| Campo | Valor |
| --- | --- |
| Addon | EZOCore |
| Autor | @Zuriplayer |
| Nombre de protocolo | `EZO_CORE_GROUP_V1` |
| Protocol ID | `513` |
| Descripcion | Presencia de grupo de la familia EZO y pequenos mensajes informativos de estado de actividad. |
| Nombre de custom event | `EZO_CORE_GROUP_REQUEST_V1` |
| Custom event ID | `3` |
| Descripcion del custom event | Solicita resincronizacion de presencia/estado EZO a miembros compatibles del grupo. |

## Forma Del Protocolo

Protocolo: `EZO_CORE_GROUP_V1`

Campo de primer nivel:

```text
VariantField:
  presence
  activityState
```

### `presence`

Lo envía EZOCore para anunciar addons de la familia EZO instalados, builds
numéricas y bits compactos de capacidades. Las claves numéricas estables evitan
reenviar nombres de addon y versiones visibles. Las comparaciones de
compatibilidad usan el `AddOnVersion` numérico, no la versión mostrada.

| Campo | Rango / formato |
| --- | --- |
| `protocolVersion` | 1-15 |
| `sessionId` | sesión efímera del emisor, 0-16777215 |
| `sequence` | 1-65535, con control de desbordamiento |
| `ttlSeconds` | 15-300 |
| `addons` | array, 0-16 registros |

Registro de addon:

| Campo | Rango / formato |
| --- | --- |
| `addonKey` | clave estable de addon EZO, 1-63 |
| `addOnVersion` | 0-1048575 |
| `apiVersion` | 0-255 |
| `capabilityMask` | mascara de 32 bits |

Las claves de addon desconocidas se ignoran. Un registro mal formado, una clave
conocida duplicada, una versión de protocolo no soportada, una secuencia antigua
o un emisor que ya no pertenece al grupo hacen que se rechace el mensaje de
presencia completo.
La secuencia se comprueba dentro de la misma sesión efímera del emisor, para que
un `/reloadui` pueda empezar una secuencia nueva sin esperar a que caduque el TTL
del peer anterior.

### `activityState`

Reservado para estado informativo pequeno, por ejemplo EZOTools Group
Activities. No es un canal de comandos remotos.

| Campo | Rango / formato |
| --- | --- |
| `protocolVersion` | 1-15 |
| `sequence` | 1-65535, con control de desbordamiento |
| `sourceAddonKey` | clave estable de addon EZO, 1-63 |
| `activityType` | 0-15 |
| `stage` | 0-31 |
| `result` | 0-31 |
| `sessionId` | 0-4294967295 |
| `ttlSeconds` | 15-300 |
| `targetKey` | string, 0-32 |

Valores de enum aceptados en el protocolo v1:

| Campo | Valores |
| --- | --- |
| `activityType` | `0 unknown`, `1 trial`, `2 dungeon`, `3 arena` |
| `stage` | `0 idle`, `1 staging`, `2 returning`, `3 waitingMembers`, `4 complete`, `5 failed` |
| `result` | `0 unknown`, `1 active`, `2 complete`, `3 cancelled`, `4 failed`, `5 interrupted` |

El primer consumidor previsto es EZOTools. El receptor preparado solo acepta
estado de actividad del líder actual del grupo, después de que una presencia
válida de ese peer demuestre que el addon emisor expone
`group.activityState.provider`. También valida la secuencia, el TTL, los enums
conocidos y los límites del payload antes de disparar callbacks locales. Este
estado es solo informativo y nunca autoriza una acción remota.

## Claves Estables De Addons

Las claves solo se pueden ampliar y nunca deben reasignarse a otro addon.

| Clave | ID de addon |
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

## Bits Iniciales De Capacidades

Los nombres de capacidad siguen siendo la API local publica. La mascara de bits
solo es la representacion compacta por red.

| Bit | Capacidad |
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

## Contrato Actual En Ejecucion

Las builds pueden seguir devolviendo estados normales de no disponibilidad como
`libGroupBroadcastMissing`, `transportNotInitialized`, `protocolDisabled`,
`requestEventDisabled` o `notGrouped`. Los consumidores deben tratarlos como
estados normales y evitar avisos no solicitados en chat.

La implementación usa únicamente las fábricas públicas de campos de
LibGroupBroadcast. El protocolo y el evento de solicitud usan los IDs numéricos
reservados en el registro oficial.
