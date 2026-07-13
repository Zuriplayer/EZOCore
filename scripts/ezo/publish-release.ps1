[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$ReleaseWebhookUrl = $env:EZO_CODEX_RELEASES,
    [string]$DownloadWebhookUrl = $env:EZO_CODEX_DOWNLOADS,
    [string]$AnnouncementWebhookUrl = $env:EZO_CODEX_ANNOUNCER,
    [string]$CodexLogWebhookUrl = $env:CODEX_LOG,
    [string]$Note = "Release prepared from GitHub Actions.",
    [string]$DownloadNote,
    [string]$ZipPath,
    [switch]$PublishDownload,
    [switch]$PublishAnnouncement,
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

$description = @(
    "**Addon:** $($addon.name)"
    "**Version:** $($addon.version)"
    "**Status:** $($addon.status)"
    ""
    $Note
) -join "`n"

& $publishDiscord `
    -WebhookUrl $ReleaseWebhookUrl `
    -Title "Release note: $($addon.name) v$($addon.version)" `
    -Description $description `
    -Color 5763719 `
    -FilePath $ZipPath `
    -DryRun:$DryRun

if ($PublishDownload) {
    # #downloads is bilingual (EN+ES) by rule; everything else stays English-only.
    # Falls back to -Note if no bilingual text was provided, so old callers keep working.
    $effectiveDownloadNote = if ($DownloadNote) { $DownloadNote } else { $Note }
    $downloadScript = Join-Path $PSScriptRoot "publish-download.ps1"
    & $downloadScript -ConfigPath $ConfigPath -WebhookUrl $DownloadWebhookUrl -ZipPath $ZipPath -Note $effectiveDownloadNote -DryRun:$DryRun -Force:$Force
}

if ($PublishAnnouncement) {
    $announcementScript = Join-Path $PSScriptRoot "publish-announcement.ps1"
    & $announcementScript -ConfigPath $ConfigPath -WebhookUrl $AnnouncementWebhookUrl -Note $Note -DryRun:$DryRun
}

if ($PublishCodexLog) {
    $codexLogScript = Join-Path $PSScriptRoot "publish-codex-log.ps1"
    & $codexLogScript -ConfigPath $ConfigPath -WebhookUrl $CodexLogWebhookUrl -Action "Release workflow completed" -Note $Note -DryRun:$DryRun
}
