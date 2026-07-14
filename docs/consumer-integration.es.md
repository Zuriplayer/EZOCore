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

- transporte LibGroupBroadcast;
- presencia entre jugadores;
- registro de peers/miembros;
- sincronizacion de estado de reset;
- comandos remotos ni viaje automatico;
- SavedVariables como bus.

Las futuras funciones entre jugadores deben ser primero informativas,
versionadas, comprobadas por capacidad y validadas por separado.
