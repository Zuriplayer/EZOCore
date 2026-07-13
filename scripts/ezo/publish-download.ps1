[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$WebhookUrl = $env:EZO_CODEX_DOWNLOADS,
    [string]$Note,
    [string]$ZipPath,
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
$package = if ($addon.package) { $addon.package } else { $config.package }
$publishDiscord = Join-Path $PSScriptRoot "publish-discord.ps1"

if (-not $ZipPath) {
    if (-not $package) {
        throw "Package configuration not found in ezo-addon.json."
    }
    $ZipPath = Join-Path $repoRoot (Join-Path $package.outputPath $package.zipName)
}

if ($Force -or -not (Test-Path -LiteralPath $ZipPath)) {
    $buildScript = Join-Path $PSScriptRoot "build-addon-package.ps1"
    & $buildScript -ConfigPath $ConfigPath -Force:$Force | Out-Null
}

# #downloads is bilingual (EN+ES) by convention; this script does not translate
# automatically, it only forwards whatever bilingual $Note the caller supplies.
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
    -Title "EZOCore download: $($addon.name) v$($addon.version)" `
    -Description $description `
    -Color 3066993 `
    -FilePath $ZipPath `
    -DryRun:$DryRun
