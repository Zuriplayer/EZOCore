[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
    if ($PSScriptRoot) {
        return (Get-Item -LiteralPath (Join-Path $PSScriptRoot "..\..")).FullName
    }
    return (Get-Location).Path
}

$repoRoot = Get-RepoRoot
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $repoRoot "ezo-addon.json"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$addon = $config.addon
$package = if ($addon.package) { $addon.package } else { $config.package }
if (-not $package) {
    throw "Package configuration not found in ezo-addon.json."
}

$outputDir = Join-Path $repoRoot $package.outputPath
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$zipPath = Join-Path $outputDir $package.zipName
if ((Test-Path -LiteralPath $zipPath) -and $Force) {
    Remove-Item -LiteralPath $zipPath -Force
}
if (Test-Path -LiteralPath $zipPath) {
    throw "Package already exists: $zipPath (use -Force to overwrite)"
}

function Test-PathMatchesAnyPattern {
    param(
        [string]$RelativePath,
        [string[]]$Patterns
    )

    $normalized = $RelativePath -replace "\\", "/"
    foreach ($pattern in $Patterns) {
        if ($normalized -like $pattern) {
            return $true
        }
    }
    return $false
}

$allFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -File
$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
$packageRoot = Join-Path $stagingRoot $package.rootFolderName
New-Item -ItemType Directory -Path $packageRoot | Out-Null

foreach ($file in $allFiles) {
    $relativePath = $file.FullName.Substring($repoRoot.Length).TrimStart("\", "/")

    if (Test-PathMatchesAnyPattern -RelativePath $relativePath -Patterns $package.exclude) {
        continue
    }
    if (-not (Test-PathMatchesAnyPattern -RelativePath $relativePath -Patterns $package.include)) {
        continue
    }

    $destination = Join-Path $packageRoot $relativePath
    $destinationDir = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $file.FullName -Destination $destination -Force
}

Compress-Archive -Path $packageRoot -DestinationPath $zipPath -Force
Remove-Item -LiteralPath $stagingRoot -Recurse -Force

$result = [ordered]@{
    ZipPath = $zipPath
    Addon = $addon.name
    Version = $addon.version
}
$result | ConvertTo-Json
