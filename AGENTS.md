# EZOCore - AI Development Rules

<!-- EZO-SHARED-LAM-START -->
## Estándar LAM compartido

Antes de crear o modificar ajustes LibAddonMenu, leer y aplicar:
`E:\Dev\EZOFamilyDocs\docs\ezo-lam-settings-style.md`

Las reglas específicas de este addon tienen prioridad. Si el archivo compartido
no está accesible, no modificar LAM e indicarlo explícitamente.
<!-- EZO-SHARED-LAM-END -->

<!-- EZO-ESO-UPDATE-START -->
## Baseline obligatorio de ESO

Antes de analizar, modificar, validar, versionar o publicar este proyecto, leer
`..\EZOFamilyDocs\docs\eso-updates\current.md` y aplicar la política enlazada.

Baseline vigente: `U51-PTS-v12.1.0`.

- La matriz por addon vive en `..\EZOFamilyDocs\data\eso-update-baseline.json`.
- U51 sigue siendo PTS provisional hasta que exista verificación explícita.
- No cambiar `## APIVersion` por inferencia; verificarla en el cliente o en una
  fuente fiable de API.
- Si estos archivos no están disponibles, detener el trabajo sensible a
  compatibilidad e indicar el bloqueo.

Fuente remota de respaldo:
https://github.com/Zuriplayer/EZOFamilyDocs/blob/main/docs/eso-updates/current.md
<!-- EZO-ESO-UPDATE-END -->
