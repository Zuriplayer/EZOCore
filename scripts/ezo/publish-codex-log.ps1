[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$WebhookUrl = $env:CODEX_LOG,
    [string]$Action = "Workflow completed",
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
    "**Action:** $Action"
)
if ($Note) {
    $descriptionLines += ""
    $descriptionLines += $Note
}
$description = $descriptionLines -join "`n"

& $publishDiscord `
    -WebhookUrl $WebhookUrl `
    -Title "Codex log: $Action" `
    -Description $description `
    -Color 10181046 `
    -DryRun:$DryRun
