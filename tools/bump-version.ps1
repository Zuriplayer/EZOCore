param(
    [string] $Version,

    [int] $AddOnVersion,

    [switch] $Patch,

    [switch] $Check,

    [string] $ApiVersion
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).ProviderPath
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Read-Text {
    param([Parameter(Mandatory = $true)][string] $Path)
    return [System.IO.File]::ReadAllText($Path, $utf8)
}

function Write-Text {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)][string] $Content
    )
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Get-RegexValue {
    param(
        [Parameter(Mandatory = $true)][string] $Content,
        [Parameter(Mandatory = $true)][string] $Pattern
    )
    $match = [regex]::Match($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups[1].Value
}

function Set-RegexValue {
    param(
        [Parameter(Mandatory = $true)][string] $Content,
        [Parameter(Mandatory = $true)][string] $Pattern,
        [Parameter(Mandatory = $true)][string] $Value
    )
    return [regex]::Replace($Content, $Pattern, {
        param($match)
        return $match.Groups[1].Value + $Value + $match.Groups[2].Value
    }, [System.Text.RegularExpressions.RegexOptions]::Multiline)
}

function Increment-PatchVersion {
    param([Parameter(Mandatory = $true)][string] $CurrentVersion)
    $parts = $CurrentVersion.Split(".")
    if ($parts.Count -ne 3) {
        throw "Cannot patch-bump non-semver version '$CurrentVersion'. Pass -Version explicitly."
    }
    $patchNumber = 0
    if (-not [int]::TryParse($parts[2], [ref]$patchNumber)) {
        throw "Cannot patch-bump version '$CurrentVersion'. Pass -Version explicitly."
    }
    return "$($parts[0]).$($parts[1]).$($patchNumber + 1)"
}

function Get-ApiVersionTokens {
    param([string] $Value)
    if (-not $Value) {
        return @()
    }
    return @($Value -split '\s+' | Where-Object { $_ })
}

function Test-ApiVersionList {
    param(
        [Parameter(Mandatory = $true)][string[]] $Tokens,
        [Parameter(Mandatory = $true)][string] $Label
    )
    if ($Tokens.Count -eq 0) {
        throw "$Label must contain at least one API version."
    }
    if ($Tokens.Count -gt 2) {
        throw "$Label contains $($Tokens.Count) API versions. ESO only honors the first 2 entries."
    }
    foreach ($token in $Tokens) {
        if ($token -notmatch '^\d+$') {
            throw "$Label contains invalid API version '$token'."
        }
    }
}

function Get-PackageConfig {
    param([Parameter(Mandatory = $true)] $Config)
    if ($Config.addon.package) {
        return $Config.addon.package
    }
    return $Config.package
}

function Write-Json {
    param(
        [Parameter(Mandatory = $true)][string] $Path,
        [Parameter(Mandatory = $true)] $Value
    )
    $json = $Value | ConvertTo-Json -Depth 20
    Write-Text $Path ($json + "`n")
}

$manifest = Join-Path $root "EZOCore.txt"
$core = Join-Path $root "EZOCore.lua"
$configPath = Join-Path $root "ezo-addon.json"
$changelogPath = Join-Path $root "CHANGELOG.md"

foreach ($path in @($manifest, $core, $configPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required file not found: $path"
    }
}

$manifestText = Read-Text $manifest
$coreText = Read-Text $core
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$package = Get-PackageConfig $config

if (-not $package) {
    throw "Package configuration not found in ezo-addon.json."
}

$manifestVersion = Get-RegexValue $manifestText '^## Version:\s*(.+?)\s*$'
$manifestAddOnVersion = Get-RegexValue $manifestText '^## AddOnVersion:\s*(\d+)\s*$'
$manifestApiVersion = Get-RegexValue $manifestText '^## APIVersion:\s*(.+?)\s*$'
$coreVersion = Get-RegexValue $coreText '^\s*EZOCore\.version\s*=\s*"([^"]+)"\s*$'
$configVersion = $config.addon.version
$expectedZipName = "EZOCore_v$configVersion.zip"

if ($Check) {
    $ok = $true
    if ($manifestVersion -ne $coreVersion) {
        Write-Error "Version mismatch: EZOCore.txt=$manifestVersion EZOCore.lua=$coreVersion"
        $ok = $false
    }
    if ($manifestVersion -ne $configVersion) {
        Write-Error "Version mismatch: EZOCore.txt=$manifestVersion ezo-addon.json=$configVersion"
        $ok = $false
    }
    if ($package.zipName -ne $expectedZipName) {
        Write-Error "Zip name mismatch: ezo-addon.json='$($package.zipName)' expected '$expectedZipName'"
        $ok = $false
    }
    if (-not $manifestAddOnVersion) {
        Write-Error "Missing ## AddOnVersion in EZOCore.txt"
        $ok = $false
    }

    $manifestApiTokens = Get-ApiVersionTokens $manifestApiVersion
    try {
        Test-ApiVersionList $manifestApiTokens "## APIVersion"
    } catch {
        Write-Error $_
        $ok = $false
    }

    if ($ApiVersion) {
        $expectedApiTokens = Get-ApiVersionTokens $ApiVersion
        try {
            Test-ApiVersionList $expectedApiTokens "-ApiVersion"
            foreach ($expectedApiToken in $expectedApiTokens) {
                if ($manifestApiTokens -notcontains $expectedApiToken) {
                    Write-Error "APIVersion mismatch: EZOCore.txt='$manifestApiVersion' does not include expected API '$expectedApiToken'"
                    $ok = $false
                }
            }
        } catch {
            Write-Error $_
            $ok = $false
        }
    }

    if (Test-Path -LiteralPath $changelogPath) {
        $changelog = Read-Text $changelogPath
        if ($changelog -notmatch [regex]::Escape("[$configVersion]")) {
            Write-Error "CHANGELOG.md has no entry for version '$configVersion'."
            $ok = $false
        }
    }

    if (-not $ok) {
        exit 1
    }

    Write-Host "Version check OK: $manifestVersion / AddOnVersion $manifestAddOnVersion / APIVersion $manifestApiVersion"
    if (-not $ApiVersion) {
        Write-Host "Pass -ApiVersion <GetAPIVersion()> to verify the AddOns screen out-of-date flag against a known client API."
    }
    exit 0
}

if ($Patch) {
    if ($Version) {
        throw "Use either -Patch or -Version, not both."
    }
    $Version = Increment-PatchVersion $manifestVersion
}

if (-not $Version) {
    throw "Pass -Version <x.y.z>, or use -Patch, or use -Check."
}

if ($manifestVersion -ne $coreVersion -or $manifestVersion -ne $configVersion) {
    throw "Refusing to bump from inconsistent state: EZOCore.txt=$manifestVersion EZOCore.lua=$coreVersion ezo-addon.json=$configVersion"
}

if (-not $PSBoundParameters.ContainsKey("AddOnVersion")) {
    $currentAddOnVersion = 0
    if (-not [int]::TryParse($manifestAddOnVersion, [ref]$currentAddOnVersion)) {
        throw "Cannot read current ## AddOnVersion. Pass -AddOnVersion explicitly."
    }
    $AddOnVersion = $currentAddOnVersion + 1
}

$manifestText = Set-RegexValue $manifestText '^(## Version:\s*).+?(\s*)$' $Version
$manifestText = Set-RegexValue $manifestText '^(## AddOnVersion:\s*)\d+(\s*)$' ([string]$AddOnVersion)
if ($ApiVersion) {
    $apiTokens = Get-ApiVersionTokens $ApiVersion
    Test-ApiVersionList $apiTokens "-ApiVersion"
    $manifestText = Set-RegexValue $manifestText '^(## APIVersion:\s*).+?(\s*)$' $ApiVersion
}
Write-Text $manifest $manifestText

$coreText = Set-RegexValue $coreText '^(\s*EZOCore\.version\s*=\s*")[^"]+("\s*)$' $Version
Write-Text $core $coreText

$config.addon.version = $Version
$package.zipName = "EZOCore_v$Version.zip"
Write-Json $configPath $config

Write-Host "Version updated to $Version / AddOnVersion $AddOnVersion"
if ($ApiVersion) {
    Write-Host "APIVersion updated to $ApiVersion"
} else {
    Write-Host "APIVersion unchanged: $manifestApiVersion"
}
Write-Host "Review with: git diff --check; git diff"
