# ==============================================================================
# CLIProxyAPI Windows Installer (PowerShell)
# Repository: https://github.com/tsaQB/cliproxyapi-installer
# ==============================================================================
$ErrorActionPreference = "Stop"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "     CLIProxyAPI Windows Installer (Preview)        " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$baseDir = "$env:USERPROFILE\.cliproxyapi"
$binDir = "$baseDir\bin"
$staticDir = "$baseDir\static"
$authDir = "$baseDir\auths"
$logDir = "$baseDir\logs"
$configFile = "$baseDir\config.yaml"

New-Item -ItemType Directory -Force -Path $binDir, $staticDir, $authDir, $logDir | Out-Null

# 1. Detect Architecture
$arch = "amd64"
try {
    if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq [System.Runtime.InteropServices.Architecture]::Arm64) {
        $arch = "aarch64"
    }
} catch {
    $arch = "amd64"
}
Write-Host "[1/5] Detected architecture: Windows ($arch)" -ForegroundColor Green

# 2. Query Latest Release
Write-Host "[2/5] Fetching latest release from GitHub..." -ForegroundColor Cyan
$releaseTag = "v7.3.17"
try {
    $releaseJson = Invoke-RestMethod -Uri "https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest" -Headers @{ "User-Agent" = "CLIProxyAPI-Installer" } -UseBasicParsing
    if ($releaseJson.tag_name) {
        $releaseTag = $releaseJson.tag_name
    }
} catch {
    Write-Host "Using default release tag: $releaseTag" -ForegroundColor Yellow
}
$cleanTag = $releaseTag.TrimStart('v')

$zipUrl = "https://github.com/router-for-me/CLIProxyAPI/releases/download/$releaseTag/CLIProxyAPI_${cleanTag}_windows_${arch}.zip"
$dashboardUrl = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/latest/download/management.html"
$tmpZip = "$env:TEMP\cliproxyapi_windows.zip"
$tmpExtract = "$env:TEMP\cliproxyapi_extract"

# 3. Download Binary and WebUI
Write-Host "[3/5] Downloading binary and WebUI dashboard..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing
if (Test-Path $tmpExtract) { Remove-Item -Recurse -Force $tmpExtract }
Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force
Move-Item -Force "$tmpExtract\cli-proxy-api.exe" "$binDir\cli-proxy-api.exe"
Remove-Item -Force $tmpZip
Remove-Item -Recurse -Force $tmpExtract

Invoke-WebRequest -Uri $dashboardUrl -OutFile "$staticDir\management.html" -UseBasicParsing
Write-Host "✔ Binary and WebUI deployed" -ForegroundColor Green

# 4. Configuration Setup
Write-Host "[4/5] Setting up configuration profile..." -ForegroundColor Cyan
if (-not (Test-Path $configFile)) {
    $bytes = New-Object byte[] 16
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $randomKey = ($bytes | ForEach-Object { "{0:x2}" -f $_ }) -join ''

    $yamlContent = @"
# CLIProxyAPI Windows Configuration
host: "0.0.0.0"
port: 8317

api-keys:
  - "$randomKey"

remote-management:
  allow-remote: true
  secret-key: "admin123"
  disable-control-panel: false
  panel-github-repository: "https://github.com/router-for-me/Cli-Proxy-API-Management-Center"

auth-dir: "$authDir"
log-level: "info"
logging-to-file: true
logs-max-total-size-mb: 50
usage-statistics-enabled: true

routing:
  strategy: "round-robin"

# Prevent false 429 rate limit triggers from Google Antigravity sensor
antigravity:
  sensitive-words:
    - Nous
    - Research

# Model alias mappings for Hermes tool calling compatibility
oauth-model-alias:
  antigravity:
    - name: "gemini-3.8-flash-high"
      alias: "gemini-3.8-flash"
      fork: true
    - name: "gemini-3.8-flash-high"
      alias: "gemini-3.8-flash-customtools"
      fork: true
"@
    Set-Content -Path $configFile -Value $yamlContent -Encoding UTF8
    Write-Host "✔ Default configuration created with secret: admin123" -ForegroundColor Green
} else {
    Write-Host "✔ Existing configuration preserved: $configFile" -ForegroundColor Green
}

# 5. Create CLI Command Launcher
Write-Host "[5/5] Registering command launcher..." -ForegroundColor Cyan
$cmdLauncher = "$binDir\cliproxyapi.cmd"
$cmdScript = @"
@echo off
set "MANAGEMENT_STATIC_PATH=$staticDir"
if "%~1"=="" (
    start "" "$binDir\cli-proxy-api.exe" -config "$configFile"
    echo CLIProxyAPI started in background.
    echo Dashboard: http://127.0.0.1:8317/management.html
) else if "%~1"=="run" (
    shift
    "$binDir\cli-proxy-api.exe" -config "$configFile" %*
) else (
    "$binDir\cli-proxy-api.exe" -config "$configFile" %*
)
"@
Set-Content -Path $cmdLauncher -Value $cmdScript

# Append to User PATH if missing
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$binDir;$userPath", "User")
    Write-Host "✔ Added $binDir to User PATH" -ForegroundColor Green
}

Write-Host ""
Write-Host "────────────────────────────────────────────────────" -ForegroundColor Green
Write-Host "  🎉 Installation Complete!" -ForegroundColor Green
Write-Host "────────────────────────────────────────────────────" -ForegroundColor Green
Write-Host "  • WebUI Dashboard : http://127.0.0.1:8317/management.html"
Write-Host "  • Default Secret  : admin123"
Write-Host "  • Configuration   : $configFile"
Write-Host ""
Write-Host "  Command to run:"
Write-Host "    cliproxyapi run     (Run in terminal)"
Write-Host "    cliproxyapi         (Run in background)"
Write-Host "────────────────────────────────────────────────────" -ForegroundColor Green
