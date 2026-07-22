# Politica de guardado de preferencias EZO

EZOCore es propietario de la politica compartida para preferencias ordinarias
de addons EZO. La politica se guarda por cuenta en `EZOCoreSavedVariables` para
que todos los personajes vean la misma decision familiar.

## Alcance predeterminado

El alcance predeterminado es `character`. Los addons integrados pueden usar
`EZOCore:GetPreferenceScope(addonId, preferenceKey)` para decidir si una
preferencia debe cargarse desde guardado de personaje o de cuenta.

## Siempre Por Cuenta

Estos addons son solo globales y deben permanecer por cuenta aunque el alcance
predeterminado sea `character`:

| Addon | Motivo |
| --- | --- |
| EZORaidPlanner | Los datos de planificacion de raid son estado compartido de cuenta/familia. |
| EZOTools | Los datos de herramienta y estado de modulos son estado de cuenta/familia. |
| EZOTest | El estado de pruebas permanece por cuenta; el addon todavia no esta integrado en EZOCore. |

Estas preferencias individuales tambien son solo globales:

| Addon | Clave de preferencia | Motivo |
| --- | --- | --- |
| EZOCore | `language` | Politica de idioma compartida de la familia. |
| EZOCore | `preferences.defaultScope` | La propia politica de guardado debe ser comun. |
| EZOCore | `settings.addonLifecycleDefaults` | La politica de ciclo de vida de addons instalados no depende del personaje. |
| EZOcamsens | `meta.settingsScope` | La metadata de alcance controla desde donde carga ajustes el addon. |
| EZOChat | `history.messages` | El historial de chat es un registro compartido de cuenta. |

## Exclusiones Actuales

Estos addons quedan intencionadamente fuera de esta pasada de migracion:

| Addon | Decision |
| --- | --- |
| EZOChat | Dejar sin cambios por ahora, salvo la politica conocida de historial siempre global. |
| EZOTakingAim / EZOta | Ignorar por ahora. |
| EZOAuto | Mantener por personaje. |
| EZOMetter | Mantener por personaje. |

## Direccion De Migracion

Los addons deben migrarse gradualmente. Posiciones HUD, preferencias de camara o
combate y comportamiento de rol de personaje deberian seguir normalmente el
alcance predeterminado. Datos compartidos de planificacion, rutas de cuenta,
idioma/politicas centrales e historiales largos deben permanecer por cuenta.

La politica no mueve datos por si misma. Cada addon consumidor debe migrar sus
propias SavedVariables y conservar los datos antiguos de cuenta hasta que
`/reloadui` y las comprobaciones con varios personajes confirmen el resultado.
