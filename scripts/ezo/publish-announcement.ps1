[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$WebhookUrl = $env:EZO_CODEX_ANNOUNCER,
    [string]$Note,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = (Get-Item -LiteralPath (Join-Path $PSScriptRoot "..\..")).FullName
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $repoRoot "ezo-addon.json"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$addon = $config.addon
$publishDiscord = Join-Path $PSScriptRoot "publish-discord.ps1"

$descriptionLines = @(
    "**Addon:** $($addon.name)"
    "**Version:** $($addon.version)"
)
if ($Note) {
    $descriptionLines += ""
    $descriptionLines += $Note
}
$description = $descriptionLines -join "`n"

& $publishDiscord `
    -WebhookUrl $WebhookUrl `
    -Title "EZOCore announcement: $($addon.name) v$($addon.version)" `
    -Description $description `
    -Color 15844367 `
    -DryRun:$DryRun
