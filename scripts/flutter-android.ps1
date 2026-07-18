param(
    [string]$DeviceId = "emulator-5554",
    [switch]$Profile
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $repoRoot ".env"
$frontendPath = Join-Path $repoRoot "frontend"

if (-not (Test-Path $envPath)) {
    throw "Missing .env file at $envPath"
}

$values = @{}
Get-Content $envPath | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith("#") -or -not $line.Contains("=")) {
        return
    }

    $key, $value = $line.Split("=", 2)
    $values[$key.Trim()] = $value.Trim().Trim('"').Trim("'")
}

$serverClientId = $values["GOOGLE_OAUTH_SERVER_CLIENT_ID"]
if ([string]::IsNullOrWhiteSpace($serverClientId)) {
    throw "GOOGLE_OAUTH_SERVER_CLIENT_ID is missing in .env"
}

$apiBaseUrl = $values["ANDROID_API_BASE_URL"]
if ([string]::IsNullOrWhiteSpace($apiBaseUrl)) {
    $apiBaseUrl = "http://10.0.2.2:8000/api/v1"
}

$androidStudioJava = "C:\Program Files\Android\Android Studio\jbr"
if (Test-Path (Join-Path $androidStudioJava "bin\java.exe")) {
    $env:JAVA_HOME = $androidStudioJava
    $env:Path = "$androidStudioJava\bin;$env:Path"
}

$modeArgs = @()
if ($Profile) {
    $modeArgs += "--profile"
}

Push-Location $frontendPath
try {
    flutter run @modeArgs `
        -d $DeviceId `
        --dart-define="GOOGLE_OAUTH_SERVER_CLIENT_ID=$serverClientId" `
        --dart-define="API_BASE_URL=$apiBaseUrl"
}
finally {
    Pop-Location
}
