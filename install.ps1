# ==============================================================================
# CLIProxyAPI Windows Native Installer (PowerShell)
# Architecture: x64 (amd64) and ARM64 (aarch64)
# Repository: https://github.com/tsaQB/cliproxyapi-installer
# ==============================================================================
$ErrorActionPreference = "Stop"

# Force TLS 1.2+ for older PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]'Tls13'
} catch {}

try { Clear-Host } catch {}

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
$authDirYaml = $authDir.Replace('\', '/')

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

auth-dir: "$authDirYaml"
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
    $existingYaml = Get-Content -Path $configFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($existingYaml) {
        # Auto-heal unescaped Windows backslashes in auth-dir from older versions
        if ($existingYaml -match 'auth-dir:\s*"([^"]*\\Users[^"]*)"') {
            $badAuth = $matches[1]
            $goodAuth = $badAuth.Replace('\', '/')
            $fixedYaml = $existingYaml.Replace("`"$badAuth`"", "`"$goodAuth`"")
            Set-Content -Path $configFile -Value $fixedYaml -Encoding UTF8
        }
        $existingSecret = ($existingYaml | Select-String -Pattern '^\s*secret-key:\s*["'']?([^#"''\r\n]+)["'']?' | ForEach-Object { $_.Matches.Groups[1].Value.Trim() } | Select-Object -First 1)
        if ($existingSecret) {
            $adminKey = $existingSecret
        }
    }
}

# 6. Command Launcher and PATH Registration
Write-Host "[6/6] 🔗 Registering CLI command launcher and PATH..." -ForegroundColor Cyan

# 6a. Generate PowerShell CLI Controller
$ps1Launcher = "$binDir\cliproxyapi.ps1"
$ps1Script = @'
<#
.SYNOPSIS
    CLIProxyAPI Management Utility for Windows (PowerShell & CMD)
#>
$baseDir = "$env:USERPROFILE\.cliproxyapi"
$binDir = "$baseDir\bin"
$bin = "$binDir\cli-proxy-api.exe"
$config = "$baseDir\config.yaml"
$logDir = "$baseDir\logs"
$logFile = "$logDir\service.log"
$staticDir = "$baseDir\static"

$env:MANAGEMENT_STATIC_PATH = $staticDir

function Get-DaemonProcess {
    Get-Process -Name "cli-proxy-api" -ErrorAction SilentlyContinue
}

$cmd = if ($args.Count -gt 0) { $args[0].ToLower() } else { "help" }

if ($args.Count -gt 0 -and $args[0].StartsWith("-")) {
    & $bin -config $config $args
    exit $LASTEXITCODE
}

switch ($cmd) {
    "start" {
        $p = Get-DaemonProcess
        if ($p) {
            Write-Host "[!] CLIProxyAPI is already running (PID: $($p.Id))." -ForegroundColor Yellow
            exit 0
        }
        Write-Host "[*] Starting CLIProxyAPI background daemon..." -ForegroundColor Cyan
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

        $cmdArg = "/c `"`"$bin`" -config `"$config`" >> `"$logFile`" 2>&1`""
        Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArg -WorkingDirectory $baseDir -WindowStyle Hidden
        Start-Sleep -Seconds 1

        $p = Get-DaemonProcess
        if ($p) {
            Write-Host "[v] CLIProxyAPI is running! (PID: $($p.Id))" -ForegroundColor Green
            Write-Host "    Endpoint  : http://127.0.0.1:8317" -ForegroundColor Cyan
            Write-Host "    Dashboard : http://127.0.0.1:8317/management.html" -ForegroundColor Cyan
        } else {
            Write-Host "[x] Failed to start. Check logs: $logFile" -ForegroundColor Red
            if (Test-Path $logFile) {
                Write-Host "`nLast log entries:" -ForegroundColor DarkGray
                Get-Content -Path $logFile -Tail 5 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
            }
        }
        exit 0
    }
    "stop" {
        $p = Get-DaemonProcess
        if ($p) {
            $p | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Host "[v] CLIProxyAPI daemon stopped." -ForegroundColor Green
        } else {
            Write-Host "[!] CLIProxyAPI is not running." -ForegroundColor Yellow
        }
        exit 0
    }
    "restart" {
        $p = Get-DaemonProcess
        if ($p) {
            $p | Stop-Process -Force -ErrorAction SilentlyContinue
            Write-Host "[v] CLIProxyAPI daemon stopped." -ForegroundColor Green
            Start-Sleep -Seconds 1
        }
        Write-Host "[*] Starting CLIProxyAPI background daemon..." -ForegroundColor Cyan
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

        $cmdArg = "/c `"`"$bin`" -config `"$config`" >> `"$logFile`" 2>&1`""
        Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArg -WorkingDirectory $baseDir -WindowStyle Hidden
        Start-Sleep -Seconds 1

        $p = Get-DaemonProcess
        if ($p) {
            Write-Host "[v] CLIProxyAPI is running! (PID: $($p.Id))" -ForegroundColor Green
            Write-Host "    Endpoint  : http://127.0.0.1:8317" -ForegroundColor Cyan
            Write-Host "    Dashboard : http://127.0.0.1:8317/management.html" -ForegroundColor Cyan
        } else {
            Write-Host "[x] Failed to start. Check logs: $logFile" -ForegroundColor Red
        }
        exit 0
    }
    "status" {
        $p = Get-DaemonProcess
        if ($p) {
            $mem = [math]::Round($p.WorkingSet64 / 1MB, 2)
            Write-Host "[v] CLIProxyAPI is active" -ForegroundColor Green
            Write-Host "    PID       : $($p.Id)" -ForegroundColor White
            Write-Host "    Memory    : $mem MB" -ForegroundColor White
            Write-Host "    Endpoint  : http://127.0.0.1:8317" -ForegroundColor Cyan
            Write-Host "    Dashboard : http://127.0.0.1:8317/management.html" -ForegroundColor Cyan
        } else {
            Write-Host "[x] CLIProxyAPI is not running." -ForegroundColor Red
        }
        exit 0
    }
    { $_ -in "logs", "log" } {
        if (Test-Path $logFile) {
            Write-Host "Streaming live logs from $logFile (Ctrl+C to exit)..." -ForegroundColor DarkGray
            Get-Content -Path $logFile -Wait -Tail 50
        } else {
            Write-Host "No logs found yet at $logFile" -ForegroundColor Yellow
        }
        exit 0
    }
    { $_ -in "update", "upgrade" } {
        Write-Host "[*] Upgrading CLIProxyAPI via official installer..." -ForegroundColor Cyan
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::SecurityProtocol -bor [Net.SecurityProtocolType]'Tls13'
        } catch {}
        Invoke-Expression (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/tsaQB/cliproxyapi-installer/main/install.ps1" -UseBasicParsing)
        exit 0
    }
    "run" {
        $remaining = if ($args.Count -gt 1) { $args[1..($args.Count-1)] } else { @() }
        & $bin -config $config $remaining
        exit $LASTEXITCODE
    }
    "help" {
        Write-Host "CLIProxyAPI Windows Commands:" -ForegroundColor White
        Write-Host "  cliproxyapi start      - Launch service in background" -ForegroundColor Cyan
        Write-Host "  cliproxyapi stop       - Stop background service" -ForegroundColor Cyan
        Write-Host "  cliproxyapi restart    - Restart service daemon" -ForegroundColor Cyan
        Write-Host "  cliproxyapi status     - View service running status" -ForegroundColor Cyan
        Write-Host "  cliproxyapi logs       - Stream real-time service logs" -ForegroundColor Cyan
        Write-Host "  cliproxyapi update     - Upgrade to latest release" -ForegroundColor Cyan
        Write-Host "  cliproxyapi run        - Run in foreground console" -ForegroundColor Cyan
        Write-Host "  cliproxyapi <options>  - Pass flags directly (e.g. -antigravity-login)" -ForegroundColor Cyan
        exit 0
    }
    default {
        & $bin -config $config $args
        exit $LASTEXITCODE
    }
}
'@
Set-Content -Path $ps1Launcher -Value $ps1Script -Encoding UTF8

# 6b. Generate Command Prompt Forwarder (.cmd)
$cmdLauncher = "$binDir\cliproxyapi.cmd"
$cmdScript = @"
@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cliproxyapi.ps1" %*
exit /b %errorlevel%
"@
Set-Content -Path $cmdLauncher -Value $cmdScript -Encoding ASCII

# 6c. Generate Git Bash / MSYS2 Forwarder (extensionless)
$shLauncher = "$binDir\cliproxyapi"
$shScript = @'
#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${SCRIPT_DIR}/cliproxyapi.ps1" "$@"
exit $?
'@
Set-Content -Path $shLauncher -Value $shScript -Encoding ASCII

# Add to User PATH if missing
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$pathEntries = if ($userPath) { $userPath -split ';' } else { @() }
if ($pathEntries -notcontains $binDir) {
    $newPath = if ($userPath) { "$binDir;$userPath" } else { $binDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = "$binDir;$env:Path"
}
[Environment]::SetEnvironmentVariable("MANAGEMENT_STATIC_PATH", $staticDir, "User")
$env:MANAGEMENT_STATIC_PATH = $staticDir
Write-Host "      ✔ Command 'cliproxyapi' registered in PATH`n" -ForegroundColor Green

# Resume process if it was running before upgrade
if ($wasRunning) {
    Write-Host "      🔄 Resuming CLIProxyAPI in background..." -ForegroundColor Cyan
    $resumeArg = "/c `"`"$binDir\cli-proxy-api.exe`" -config `"$configFile`" >> `"$logDir\service.log`" 2>&1`""
    Start-Process -FilePath "cmd.exe" -ArgumentList $resumeArg -WorkingDirectory $baseDir -WindowStyle Hidden
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
