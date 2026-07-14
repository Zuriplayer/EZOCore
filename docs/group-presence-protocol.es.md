# Protocolo De Grupo De EZOCore

Estado: preparacion para reserva de IDs. La build actual no activa trafico.

EZOCore usara un unico protocolo futuro de LibGroupBroadcast para presencia de
grupo de la familia EZO y mensajes pequenos de estado informativo. Los addons
funcionales de EZO siguen funcionando sin EZOCore y sin LibGroupBroadcast.

## Ficha De Reserva

Copia esto en el registro oficial de IDs de LibGroupBroadcast despues de elegir
IDs numericos libres:

| Campo | Valor |
| --- | --- |
| Addon | EZOCore |
| Autor | @Zuriplayer |
| Nombre de protocolo | `EZO_CORE_GROUP_V1` |
| Protocol ID | `TBD` |
| Descripcion | Presencia de grupo de la familia EZO y pequenos mensajes informativos de estado de actividad. |
| Nombre de custom event | `EZO_CORE_GROUP_REQUEST_V1` |
| Custom event ID | `TBD` |
| Descripcion del custom event | Solicita resincronizacion de presencia/estado EZO a miembros compatibles del grupo. |

No sustituyas `TBD` en el codigo hasta que los IDs esten reservados en la wiki
oficial de ESOUI. `modules/group_presence.lua` mantiene intencionadamente
`LGB_PROTOCOL_READY = false` hasta entonces.

## Forma Del Protocolo

Protocolo: `EZO_CORE_GROUP_V1`

Campo de primer nivel:

```text
VariantField:
  presence
  activityState
```

### `presence`

Lo envia EZOCore para anunciar addons de la familia EZO instalados y bits
compactos de capacidades.

| Campo | Rango / formato |
| --- | --- |
| `protocolVersion` | 1-15 |
| `sequence` | 0-65535 |
| `coreApiVersion` | 0-255 |
| `coreVersion` | string, 1-16 |
| `coreAddOnVersion` | 0-999999 |
| `ttlSeconds` | 15-300 |
| `addons` | array, 0-16 registros |

Registro de addon:

| Campo | Rango / formato |
| --- | --- |
| `id` | string, 3-32 |
| `version` | string, 1-16 |
| `addOnVersion` | 0-999999 |
| `apiVersion` | 0-255 |
| `capabilityMask` | mascara de 32 bits |

### `activityState`

Reservado para estado informativo pequeno, por ejemplo EZOTools Group
Activities. No es un canal de comandos remotos.

| Campo | Rango / formato |
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

El primer consumidor previsto es EZOTools. Los receptores deben validar
pertenencia actual al grupo, autoridad del lider cuando corresponda, frescura de
secuencia, TTL, enums conocidos y capacidades requeridas antes de mostrar el
estado.

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

Las builds actuales devuelven `protocolDefinitionPending` o
`reservedIdsMissing` y no envian datos de LibGroupBroadcast. Los consumidores
deben tratarlo como un estado normal y evitar avisos no solicitados en chat.
