# Integracion De Consumidores Con EZOCore

Este documento describe la superficie de integracion local actual para addons
EZO. Solo cubre funcionalidad implementada ahora en EZOCore: registro local de
addons, descubrimiento de servicios, capacidades, callbacks y el servicio
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

## Consultar Estado De Presencia De Grupo

El servicio `family.groupPresence` existe antes de activar trafico remoto. Sirve
para que los consumidores comprueben si el transporte esta disponible y consulten
estado de peers cuando el protocolo se active:

```lua
local groupPresence = EZOCore and EZOCore:GetService("family.groupPresence", 1)
local status = groupPresence and groupPresence:GetStatus()
if status and status.active then
    local state = groupPresence:GetPeerCompatibility("group1", "ezotools", "group.activities", 1)
end
```

Las builds actuales devuelven `protocolDefinitionPending` y no envian datos. No
se deben mostrar avisos no solicitados al jugador por ese estado.

La ficha de reserva y el formato por red estan documentados en
[group-presence-protocol.es.md](group-presence-protocol.es.md). El nombre de
protocolo previsto es `EZO_CORE_GROUP_V1` y el custom event de resincronizacion
previsto es `EZO_CORE_GROUP_REQUEST_V1`.

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

EZOCore actualmente no implementa:

- transmision activa de presencia de grupo;
- presencia entre jugadores;
- registro de peers/miembros;
- sincronizacion de estado de reset;
- comandos remotos ni viaje automatico;
- SavedVariables como bus.

Las futuras funciones entre jugadores deben ser primero informativas,
versionadas, comprobadas por capacidad y validadas por separado.
