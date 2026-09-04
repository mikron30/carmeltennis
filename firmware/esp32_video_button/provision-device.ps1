param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_-]{1,64}$')]
    [string]$DeviceId,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 3)]
    [int]$CourtNumber,

    [string]$WifiSsid,
    [switch]$ReuseWifiFromConfig,
    [string]$ProjectId = 'potent-howl-228108',
    [switch]$Rotate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-CppString {
    param([string]$Value)
    return $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n')
}

function New-DeviceSecret {
    $bytes = New-Object byte[] 32
    $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $random.GetBytes($bytes)
    } finally {
        $random.Dispose()
    }
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Get-ConfiguredWifiValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigText,

        [Parameter(Mandatory = $true)]
        [ValidateSet('WIFI_SSID', 'WIFI_PASSWORD')]
        [string]$Name
    )

    $pattern = 'constexpr\s+char\s+' + [regex]::Escape($Name) +
        '\[\]\s*=\s*"((?:\\.|[^"\\])*)"\s*;'
    $match = [regex]::Match($ConfigText, $pattern)
    if (-not $match.Success) {
        throw "Could not read $Name from the existing device_config.h."
    }
    return [regex]::Unescape($match.Groups[1].Value)
}

if (-not (Get-Command gcloud.cmd -ErrorAction SilentlyContinue)) {
    throw 'gcloud.cmd is required and must be authenticated for the Firebase project.'
}
if (-not (Get-Command firebase.cmd -ErrorAction SilentlyContinue)) {
    throw 'firebase.cmd is required and must be authenticated for the Firebase project.'
}

$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDirectory '..\..')).Path
$configPath = Join-Path $scriptDirectory 'device_config.h'

if ($ReuseWifiFromConfig) {
    if (-not [string]::IsNullOrWhiteSpace($WifiSsid)) {
        throw 'Do not combine -WifiSsid with -ReuseWifiFromConfig.'
    }
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw 'Cannot reuse Wi-Fi because device_config.h does not exist.'
    }
    $existingConfigText = Get-Content -Raw -LiteralPath $configPath
    $WifiSsid = Get-ConfiguredWifiValue -ConfigText $existingConfigText -Name WIFI_SSID
    $wifiPassword = Get-ConfiguredWifiValue -ConfigText $existingConfigText -Name WIFI_PASSWORD
} else {
    if ([string]::IsNullOrWhiteSpace($WifiSsid)) {
        $WifiSsid = Read-Host '2.4 GHz Wi-Fi SSID'
    }
    if ([string]::IsNullOrWhiteSpace($WifiSsid)) {
        throw 'Wi-Fi SSID cannot be empty.'
    }

    $secureWifiPassword = Read-Host 'Wi-Fi password (input is hidden)' -AsSecureString
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureWifiPassword)
    try {
        $wifiPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    }
}

if ([string]::IsNullOrWhiteSpace($WifiSsid)) {
    throw 'Wi-Fi SSID cannot be empty.'
}

$functionEnvironment = Join-Path $repoRoot "functions\.env.$ProjectId"
if (-not (Test-Path -LiteralPath $functionEnvironment)) {
    throw "Missing $functionEnvironment. Create it from functions\.env.example before deployment."
}

$secretName = 'ESP32_VIDEO_DEVICE_KEYS'
$existingJsonLines = & gcloud.cmd secrets versions access latest `
    "--secret=$secretName" "--project=$ProjectId" 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "Could not read $secretName from project $ProjectId. Create it first or check gcloud authentication."
}
$existingJson = $existingJsonLines -join "`n"
$existingObject = $existingJson | ConvertFrom-Json
$configuration = [ordered]@{}
foreach ($property in $existingObject.PSObject.Properties) {
    $configuration[$property.Name] = $property.Value
}
if ($configuration.Contains($DeviceId) -and -not $Rotate) {
    throw "Device '$DeviceId' already exists. Use -Rotate only when intentionally replacing its key."
}

$deviceSecret = New-DeviceSecret
$configuration[$DeviceId] = [ordered]@{
    secret = $deviceSecret
    courts = @($CourtNumber)
}

$temporarySecretFile = Join-Path ([IO.Path]::GetTempPath()) `
    ("esp32-device-keys-{0}.json" -f [Guid]::NewGuid().ToString('N'))
try {
    $updatedJson = $configuration | ConvertTo-Json -Depth 8 -Compress
    [IO.File]::WriteAllText(
        $temporarySecretFile,
        $updatedJson,
        (New-Object Text.UTF8Encoding($false)))

    & gcloud.cmd secrets versions add $secretName `
        "--data-file=$temporarySecretFile" "--project=$ProjectId"
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to add the new device-key secret version.'
    }
} finally {
    if (Test-Path -LiteralPath $temporarySecretFile) {
        Remove-Item -LiteralPath $temporarySecretFile -Force
    }
}

$configText = @"
#pragma once

// Generated locally by provision-device.ps1. Never commit or share this file.
constexpr char WIFI_SSID[] = "$(ConvertTo-CppString $WifiSsid)";
constexpr char WIFI_PASSWORD[] = "$(ConvertTo-CppString $wifiPassword)";
constexpr uint8_t COURT_NUMBER = $CourtNumber;
constexpr char DEVICE_ID[] = "$(ConvertTo-CppString $DeviceId)";
constexpr char DEVICE_SECRET[] = "$(ConvertTo-CppString $deviceSecret)";
constexpr int BUTTON_GPIO = 27;
constexpr int STATUS_LED_GPIO = 26;
constexpr bool STATUS_LED_ACTIVE_HIGH = true;
"@
[IO.File]::WriteAllText(
    $configPath,
    $configText,
    (New-Object Text.UTF8Encoding($false)))

# A Cloud Function revision is bound to a specific Secret Manager version, so
# publishing the new version is not enough: redeploy the physical endpoint.
Push-Location $repoRoot
try {
    Remove-Item Env:DEBUG -ErrorAction SilentlyContinue
    $env:FUNCTIONS_DISCOVERY_TIMEOUT = '60'
    & firebase.cmd deploy --only functions:requestVideoClip `
        "--project=$ProjectId" --non-interactive
    if ($LASTEXITCODE -ne 0) {
        throw 'Secret created, but requestVideoClip deployment failed. Do not flash until deployment succeeds.'
    }
} finally {
    Pop-Location
}

Write-Host ''
Write-Host "Provisioned '$DeviceId' for court $CourtNumber."
Write-Host "Created ignored firmware config: $configPath"
Write-Host 'The device secret was not printed. Open the sketch and upload it now.'
