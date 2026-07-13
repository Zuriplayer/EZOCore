[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$WebhookUrl = $env:EZO_CODEX_BETA_BUILDS,
    [string]$CodexLogWebhookUrl = $env:CODEX_LOG,
    [string]$Note = "Clean beta build generated from GitHub Actions.",
    [string]$ZipPath,
    [switch]$PublishCodexLog,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$repoRoot = (Get-Item -LiteralPath (Join-Path $PSScriptRoot "..\..")).FullName
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $repoRoot "ezo-addon.json"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$addon = $config.addon
$publishDiscord = Join-Path $PSScriptRoot "publish-discord.ps1"

if (-not $ZipPath) {
    $ZipPath = Join-Path $repoRoot (Join-Path $config.package.outputPath $config.package.zipName)
}

if ($Force -or -not (Test-Path -LiteralPath $ZipPath)) {
    $buildScript = Join-Path $PSScriptRoot "build-addon-package.ps1"
    & $buildScript -ConfigPath $ConfigPath -Force:$Force | Out-Null
}

$description = @(
    "**Addon:** $($addon.name)"
    "**Version:** $($addon.version)"
    ""
    $Note
) -join "`n"

& $publishDiscord `
    -WebhookUrl $WebhookUrl `
    -Title "EZOCore beta build: $($addon.name)" `
    -Description $description `
    -Color 5763719 `
    -FilePath $ZipPath `
    -DryRun:$DryRun

if ($PublishCodexLog) {
    & $publishDiscord `
        -WebhookUrl $CodexLogWebhookUrl `
        -Title "Codex log: beta build published" `
        -Description $description `
        -Color 10181046 `
        -DryRun:$DryRun
}
