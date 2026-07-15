# Integracion De Consumidores Con EZOCore

Este documento describe la superficie de integracion local actual para addons
EZO. Solo cubre funcionalidad implementada ahora en EZOCore: registro local de
addons, estado local, descubrimiento de servicios, capacidades, callbacks y el servicio
central `Settings > EZO`.

## Alcance

EZOCore es infraestructura opcional. Los addons funcionales deben seguir
funcionando cuando no esta instalado.

Usa:

```text
## OptionalDependsOn: EZOCore
```

No uses `DependsOn: EZOCore` salvo que el addon realmente no pueda cargar sin
el. No anadas dependencias directas entre dos addons EZO funcionales.

## Registrar Un Addon

Registra durante la inicializacion del addon, cuando tanto el consumidor como
EZOCore hayan cargado:

```lua
if EZOCore and type(EZOCore.RegisterAddon) == "function" then
    EZOCore:RegisterAddon({
        id = "ezotools",
        name = "EZOTools",
        version = EZOTools.ADDON_VERSION,
        addOnVersion = EZOTools.ADDON_VERSION_NUMERIC,
        apiVersion = 1,
        capabilities = {
            "group.activities",
            "group.activityState.provider",
            "group.activityState.consumer",
        },
    })
end
```

Reglas:

- `id` debe ser estable, en minusculas y seguro para busquedas.
- `version` es la version SemVer visible.
- `addOnVersion` es el `## AddOnVersion` numerico de ESO.
- `apiVersion` es la version del contrato local expuesto por ese addon.
- `capabilities` debe describir comportamiento concreto soportado, no nombres
  vagos de addon.

EZOCore rechaza metadata invalida e IDs duplicados sin romper al llamador.

## Consultar Capacidades

Usa comprobaciones de capacidad en vez de asumir detalles de addons hermanos:

```lua
if EZOCore and EZOCore:HasCapability("ezotools", "group.activities", 1) then
    -- Hay un registro local compatible de EZOTools.
end
```

`HasAddon(addonId, minimumApiVersion)` comprueba solo el registro del addon.
`HasCapability(addonId, capability, minimumApiVersion)` comprueba registro,
compatibilidad de API y una capacidad concreta.

## Consultar Presencia Local

El servicio `family.presence` expone los mismos datos de registro local mediante
una fachada de servicio sobre la que se podra construir la presencia remota
posterior:

```lua
local presence = EZOCore and EZOCore:GetService("family.presence", 1)
if presence and presence:HasLocalCapability("ezotools", "group.activities", 1) then
    local ezotools = presence:GetLocalAddon("ezotools")
    -- Inspeccionar ezotools.version, ezotools.addOnVersion, ezotools.capabilities.
end
```

`GetLocalAddons()` devuelve solo el cliente actual. No implica nada sobre los
miembros del grupo y no envia trafico por LibGroupBroadcast.

## Intercambiar Estado Local

Usa `family.localState` para datos de sesion compartidos entre addons EZO
cargados en el mismo cliente. Es la ruta normal para coordinar addons entre si.
No persiste estado y nunca envia datos a otros jugadores.

Publicador:

```lua
local localState = EZOCore and EZOCore:GetService("family.localState", 1)
if localState then
    localState:Publish("ezotools.groupActivity", {
        sourceAddon = "ezotools",
        version = 1,
        activityType = "trial",
        stage = "staging",
        targetKey = "sanitys_edge",
        leader = true,
    }, {
        publisherAddonId = "ezotools",
        version = 1,
        ttlSeconds = 120,
    })
end
```

Consumidor:

```lua
local localState = EZOCore and EZOCore:GetService("family.localState", 1)
if localState then
    localState:Subscribe("ezotools.groupActivity", function(entry)
        local value = entry and entry.value
        if value then
            -- Refrescar UI local desde value.stage, value.targetKey, etc.
        end
    end)

    local current = localState:GetValue("ezotools.groupActivity")
end
```

Reglas:

- Las claves deben tener namespace, por ejemplo `ezotools.groupActivity`.
- Los valores deben ser datos planos: strings, numeros, booleanos y tablas
  pequenas.
- No publiques funciones, controles, userdata ni referencias a SavedVariables.
- No uses este servicio para datos entre jugadores; usa las APIs productoras de
  `family.groupPresence` para datos que deban viajar por LibGroupBroadcast.
- Los addons deben mantener su comportamiento independiente cuando EZOCore no
  este presente.

## Consultar Estado De Presencia De Grupo

El servicio `family.groupPresence` permite que los consumidores comprueben si el
transporte registrado está disponible y consulten el estado actual de los peers:

```lua
local groupPresence = EZOCore and EZOCore:GetService("family.groupPresence", 1)
local status = groupPresence and groupPresence:GetStatus()
if status and status.active then
    local state = groupPresence:GetPeerCompatibility(
        "group1", "ezotools", "group.activities", 1, 10145)
end
```

Los productores deben publicar mediante EZOCore, no declarando handlers de
LibGroupBroadcast directamente:

```lua
local groupPresence = EZOCore and EZOCore:GetService("family.groupPresence", 1)
if groupPresence then
    groupPresence:PublishActivityState({
        sourceAddonId = "ezotools",
        activityType = "trial",
        stage = "staging",
        result = "active",
        sessionId = 1,
        ttlSeconds = 60,
        targetKey = "example",
    })

    groupPresence:PublishPerformanceState({
        sourceAddonId = "ezogroupframes",
        pingMs = 42,
        fps = 58,
        privacyState = "public",
        ttlSeconds = 30,
    })
end
```

`privacyState = "public"` exige valores válidos de ping y FPS. Con `unknown`,
`private` o `hidden`, las métricas pueden omitirse y EZOCore transmite ceros. El
productor sigue siendo responsable de ofrecer un opt-in explícito antes de
publicar estado de rendimiento.

Los consumidores reciben el estado de actividad validado mediante
`EZO_CORE_GROUP_ACTIVITY_STATE_UPDATED`. El tipo de actividad, la etapa y el
resultado son valores con nombre; los códigos compactos usados por red también
se exponen con el sufijo `Code`. Los productores pueden escuchar
`EZO_CORE_GROUP_PRESENCE_REQUESTED` y volver a publicar su estado actual después
de resincronizar presencia. Son callbacks locales de EZOCore, no registros de
LibGroupBroadcast propiedad del consumidor.

Los dos últimos argumentos son la versión mínima de la API local y el
`AddOnVersion` numérico mínimo opcional. Usa este último para compatibilidad de
builds; no compares cadenas de versión visibles.

El transporte puede no estar disponible si falta LibGroupBroadcast, si el
usuario ha desactivado el protocolo o si el jugador no esta en grupo. No se
deben mostrar avisos no solicitados al jugador por esos estados normales.

Cuando el transporte este activo, la compatibilidad se basará en IDs estables de
addon, `AddOnVersion` numérico, versión de API local y bits de capacidades
declaradas. Los peers desconocidos o caducados deben seguir como `unknown`; un
consumidor no debe deducir que falta un addon hasta recibir una presencia válida
del miembro actual del grupo.
EZOCore renueva la presencia cada 45 segundos mientras el jugador está en grupo
y reinicia el estado transitorio de secuencias cuando un emisor comienza una
sesión nueva.

Los IDs reservados y el formato por red estan documentados en
[group-presence-protocol.es.md](group-presence-protocol.es.md). El protocolo es
`EZO_CORE_GROUP_V1` (`513`) y el custom event de resincronizacion es
`EZO_CORE_GROUP_REQUEST_V1` (`3`).

## Usar Diagnostico Comun

El servicio `family.debug` centraliza el acceso opcional a LibDebugLogger sin
convertir el diagnostico en una dependencia obligatoria:

```lua
local diagnostics = EZOCore and EZOCore:GetService("family.debug", 1)
if diagnostics then
    diagnostics:Debug("EZOTools", "Actividad seleccionada: %s", activityName)
end
```

Los metodos disponibles son `Log(tag, level, message, ...)`, `Debug`, `Info`,
`Warn`, `Error`, `IsAvailable`, `IsViewerAvailable` y `ShowViewer`. Los metodos
de log devuelven `false` sin formatear ni conservar el mensaje cuando
LibDebugLogger no esta disponible. Los metodos del visor tambien devuelven
`false` sin escribir en el chat.

Los addons funcionales deben mantener su ruta opcional independiente a
LibDebugLogger mientras EZOCore siga siendo opcional. No se debe usar `Error`
para diagnostico ordinario; queda reservado para errores capturados y
suprimidos por el propio addon.

## Registrar Una Superficie Movible

Usa `family.layout` solo para superficies HUD de posición libre que ya tengan
un modo mover independiente:

```lua
local layout = EZOCore and EZOCore:GetService("family.layout", 1)
if layout then
    layout:RegisterSurface({
        id = "example.alert",
        addonId = "example",
        addonName = "Example",
        name = "Ventana de avisos",
        setEditMode = function(enabled)
            Example.SetMoveMode(enabled)
            return Example.IsMoveMode() == enabled
        end,
        isEditMode = Example.IsMoveMode,
    })
end
```

El estado de movimiento debe limitarse a la sesión. El addon conserva la
previsualización, visibilidad HUD/HUD_UI, guardado de posición y fallback local
cuando EZOCore no está disponible. No registres retículos, marcadores ligados a
unidades, controles nativos de ESO ni paneles de Settings.

## Registrar Un Servicio

Los servicios son tablas locales explicitas. EZOCore no ejecuta funciones por
nombre.

```lua
local service = {
    GetState = function()
        return currentState
    end,
}

if EZOCore and type(EZOCore.RegisterService) == "function" then
    EZOCore:RegisterService("example.state", 1, service)
end
```

Los consumidores recuperan servicios de forma defensiva:

```lua
local service = EZOCore and EZOCore:GetService("example.state", 1)
if service and type(service.GetState) == "function" then
    local state = service:GetState()
end
```

## Registrar Settings

Los addons con tablas de opciones de LibAddonMenu deben mantener su panel LAM
normal y registrar ese panel en EZOCore cuando este disponible:

```lua
local panelData = {
    type = "panel",
    name = "EZOTools",
    displayName = "EZOTools",
    author = "@Zuriplayer",
    version = EZOTools.ADDON_VERSION,
    ezoStage = "beta",
    registerForRefresh = true,
}

local options = BuildOptions()

if EZOCore and type(EZOCore.RegisterSettingsPanel) == "function" then
    EZOCore:RegisterSettingsPanel("ezotools", "EZOTools_Panel", panelData, options)
elseif LibAddonMenu2 then
    LibAddonMenu2:RegisterAddonPanel("EZOTools_Panel", panelData)
    LibAddonMenu2:RegisterOptionControls("EZOTools_Panel", options)
end
```

La ventana central `Settings > EZO` dibuja los controles LAM registrados por
cada addon dentro de su propia vista. Al seleccionar un addon se permanece dentro
del panel EZO y no se crea una entrada duplicada en la lista estándar de
configuración. El panel LAM independiente solo actúa como fallback de
compatibilidad cuando EZOCore no está disponible.

`panelData.ezoStage` debe coincidir con `addon.stage` en el archivo
`ezo-addon.json` del repositorio. Los valores admitidos en ejecución son
`development`, `beta`, `stable`, `maintenance` y `archived`. EZOCore centraliza
la validación, el orden, los nombres de grupo y sus textos de ayuda. Los valores
ausentes o no válidos se muestran en `Sin clasificar`; EZOCore nunca deduce la
madurez a partir del nombre o la versión de un addon.

## Callbacks Locales

Los callbacks viven en memoria y son locales a un unico cliente de ESO:

```lua
local function OnAddonRegistered(addon)
    -- Inspeccionar addon.id, addon.version, addon.capabilities, etc.
end

if EZOCore and type(EZOCore.RegisterCallback) == "function" then
    EZOCore:RegisterCallback(EZOCore.EVENT_ADDON_REGISTERED, OnAddonRegistered)
end
```

Usa `UnregisterCallback(eventName, callback)` al retirar listeners temporales.

## Todavia No Implementado

EZOCore no implementa comandos remotos, viaje automático ni SavedVariables como
bus. La presencia de grupo y las APIs productoras informativas están
implementadas, pero todavía requieren pruebas de aceptación con varios clientes
antes de que los consumidores dependan de ellas para comportamiento visible.
