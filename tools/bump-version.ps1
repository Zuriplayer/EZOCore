[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$ManifestPath,
    [switch]$Check,
    [string]$NewVersion
)

$ErrorActionPreference = "Stop"

$repoRoot = (Get-Item -LiteralPath (Join-Path $PSScriptRoot "..")).FullName
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $repoRoot "ezo-addon.json"
}
if (-not $ManifestPath) {
    $ManifestPath = Join-Path $repoRoot "EZOCore.txt"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$manifestLines = Get-Content -LiteralPath $ManifestPath

function Get-ManifestValue {
    param([string[]]$Lines, [string]$Key)

    foreach ($line in $Lines) {
        if ($line -match "^##\s*$Key\s*:\s*(.+)$") {
            return $Matches[1].Trim()
        }
    }

    return $null
}

$manifestVersion = Get-ManifestValue -Lines $manifestLines -Key "Version"
$configVersion = $config.addon.version
$expectedZipName = "EZOCore_v$configVersion.zip"
$actualZipName = $config.package.zipName

$issues = @()

if ($manifestVersion -ne $configVersion) {
    $issues += "EZOCore.txt Version ('$manifestVersion') does not match ezo-addon.json addon.version ('$configVersion')."
}

if ($actualZipName -ne $expectedZipName) {
    $issues += "ezo-addon.json package.zipName ('$actualZipName') does not match expected '$expectedZipName'."
}

$changelogPath = Join-Path $repoRoot "CHANGELOG.md"
if (Test-Path -LiteralPath $changelogPath) {
    $changelog = Get-Content -LiteralPath $changelogPath -Raw
    if ($changelog -notmatch [regex]::Escape("[$configVersion]")) {
        $issues += "CHANGELOG.md has no entry for version '$configVersion'."
    }
}

if ($Check) {
    if ($issues.Count -gt 0) {
        Write-Host "Version check FAILED:" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
        exit 1
    }

    Write-Host "Version check OK: EZOCore is at v$configVersion." -ForegroundColor Green
    exit 0
}

if ($NewVersion) {
    Write-Host "Bumping to $NewVersion is not fully automated yet." -ForegroundColor Yellow
    Write-Host "Update EZOCore.txt (## Version / ## AddOnVersion), ezo-addon.json (addon.version / package.zipName) and CHANGELOG.md manually, then re-run with -Check." -ForegroundColor Yellow
    exit 1
}

if ($issues.Count -gt 0) {
    $issues | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
} else {
    Write-Host "EZOCore is at v$configVersion. Everything is consistent." -ForegroundColor Green
}
