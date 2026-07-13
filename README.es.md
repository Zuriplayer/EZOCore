# EZOCore

Capa de servicios locales para addons de EZO en *The Elder Scrolls Online*: registro de addons, descubrimiento de servicios, capacidades, callbacks y diagnóstico.

🇬🇧 Prefer English? Read the [README in English](README.md).

## Fase actual

EZOCore está actualmente en una fase de **vista previa de servicio solo local**:

- Expone una pequeña API local de registro/servicio/callbacks que funciona por completo dentro de un único cliente de ESO.
- Todavía no hay sincronización de grupo, no se usa LibGroupBroadcast y no hay comunicación entre jugadores.
- No hay automatización remota disparada desde dentro del juego; los GitHub Actions de este repositorio son workflows manuales, disparados por el desarrollador, para empaquetar y publicar el estado en Discord.

## ¿Este addon hace algo por sí solo?

No demasiado por sí mismo. EZOCore está pensado como una dependencia opcional compartida para otros addons de EZO (como EZOTools o EZOGroupFrames). Esos addons siguen funcionando perfectamente sin EZOCore instalado; cuando está presente, podrán usar `## OptionalDependsOn: EZOCore` para descubrir servicios compartidos en lugar de duplicar esa lógica.

## API (fase local)

- `EZOCore:RegisterAddon(metadata)`
- `EZOCore:GetAddon(addonId)`
- `EZOCore:GetRegisteredAddons()`
- `EZOCore:HasAddon(addonId, minimumApiVersion)`
- `EZOCore:HasCapability(addonId, capability, minimumApiVersion)`
- `EZOCore:RegisterService(name, apiVersion, service)`
- `EZOCore:GetService(name, minimumApiVersion)`
- `EZOCore:RegisterCallback(eventName, callback)`
- `EZOCore:UnregisterCallback(eventName, callback)`
- `EZOCore:FireCallback(eventName, ...)`

Todo lo anterior funciona localmente en memoria. Nada se guarda en SavedVariables y nada se envía por red.

Los addons deben registrarse con IDs EZO estables en minúsculas, versión visible, `AddOnVersion` numérico, versión de API local y capacidades. EZOCore rechaza metadata inválida sin romper al llamador.

## Requisitos

- The Elder Scrolls Online (PC)
- Opcional: LibDebugLogger, DebugLogViewer (para diagnóstico; EZOCore se degrada sin romperse si no están)

## Instalación

1. Descarga la última versión desde Releases (o clona este repositorio).
2. Copia la carpeta `EZOCore` en tu carpeta de AddOns de ESO: `Documents/Elder Scrolls Online/live/AddOns/`.
3. Activa el addon desde la pantalla de Add-Ons del juego.

## Hoja de ruta (todavía no implementado)

Fases futuras podrían añadir presencia y mensajería entre jugadores mediante LibGroupBroadcast. Ese trabajo no ha comenzado y nada en este repositorio lo implementa todavía; este README se actualizará cuando así sea.

## Soporte

📢 Para soporte, feedback, reportar bugs o sugerencias, únete a nuestro Discord: https://discord.gg/hsc9AHC5Cr

## Licencia

MIT — ver [LICENSE](LICENSE).

Desarrollado y mantenido por Zuriplayer.
