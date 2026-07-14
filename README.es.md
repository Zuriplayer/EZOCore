# EZOCore

Capa de servicios locales para addons de EZO en *The Elder Scrolls Online*: registro de addons, descubrimiento de servicios, capacidades, callbacks y diagnóstico.

🇬🇧 Prefer English? Read the [README in English](README.md).

## Fase actual

EZOCore está actualmente en **beta pública** dentro de una fase de vista previa de servicio solo local:

- Expone una pequeña API local de registro/servicio/callbacks que funciona por completo dentro de un único cliente de ESO.
- Es propietario del menú central `Settings > EZO` para la configuración de los addons de la familia EZO, con cabeceras informativas estándar de EZO.
- Proporciona un modo de idioma común para la familia EZO: automático, inglés, español o "dejar que cada addon elija"; los addons independientes conservan su fallback propio cuando EZOCore no está instalado o el modo central permite opciones locales.
- Todavía no hay sincronización de grupo, no se usa LibGroupBroadcast y no hay comunicación entre jugadores.
- No hay automatización remota disparada desde dentro del juego; los GitHub Actions de este repositorio son workflows manuales, disparados por el desarrollador, para empaquetar y publicar el estado en Discord.
- Beta pública significa que el repositorio está visible para revisión/pruebas, pero el conjunto implementado sigue limitado intencionadamente a servicios locales.

## ¿Este addon hace algo por sí solo?

No demasiado por sí mismo. EZOCore está pensado como una dependencia opcional compartida para otros addons de EZO (como EZOTools o EZOGroupFrames). Esos addons siguen funcionando perfectamente sin EZOCore instalado; cuando está presente, podrán usar `## OptionalDependsOn: EZOCore` para descubrir servicios compartidos en lugar de duplicar esa lógica.

## Panel de ajustes

EZOCore es propietario del hub central `Settings > EZO`. Su índice lateral combina navegación y selectores de activación: EZOCore permanece marcado y bloqueado, mientras los demás addons EZO instalados se pueden activar o desactivar y aplicar mediante el botón común `Recargar UI`. Los addons se agrupan por su fase declarada, desde trabajos estables y mantenidos hasta versiones beta y en desarrollo; los estados archivado y sin clasificar permanecen explícitos. Cada grupo usa el icono informativo morado de EZO y mantiene su explicación en el tooltip de la cabecera. Los addons desactivados permanecen en la lista, pero no pueden mostrar sus ajustes hasta activarlos y recargar la interfaz. La ayuda específica de cada campo permanece en el tooltip de su propio control.

## Preferencia de idioma

EZOCore guarda un modo de idioma de cuenta para la familia EZO: automático, inglés, español o "dejar que cada addon elija". Automático, inglés y español desactivan los selectores de idioma de los addons integrados y aplican la elección central. "Dejar que cada addon elija" vuelve a habilitar el selector local de cada addon. Los addons instalados sin EZOCore deben seguir exponiendo su propio fallback local de idioma.

## API (fase local)

- `EZOCore:RegisterAddon(metadata)`
- `EZOCore:GetAddon(addonId)`
- `EZOCore:GetRegisteredAddons()`
- `EZOCore:HasAddon(addonId, minimumApiVersion)`
- `EZOCore:HasCapability(addonId, capability, minimumApiVersion)`
- `EZOCore:RegisterService(name, apiVersion, service)`
- `EZOCore:GetService(name, minimumApiVersion)`
- `EZOCore:RegisterSettingsPanel(addonId, panelId, panelData, options)`
- `EZOCore:GetSettingsPanels()`
- `EZOCore:OpenSettingsPanel(addonId)`
- `EZOCore:RefreshSettingsPanel()`
- `EZOCore:OpenSettings()`
- `EZOCore:GetConfiguredLanguage()`
- `EZOCore:GetLanguage()`
- `EZOCore:GetClientLanguage()`
- `EZOCore:SetLanguage(language)`
- `EZOCore:IsSupportedLanguage(language)`
- `EZOCore:IsLanguageGloballyManaged()`
- `EZOCore:RegisterCallback(eventName, callback)`
- `EZOCore:UnregisterCallback(eventName, callback)`
- `EZOCore:FireCallback(eventName, ...)`

Todo lo anterior funciona localmente en el cliente actual. La preferencia global de idioma se guarda en las SavedVariables de EZOCore; el registro de addons, los servicios y los callbacks siguen siendo locales de sesión y nada se envía por red.

Los addons deben registrarse con IDs EZO estables en minúsculas, versión visible, `AddOnVersion` numérico, versión de API local y capacidades. EZOCore rechaza metadata inválida sin romper al llamador.

Los ejemplos de integración para consumidores viven en [docs/consumer-integration.es.md](docs/consumer-integration.es.md). Los servicios implementados ahora son:

- `family.settings` API v1: registro central en `Settings > EZO`, navegación y controles de carga de addons instalados.
- `family.presence` API v1: fachada local de presencia sobre addons EZO registrados, versiones y capacidades.
- `family.language` API v1: preferencia local de idioma compartida para addons de la familia EZO.
- registro local de addons/capacidades: descubrimiento solo local para consumidores como EZOTools.

## Requisitos

- The Elder Scrolls Online (PC)
- Opcional: LibDebugLogger, DebugLogViewer (para diagnóstico; EZOCore se degrada sin romperse si no están)
- Opcional: LibAddonMenu-2.0 (para dibujar controles de opciones registrados en `Settings > EZO`)

## Instalación

1. Descarga la última versión desde Releases (o clona este repositorio).
2. Copia la carpeta `EZOCore` en tu carpeta de AddOns de ESO: `Documents/Elder Scrolls Online/live/AddOns/`.
3. Activa el addon desde la pantalla de Add-Ons del juego.

## Hoja de ruta (todavía no implementado)

Fases futuras podrían añadir presencia y mensajería entre jugadores mediante LibGroupBroadcast. Ese trabajo no ha comenzado y nada en este repositorio lo implementa todavía; este README se actualizará cuando así sea.

## Soporte

📢 Para soporte, feedback, reportar bugs o sugerencias, únete a nuestro Discord: https://discord.gg/ekw8zUAcRm

## Licencia

MIT — ver [LICENSE](LICENSE).

Desarrollado y mantenido por Zuriplayer.
