# Protocolo De Grupo De EZOCore

Estado: validacion beta del transporte. El protocol ID `511` es el espacio
oficial para pruebas locales. El custom event ID `39` es el espacio oficial
equivalente para eventos de prueba. Ambos deben sustituirse por registros
permanentes validos antes de una release publica.

EZOCore usa un unico protocolo de LibGroupBroadcast para presencia de
grupo de la familia EZO y mensajes pequenos de estado informativo. Los addons
funcionales de EZO siguen funcionando sin EZOCore y sin LibGroupBroadcast.

## IDs Beta

Registro oficial: https://wiki.esoui.com/LibGroupBroadcast_IDs

| Campo | Valor |
| --- | --- |
| Addon | EZOCore |
| Autor | @Zuriplayer |
| Nombre de protocolo | `EZO_CORE_GROUP_V2` |
| Protocol ID | `511` (ID temporal para pruebas beta locales) |
| Descripcion | Presencia de grupo de la familia EZO y estado informativo compacto de grupo, incluyendo actividad y estado opcional de rendimiento. |
| Nombre de custom event | `EZO_CORE_GROUP_REQUEST_V1` |
| Custom event ID | `39` (evento temporal para pruebas beta locales) |
| Descripcion del custom event | Solicita resincronizacion de presencia/estado EZO a miembros compatibles del grupo. |

## Forma Del Protocolo

Protocolo: `EZO_CORE_GROUP_V2`

Campo de primer nivel:

```text
VariantField:
  presence
  activityState
  performanceState
```

La variante `performanceState` es opcional. Los productores deben exponer opt-in
explícito y no deben enviarla con más frecuencia de la permitida por el throttle
del servicio EZOCore.

### `presence`

Lo envía EZOCore para anunciar addons de la familia EZO instalados, builds
numéricas y bits compactos de capacidades. Las claves numéricas estables evitan
reenviar nombres de addon y versiones visibles. Las comparaciones de
compatibilidad usan el `AddOnVersion` numérico, no la versión mostrada.

Mientras el jugador está en grupo y el transporte está activo, EZOCore renueva
la presencia cada 45 segundos. El heartbeat equivale a la mitad del TTL actual
de 90 segundos para peers.

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
| `capabilityMask` | máscara unsigned de 32 bits |

Las claves de addon desconocidas se ignoran. Un registro mal formado, una clave
conocida duplicada, una versión de protocolo no soportada, una secuencia antigua
o un emisor que ya no pertenece al grupo hacen que se rechace el mensaje de
presencia completo.
La secuencia se comprueba dentro de la misma sesión efímera del emisor, para que
un `/reloadui` pueda empezar una secuencia nueva sin esperar a que caduque el TTL
del peer anterior. Un cambio de sesión del emisor también limpia las secuencias
de actividad y rendimiento almacenadas para ese peer.

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
| `difficulty` | 0-3 |
| `sessionId` | 0-4294967295 |
| `progressCurrent` | 0-15 |
| `progressTotal` | 0-15 |
| `pendingCount` | 0-12 |
| `expectedCount` | 0-12 |
| `ttlSeconds` | 15-300 |
| `targetKey` | string, 0-32 |

Valores de enum aceptados en el protocolo v2:

| Campo | Valores |
| --- | --- |
| `activityType` | `0 unknown`, `1 trial`, `2 dungeon`, `3 arena` |
| `stage` | `0 idle`, `1 staging`, `2 returning`, `3 waitingMembers`, `4 complete`, `5 failed` |
| `result` | `0 unknown`, `1 active`, `2 complete`, `3 cancelled`, `4 failed`, `5 interrupted` |
| `difficulty` | `0 unknown`, `1 normal`, `2 veteran` |

El primer consumidor previsto es EZOTools. El receptor preparado solo acepta
estado de actividad del líder actual del grupo, después de que una presencia
válida de ese peer demuestre que el addon emisor expone
`group.activityState.provider`. También valida la secuencia, el TTL, los enums
conocidos y los límites del payload antes de disparar callbacks locales. Este
estado es solo informativo y nunca autoriza una acción remota.

EZOCore conserva el último estado de actividad validado hasta que caduca su TTL
y lo expone mediante `GetPeerActivityState(unitTag)`. Esto evita que los
consumidores que se registran después del callback inventen estados provisionales
mientras esperan una resincronización.

### `performanceState`

Reservado para pistas compactas de rendimiento/estado del jugador, por ejemplo
badges visuales en EZOGroupFrames. Es solo informativo.

| Campo | Rango / formato |
| --- | --- |
| `protocolVersion` | 1-15 |
| `sequence` | 1-65535, con control de desbordamiento |
| `sourceAddonKey` | clave estable de addon EZO, 1-63 |
| `pingMs` | 0-4095 |
| `fps` | 0-255 |
| `privacyState` | 0-7 |
| `ttlSeconds` | 15-300 |

Valores de privacidad aceptados en el protocolo v2:

| Valor | Significado |
| --- | --- |
| `0` | desconocido; las métricas se transmiten como cero |
| `1` | público/compartido |
| `2` | privado; las métricas se transmiten como cero |
| `3` | oculto; las métricas se transmiten como cero |

El receptor solo acepta estado de rendimiento después de que una presencia válida
de ese peer demuestre que el addon emisor expone
`group.performanceState.provider`. EZOCore expone
`PublishPerformanceState(...)` y limita la publicación a una vez cada 10 segundos
por clave de addon emisor. Solo el estado público transporta el ping y los FPS
indicados. Los demás estados permiten omitir las métricas y tanto el emisor como
el receptor las normalizan a cero.

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
| 18 | `group.performanceState.provider` |
| 19 | `group.performanceState.consumer` |

## Contrato Actual En Ejecucion

Las builds pueden seguir devolviendo estados normales de no disponibilidad como
`libGroupBroadcastMissing`, `transportNotInitialized`, `protocolDisabled`,
`requestEventDisabled` o `notGrouped`. Los consumidores deben tratarlos como
estados normales y evitar avisos no solicitados en chat.

La implementación usa únicamente las fábricas públicas de campos de
LibGroupBroadcast. El protocol ID `511` y el custom event ID `39` son espacios
temporales de prueba y deben sustituirse por registros permanentes válidos antes
de la release.

Presencia, actividad y rendimiento comparten un protocolo VariantField. Los
envíos no usan el reemplazo de mensajes en cola por protocolo de
LibGroupBroadcast, porque una variante nueva eliminaría otra variante distinta
en cola con el mismo ID. Presencia y rendimiento opcional se marcan como
relevantes en combate; actividad mantiene el comportamiento fuera de combate.

Métodos públicos productores de `family.groupPresence`:

- `PublishActivityState(state)`
- `PublishPerformanceState(state)`

Ayudas públicas para consumidores:

- `GetRemotePeer(unitTag)`
- `GetRemotePeers()`
- `GetPeerActivityState(unitTag)`
- `GetPeerPerformanceState(unitTag)`
