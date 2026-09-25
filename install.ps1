# ==============================================================================
# CLIProxyAPI Windows Native Installer (PowerShell)
# Architecture: x64 (amd64) and ARM64 (aarch64)
# Repository: https://github.com/tsaQB/cliproxyapi-installer
# ==============================================================================
$ErrorActionPreference = "Stop"

# Force TLS 1.2+ for older PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

Clear-Host -ErrorAction SilentlyContinue

Write-Host "____ _     ___ ____                      _    ____ ___ " -ForegroundColor Cyan
Write-Host "/ ___| |   |_ _|  _ \ _ __ _____  ___   _/ \  |  _ \_ _|" -ForegroundColor Cyan
Write-Host "| |   | |    | || |_) | '__/ _ \ \/ / | | / _ \ | |_) | | " -ForegroundColor Cyan
Write-Host "| |___| |___ | ||  __/| | | (_) >  <| |_| / ___ \|  __/| | " -ForegroundColor Cyan
Write-Host "\____|_____|___|_|   |_|  \___/_/\_\\__, /_/   \_\_|  |___|" -ForegroundColor Cyan
Write-Host "                                    |___/                  " -ForegroundColor Cyan
Write-Host "            Windows Native Service Installer               " -ForegroundColor DarkGray
Write-Host "                  Maintained by tsaQB                      `n" -ForegroundColor Magenta

# 1. Architecture Validation
Write-Host "[1/6] 🔍 Checking platform architecture..." -ForegroundColor Cyan
$arch = "amd64"
try {
    if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq [System.Runtime.InteropServices.Architecture]::Arm64) {
        $arch = "aarch64"
    }
} catch {
    $arch = "amd64"
}
Write-Host "      ✔ Compatible Windows architecture: $arch`n" -ForegroundColor Green

# 2. Directory Layout Setup
Write-Host "[2/6] 📁 Configuring workspace directories..." -ForegroundColor Cyan
$baseDir = "$env:USERPROFILE\.cliproxyapi"
$binDir = "$baseDir\bin"
$staticDir = "$baseDir\static"
$authDir = "$baseDir\auths"
$logDir = "$baseDir\logs"
$configFile = "$baseDir\config.yaml"

New-Item -ItemType Directory -Force -Path $binDir, $staticDir, $authDir, $logDir | Out-Null

# Handle running process before upgrade to avoid Windows file-locking errors
$wasRunning = $false
$runningProc = Get-Process -Name "cli-proxy-api" -ErrorAction SilentlyContinue
if ($runningProc) {
    $wasRunning = $true
    Write-Host "      🛑 Stopping active CLIProxyAPI process for upgrade..." -ForegroundColor Yellow
    Stop-Process -Name "cli-proxy-api" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}
Write-Host "      ✔ Directory layout ready at $baseDir`n" -ForegroundColor Green

# 3. Query Latest Release Tag (Rate-limit-free redirect resolution)
Write-Host "[3/6] 🌐 Resolving latest upstream release..." -ForegroundColor Cyan
$releaseTag = "v7.3.17"
try {
    $resp = Invoke-WebRequest -Uri "https://github.com/router-for-me/CLIProxyAPI/releases/latest" -MaximumRedirection 0 -UseBasicParsing -ErrorAction Stop
    $location = $resp.Headers["Location"]
    if ($location -is [array]) { $location = $location[0] }
    if ($location -match '/tag/([^/]+)$') {
        $releaseTag = $matches[1]
    }
} catch {
    $location = $null
    if ($_.Exception.Response) {
        try {
            $location = $_.Exception.Response.Headers["Location"]
            if ($location -is [array]) { $location = $location[0] }
        } catch {}
    }
    if ($location -and $location -match '/tag/([^/]+)$') {
        $releaseTag = $matches[1]
    } else {
        try {
            $releaseJson = Invoke-RestMethod -Uri "https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest" -Headers @{ "User-Agent" = "CLIProxyAPI-Installer" } -UseBasicParsing
            if ($releaseJson.tag_name) {
                $releaseTag = $releaseJson.tag_name
            }
        } catch {
            # Fallback to default release tag
        }
    }
}
$cleanTag = $releaseTag.TrimStart('v')
Write-Host "      • Upstream release: $releaseTag" -ForegroundColor DarkGray

# 4. Download Binary & WebUI Dashboard
Write-Host "[4/6] ⬇ Downloading official binary bundle and WebUI..." -ForegroundColor Cyan
$zipUrl = "https://github.com/router-for-me/CLIProxyAPI/releases/download/$releaseTag/CLIProxyAPI_${cleanTag}_windows_${arch}.zip"
$dashboardUrl = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/latest/download/management.html"
$tmpZip = "$env:TEMP\cliproxyapi_windows.zip"
$tmpExtract = "$env:TEMP\cliproxyapi_extract"

Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing
if (Test-Path $tmpExtract) { Remove-Item -Recurse -Force $tmpExtract }
Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force
Move-Item -Force "$tmpExtract\cli-proxy-api.exe" "$binDir\cli-proxy-api.exe"
Remove-Item -Force $tmpZip -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $tmpExtract -ErrorAction SilentlyContinue

try {
    Invoke-WebRequest -Uri $dashboardUrl -OutFile "$staticDir\management.html" -UseBasicParsing
} catch {
    Set-Content -Path "$staticDir\management.html" -Value "<!DOCTYPE html><html><head><title>CLIProxyAPI</title></head><body><h1>CLIProxyAPI Dashboard</h1></body></html>" -Encoding UTF8
}
Write-Host "      ✔ Windows binary and WebUI dashboard deployed`n" -ForegroundColor Green

# 5. Configuration Setup
Write-Host "[5/6] ⚙️  Configuring service profile..." -ForegroundColor Cyan
$adminKey = "admin123"
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
  secret-key: "$adminKey"
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
    Write-Host "      ✔ Config created (Secret: $adminKey)`n" -ForegroundColor Green
} else {
    Write-Host "      ✔ Existing configuration preserved: $configFile`n" -ForegroundColor Green
    $existingSecret = (Get-Content -Path $configFile -ErrorAction SilentlyContinue | Select-String -Pattern '^\s*secret-key:\s*"?([^"\r\n]+)"?' | ForEach-Object { $_.Matches.Groups[1].Value.Trim() } | Select-Object -First 1)
    if ($existingSecret) {
        $adminKey = $existingSecret
    }
}

# 6. Command Launcher and PATH Registration
Write-Host "[6/6] 🔗 Registering CLI command launcher and PATH..." -ForegroundColor Cyan

$cmdLauncher = "$binDir\cliproxyapi.cmd"
$cmdScript = @"
@echo off
setlocal
set "BASE_DIR=$baseDir"
set "BIN=$binDir\cli-proxy-api.exe"
set "CONFIG=$configFile"
set "LOG_FILE=$logDir\service.log"
set "MANAGEMENT_STATIC_PATH=$staticDir"

if "%~1"=="" goto help
if "%~1"=="start" goto start
if "%~1"=="stop" goto stop
if "%~1"=="restart" goto restart
if "%~1"=="status" goto status
if "%~1"=="logs" goto logs
if "%~1"=="log" goto logs
if "%~1"=="update" goto update
if "%~1"=="upgrade" goto update
if "%~1"=="run" goto run
goto passthrough

:start
tasklist /fi "imagename eq cli-proxy-api.exe" 2>NUL | find /i "cli-proxy-api.exe" >NUL
if not errorlevel 1 (
    echo [!] CLIProxyAPI is already running.
    exit /b 0
)
echo [*] Starting CLIProxyAPI background daemon...
powershell -NoProfile -WindowStyle Hidden -Command "Start-Process -FilePath '%BIN%' -ArgumentList '-config \"%CONFIG%\"' -WorkingDirectory '%BASE_DIR%' -RedirectStandardOutput '%LOG_FILE%' -RedirectStandardError '%LOG_FILE%'"
timeout /t 1 /nobreak >NUL
tasklist /fi "imagename eq cli-proxy-api.exe" 2>NUL | find /i "cli-proxy-api.exe" >NUL
if not errorlevel 1 (
    echo [v] CLIProxyAPI is running!
    echo Endpoint : http://127.0.0.1:8317
    echo Dashboard: http://127.0.0.1:8317/management.html
) else (
    echo [x] Failed to start. Check logs: %LOG_FILE%
)
exit /b 0

:stop
tasklist /fi "imagename eq cli-proxy-api.exe" 2>NUL | find /i "cli-proxy-api.exe" >NUL
if not errorlevel 1 (
    taskkill /f /im cli-proxy-api.exe >NUL 2>&1
    echo [v] CLIProxyAPI daemon stopped.
) else (
    echo [!] CLIProxyAPI is not running.
)
exit /b 0

:restart
call :stop
timeout /t 1 /nobreak >NUL
goto start

:status
tasklist /fi "imagename eq cli-proxy-api.exe" 2>NUL | find /i "cli-proxy-api.exe" >NUL
if not errorlevel 1 (
    echo [v] CLIProxyAPI is active
    echo Endpoint : http://127.0.0.1:8317
    echo Dashboard: http://127.0.0.1:8317/management.html
) else (
    echo [x] CLIProxyAPI is not running.
)
exit /b 0

:logs
powershell -NoProfile -Command "if (Test-Path '%LOG_FILE%') { Get-Content -Path '%LOG_FILE%' -Wait -Tail 50 } else { Write-Host 'No logs found yet.' }"
exit /b 0

:update
echo [*] Upgrading CLIProxyAPI via official installer...
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/tsaQB/cliproxyapi-installer/main/install.ps1 | iex"
exit /b 0

:run
set "ARGS=%*"
set "ARGS=%ARGS:*run=%"
"%BIN%" -config "%CONFIG%" %ARGS%
exit /b %errorlevel%

:passthrough
"%BIN%" -config "%CONFIG%" %*
exit /b %errorlevel%

:help
echo CLIProxyAPI Windows Commands:
echo   cliproxyapi start      - Launch service in background
echo   cliproxyapi stop       - Stop background service
echo   cliproxyapi restart    - Restart service daemon
echo   cliproxyapi status     - View service running status
echo   cliproxyapi logs       - Stream real-time service logs
echo   cliproxyapi update     - Upgrade to latest release
echo   cliproxyapi run        - Run in foreground console
echo   cliproxyapi ^<options^>  - Pass flags directly (e.g. -antigravity-login)
exit /b 0
"@
Set-Content -Path $cmdLauncher -Value $cmdScript -Encoding ASCII

# Add to User PATH if missing
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$binDir;$userPath", "User")
    $env:Path = "$binDir;$env:Path"
}
[Environment]::SetEnvironmentVariable("MANAGEMENT_STATIC_PATH", $staticDir, "User")
$env:MANAGEMENT_STATIC_PATH = $staticDir
Write-Host "      ✔ Command 'cliproxyapi' registered in PATH`n" -ForegroundColor Green

# Resume process if it was running before upgrade
if ($wasRunning) {
    Write-Host "      🔄 Resuming CLIProxyAPI in background..." -ForegroundColor Cyan
    Start-Process -FilePath "$binDir\cli-proxy-api.exe" -ArgumentList "-config `"$configFile`"" -WorkingDirectory $baseDir -RedirectStandardOutput "$logDir\service.log" -RedirectStandardError "$logDir\service.log" -WindowStyle Hidden
    Start-Sleep -Seconds 1
    if (Get-Process -Name "cli-proxy-api" -ErrorAction SilentlyContinue) {
        Write-Host "      ✔ Daemon resumed successfully`n" -ForegroundColor Green
    }
}

Write-Host "────────────────────────────────────────────────────" -ForegroundColor Green
Write-Host "  🎉 Installation Complete!" -ForegroundColor Green
Write-Host "────────────────────────────────────────────────────`n" -ForegroundColor Green
Write-Host "  • WebUI Dashboard : http://127.0.0.1:8317/management.html" -ForegroundColor Cyan
Write-Host "  • Secret Key      : $adminKey" -ForegroundColor Yellow
Write-Host "  • Configuration   : $configFile`n" -ForegroundColor DarkGray
Write-Host "  Quick Start Commands:" -ForegroundColor White
Write-Host "    $ cliproxyapi start   Start service in background" -ForegroundColor Cyan
Write-Host "    $ cliproxyapi status  Check server status" -ForegroundColor Cyan
Write-Host "    $ cliproxyapi logs    Stream live logs" -ForegroundColor Cyan
Write-Host "    $ cliproxyapi update  Upgrade to latest release" -ForegroundColor Cyan
Write-Host "    $ cliproxyapi stop    Stop background daemon`n" -ForegroundColor Cyan
Write-Host "────────────────────────────────────────────────────" -ForegroundColor Green
