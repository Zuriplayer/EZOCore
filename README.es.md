# EZOCore

Capa de servicios locales para addons de EZO en *The Elder Scrolls Online*: registro de addons, descubrimiento de servicios, capacidades, callbacks y diagnóstico.

🇬🇧 Prefer English? Read the [README in English](README.md).

## Fase actual

EZOCore está actualmente en **beta pública** como capa de servicios compartidos:

- Expone una pequeña API local de registro/servicio/callbacks que funciona por completo dentro de un único cliente de ESO.
- Es propietario del menú central `Settings > EZO` para la configuración de los addons de la familia EZO, con cabeceras informativas estándar de EZO.
- Proporciona un modo de idioma común para la familia EZO: automático, inglés, español o "dejar que cada addon elija"; los addons independientes conservan su fallback propio cuando EZOCore no está instalado o el modo central permite opciones locales.
- Coordina modos temporales de movimiento global e individual para los addons EZO que registran superficies HUD compatibles; las previsualizaciones permanecen ocultas en Settings y aparecen al volver al HUD principal.
- Es el único propietario del transporte LibGroupBroadcast de la familia EZO: `EZO_CORE_GROUP_V1` (`513`) y `EZO_CORE_GROUP_REQUEST_V1` (`3`). Estando en grupo, los clientes con EZOCore y el protocolo habilitado en LibGroupBroadcast pueden intercambiar presencia compacta de addons, builds numéricas, capacidades, estado de actividad y estado opcional de rendimiento. Consulta [docs/group-presence-protocol.es.md](docs/group-presence-protocol.es.md).
- No hay automatización remota disparada desde dentro del juego; los GitHub Actions de este repositorio son workflows manuales, disparados por el desarrollador, para empaquetar y publicar el estado en Discord.
- Beta pública significa que el repositorio está visible para revisión/pruebas y que el transporte de presencia de grupo todavía necesita pruebas con varios clientes antes de que otros addons dependan de él para comportamientos visibles.

## ¿Este addon hace algo por sí solo?

No demasiado por sí mismo. EZOCore está pensado como una dependencia opcional compartida para otros addons de EZO (como EZOTools o EZOGroupFrames). Esos addons siguen funcionando perfectamente sin EZOCore instalado; cuando está presente, podrán usar `## OptionalDependsOn: EZOCore` para descubrir servicios compartidos en lugar de duplicar esa lógica.

## Panel de ajustes

EZOCore es propietario del hub central `Settings > EZO`. La entrada nativa de Ajustes usa la identidad visual de la familia EZO con la Z morada. Las aperturas programáticas desde un addon integrado seleccionan directamente la vista de ajustes EZO de ese addon. Su índice lateral combina navegación y selectores de activación: EZOCore permanece marcado y bloqueado, mientras los demás addons EZO instalados se pueden activar o desactivar y aplicar mediante el botón común `Recargar UI`. Los addons se agrupan por su fase declarada en orden de madurez: Estable, Mantenimiento, Beta, Desarrollo, Sin clasificar y Archivado. Por tanto, los addons archivados permanecen visibles al final de la lista. Los addons nuevos detectados en Desarrollo o Sin clasificar empiezan desactivados y requieren recarga para retirar el código ya cargado; si después activas uno manualmente, la decisión se recuerda y no se sobrescribe. La primera actualización a esta política conserva el estado de todos los addons instalados actualmente. Cada grupo usa el icono informativo morado de EZO y mantiene su explicación en el tooltip de la cabecera. Los addons desactivados permanecen en la lista, pero no pueden mostrar sus ajustes hasta activarlos y recargar la interfaz. La ayuda específica de cada campo permanece en el tooltip de su propio control.

La sección Disposición de interfaz puede desbloquear todas las superficies EZO registradas a la vez o una por una. Cierra Settings para ver y colocar las previsualizaciones en HUD/HUD_UI y vuelve después a la misma sección para desactivar el movimiento. El estado de edición nunca se persiste; cada addon consumidor conserva la propiedad de su posición, escala y control de movimiento independiente.

## Preferencia de idioma

EZOCore guarda un modo de idioma de cuenta para la familia EZO: automático, inglés, español o "dejar que cada addon elija". Automático, inglés y español desactivan los selectores de idioma de los addons integrados y aplican la elección central. "Dejar que cada addon elija" vuelve a habilitar el selector local de cada addon. Los addons instalados sin EZOCore deben seguir exponiendo su propio fallback local de idioma.

## API

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

Las APIs de registro, estado local, ajustes, idioma, disposición, diagnóstico y callbacks funcionan localmente en el cliente actual. La preferencia global de idioma y la política de primera detección se guardan en las SavedVariables de EZOCore. Solo `family.groupPresence` usa LibGroupBroadcast, únicamente estando en grupo y cuando sus ajustes de usuario lo permiten.

Los addons deben registrarse con IDs EZO estables en minúsculas, versión visible, `AddOnVersion` numérico, versión de API local y capacidades. EZOCore rechaza metadata inválida sin romper al llamador.

Los ejemplos de integración para consumidores viven en [docs/consumer-integration.es.md](docs/consumer-integration.es.md). Los servicios implementados ahora son:

- `family.settings` API v1: registro central en `Settings > EZO`, navegación y controles de carga de addons instalados.
- `family.presence` API v1: fachada local de presencia sobre addons EZO registrados, versiones y capacidades.
- `family.localState` API v1: intercambio de estado local de sesión entre addons EZO en el mismo cliente.
- `family.groupPresence` API v1: fachada de presencia remota entre peers usando el protocolo reservado de LibGroupBroadcast `EZO_CORE_GROUP_V1` (`513`) y el evento de solicitud `EZO_CORE_GROUP_REQUEST_V1` (`3`).
- `family.language` API v1: preferencia local de idioma compartida para addons de la familia EZO.
- `family.debug` API v1: acceso común opcional a LibDebugLogger y DebugLogViewer, sin fallback al chat ni trabajo en ejecución cuando el backend no está disponible.
- `family.layout` API v1: registro de sesión y coordinación global e individual del movimiento para superficies HUD EZO compatibles.
- registro local de addons/capacidades: descubrimiento solo local para consumidores como EZOTools.

El servicio `family.groupPresence` expone consultas de estado y
especificación, consulta de peers/addons remotos, comprobaciones de
compatibilidad por capacidad/build, anuncio de presencia, publicación de
actividad/rendimiento, consulta de rendimiento remoto y solicitud de
resincronización. Los métodos de anuncio y solicitud devuelven un motivo sin
enviar cuando el transporte, el grupo o el ajuste correspondiente del usuario
en LibGroupBroadcast no están disponibles. Los clientes agrupados con el
transporte activo renuevan presencia cada 45 segundos; los estados de
rendimiento no públicos nunca exponen ping ni FPS.

## Requisitos

- The Elder Scrolls Online (PC)
- Opcional: LibDebugLogger, DebugLogViewer (para diagnóstico; EZOCore se degrada sin romperse si no están)
- Opcional: LibAddonMenu-2.0 (para dibujar controles de opciones registrados en `Settings > EZO`)
- Opcional: LibGroupBroadcast 2.0.0 (solo es necesario para la presencia EZO entre jugadores; todos los servicios locales de EZOCore continúan sin él)

## Instalación

1. Descarga la última versión desde Releases (o clona este repositorio).
2. Copia la carpeta `EZOCore` en tu carpeta de AddOns de ESO: `Documents/Elder Scrolls Online/live/AddOns/`.
3. Activa el addon desde la pantalla de Add-Ons del juego.

## Hoja de ruta (todavía no implementado)

EZOTools ya puede publicar y mostrar estado compacto de Actividades de grupo mediante este servicio. Fases futuras podrán conectar EZOGroupFrames y añadir acciones de miembros con activación expresa. El estado informativo de actividad y rendimiento no permite viajes remotos, invitaciones, cambios de grupo ni otras acciones automatizadas.

## Soporte

📢 Para soporte, feedback, reportar bugs o sugerencias, únete a nuestro Discord: https://discord.gg/ekw8zUAcRm

## Licencia

MIT — ver [LICENSE](LICENSE).

Desarrollado y mantenido por Zuriplayer.
