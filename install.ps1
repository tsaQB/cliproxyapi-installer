# ==============================================================================
# CLIProxyAPI Windows Native Installer (PowerShell)
# Architecture: x64 (amd64) and ARM64 (aarch64)
# Repository: https://github.com/tsaQB/cliproxyapi-installer
# ==============================================================================
# NOTE: This script is usually run via "irm ... | iex", so it must never call
# "exit" (that would close the user's PowerShell window). Errors are thrown.

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest is very slow with the progress bar in PS 5.1

$upstreamRepo  = "router-for-me/CLIProxyAPI"
$dashboardRepo = "router-for-me/Cli-Proxy-API-Management-Center"
$fallbackTag   = "v8.0.13"
$defaultPort   = "8317"
$defaultSecret = "admin123"

# Force TLS 1.2+ for older PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]'Tls13'
} catch {}

$utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-Utf8File([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Get-YamlValue([string]$Yaml, [string]$Key) {
    $m = [regex]::Match($Yaml, "(?m)^\s*$([regex]::Escape($Key)):[ \t]*(.*?)\s*$")
    if (-not $m.Success) { return $null }
    $value = ($m.Groups[1].Value -replace '\s+#.*$', '').Trim()
    if ($value.Length -ge 2 -and (($value[0] -eq '"' -and $value[-1] -eq '"') -or ($value[0] -eq "'" -and $value[-1] -eq "'"))) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    return $value
}

function Get-FirstApiKey([string]$Yaml) {
    $m = [regex]::Match($Yaml, "(?m)^\s*api-keys:\s*\r?\n\s*-\s*(.+?)\s*$")
    if (-not $m.Success) { return $null }
    $value = ($m.Groups[1].Value -replace '\s+#.*$', '').Trim().Trim('"').Trim("'")
    return $value
}

function Format-Secret([string]$Secret) {
    if ([string]::IsNullOrEmpty($Secret)) { return "(empty - Management API disabled)" }
    if ($Secret -match '^\$2[aby]\$') { return "(hashed - use the secret you set earlier)" }
    return $Secret
}

try { Clear-Host } catch {}

Write-Host "  ____ _     ___ ____                      _    ____ ___" -ForegroundColor Cyan
Write-Host " / ___| |   |_ _|  _ \ _ __ _____  ___   _/ \  |  _ \_ _|" -ForegroundColor Cyan
Write-Host "| |   | |    | || |_) | '__/ _ \ \/ / | | / _ \ | |_) | |" -ForegroundColor Cyan
Write-Host "| |___| |___ | ||  __/| | | (_) >  <| |_| / ___ \|  __/| |" -ForegroundColor Cyan
Write-Host " \____|_____|___|_|   |_|  \___/_/\_\\__, /_/   \_\_|  |___|" -ForegroundColor Cyan
Write-Host "                                     |___/" -ForegroundColor Cyan
Write-Host "            Windows Native Service Installer" -ForegroundColor DarkGray
Write-Host "                  Maintained by tsaQB`n" -ForegroundColor Magenta

# 1. Architecture Validation
Write-Host "[1/6] 🔍 Checking platform architecture..." -ForegroundColor Cyan
$arch = $null
try {
    switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()) {
        "X64"   { $arch = "amd64" }
        "Arm64" { $arch = "aarch64" }
    }
} catch {}
if (-not $arch) {
    # Fallback for older .NET: PROCESSOR_ARCHITEW6432 is set for 32-bit processes on 64-bit Windows
    $procArch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    switch ($procArch) {
        "AMD64" { $arch = "amd64" }
        "ARM64" { $arch = "aarch64" }
    }
}
if (-not $arch) {
    Write-Host "      ❌ Unsupported architecture. Supported: x64, ARM64`n" -ForegroundColor Red
    throw "Unsupported Windows architecture."
}
Write-Host "      ✔ Compatible Windows architecture: $arch`n" -ForegroundColor Green

# 2. Directory Layout Setup
Write-Host "[2/6] 📁 Configuring workspace directories..." -ForegroundColor Cyan
$baseDir    = Join-Path $env:USERPROFILE ".cliproxyapi"
$binDir     = Join-Path $baseDir "bin"
$staticDir  = Join-Path $baseDir "static"
$authDir    = Join-Path $baseDir "auths"
$logDir     = Join-Path $baseDir "logs"
$configFile = Join-Path $baseDir "config.yaml"
$binPath    = Join-Path $binDir "cli-proxy-api.exe"
$logFile    = Join-Path $logDir "service.log"
$dashboardFile = Join-Path $staticDir "management.html"

New-Item -ItemType Directory -Force -Path $binDir, $staticDir, $authDir, $logDir | Out-Null

# Stop our running process before upgrading to avoid Windows file-locking errors
$wasRunning = $false
$runningProc = Get-Process -Name "cli-proxy-api" -ErrorAction SilentlyContinue |
    Where-Object { -not $_.Path -or $_.Path -eq $binPath }
if ($runningProc) {
    $wasRunning = $true
    Write-Host "      🛑 Stopping active CLIProxyAPI process for upgrade..." -ForegroundColor Yellow
    $runningProc | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}
Write-Host "      ✔ Directory layout ready at $baseDir`n" -ForegroundColor Green

# 3. Query Latest Release Tag (rate-limit-free redirect resolution)
Write-Host "[3/6] 🌐 Resolving latest upstream release..." -ForegroundColor Cyan
$releaseTag = $null
try {
    $req = [System.Net.HttpWebRequest]::Create("https://github.com/$upstreamRepo/releases/latest")
    $req.Method = "HEAD"
    $req.AllowAutoRedirect = $false
    $req.UserAgent = "CLIProxyAPI-Installer"
    $resp = $req.GetResponse()
    $location = $resp.Headers["Location"]
    $resp.Close()
    if ($location -match '/tag/([^/?#]+)$') { $releaseTag = $matches[1] }
} catch {}
if (-not $releaseTag) {
    try {
        $releaseJson = Invoke-RestMethod -Uri "https://api.github.com/repos/$upstreamRepo/releases/latest" -Headers @{ "User-Agent" = "CLIProxyAPI-Installer" } -UseBasicParsing
        if ($releaseJson.tag_name) { $releaseTag = $releaseJson.tag_name }
    } catch {}
}
if (-not $releaseTag) {
    $releaseTag = $fallbackTag
    Write-Host "      ⚠️  Could not resolve the latest release; using fallback $fallbackTag" -ForegroundColor Yellow
}
$cleanTag = $releaseTag.TrimStart('v')
Write-Host "      • Upstream release: $releaseTag`n" -ForegroundColor DarkGray

# 4. Download Binary & WebUI Dashboard
Write-Host "[4/6] ⬇ Downloading official binary bundle and WebUI..." -ForegroundColor Cyan
$zipUrl = "https://github.com/$upstreamRepo/releases/download/$releaseTag/CLIProxyAPI_${cleanTag}_windows_${arch}.zip"
$dashboardUrl = "https://github.com/$dashboardRepo/releases/latest/download/management.html"
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("cliproxyapi_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

try {
    $tmpZip = Join-Path $tmpDir "cliproxyapi_windows.zip"
    $tmpExtract = Join-Path $tmpDir "extract"
    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing
    } catch {
        Write-Host "      ❌ Failed to download binary archive from $zipUrl`n" -ForegroundColor Red
        throw
    }
    Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force
    $exe = Get-ChildItem -Path $tmpExtract -Recurse -Filter "cli-proxy-api.exe" | Select-Object -First 1
    if (-not $exe) { throw "Binary 'cli-proxy-api.exe' not found inside the release archive." }
    Move-Item -Force $exe.FullName $binPath

    $tmpDashboard = Join-Path $tmpDir "management.html"
    $dashboardOk = $false
    try {
        Invoke-WebRequest -Uri $dashboardUrl -OutFile $tmpDashboard -UseBasicParsing
        $dashboardOk = (Test-Path $tmpDashboard) -and ((Get-Item $tmpDashboard).Length -gt 0)
    } catch {}
    if ($dashboardOk) {
        Move-Item -Force $tmpDashboard $dashboardFile
    } elseif ((Test-Path $dashboardFile) -and ((Get-Item $dashboardFile).Length -gt 0)) {
        Write-Host "      ⚠️  Dashboard download failed. Keeping the existing dashboard." -ForegroundColor Yellow
    } else {
        Write-Host "      ⚠️  Dashboard download failed. Creating fallback placeholder..." -ForegroundColor Yellow
        Write-Utf8File $dashboardFile '<!DOCTYPE html><html><head><meta charset="utf-8"><title>CLIProxyAPI</title></head><body><h1>CLIProxyAPI Dashboard</h1><p>Please update your dashboard from <a href="https://github.com/router-for-me/Cli-Proxy-API-Management-Center">Management Center</a>.</p></body></html>'
    }
} finally {
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
}
Write-Host "      ✔ Windows binary and WebUI dashboard deployed`n" -ForegroundColor Green

# 5. Configuration Setup
Write-Host "[5/6] ⚙️  Configuring service profile..." -ForegroundColor Cyan
$authDirYaml = $authDir.Replace('\', '/')

if (-not (Test-Path $configFile)) {
    $bytes = New-Object byte[] 16
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $newApiKey = ($bytes | ForEach-Object { "{0:x2}" -f $_ }) -join ''

    $yamlContent = @"
# CLIProxyAPI Windows Configuration
host: "0.0.0.0"
port: $defaultPort

api-keys:
  - "$newApiKey"

remote-management:
  allow-remote: true
  secret-key: "$defaultSecret"
  disable-control-panel: false
  panel-github-repository: "https://github.com/$dashboardRepo"

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
    Write-Utf8File $configFile ($yamlContent -replace "`r`n", "`n")
    Write-Host "      ✔ Config created: $configFile`n" -ForegroundColor Green
} else {
    Write-Host "      ✔ Existing configuration preserved: $configFile`n" -ForegroundColor Green
    $rawBytes = [System.IO.File]::ReadAllBytes($configFile)
    $hasBom = $rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF
    $existingYaml = [System.IO.File]::ReadAllText($configFile)
    $fixedYaml = $existingYaml
    # Auto-heal unescaped Windows backslashes in a double-quoted auth-dir from older versions
    $authMatch = [regex]::Match($fixedYaml, '(?m)^(\s*auth-dir:\s*)"([^"]*\\[^"]*)"')
    if ($authMatch.Success) {
        $fixedYaml = $fixedYaml.Remove($authMatch.Index, $authMatch.Length).Insert($authMatch.Index, $authMatch.Groups[1].Value + '"' + $authMatch.Groups[2].Value.Replace('\', '/') + '"')
    }
    # Older versions wrote the config with a UTF-8 BOM; rewrite without it
    if ($hasBom -or $fixedYaml -ne $existingYaml) {
        Write-Utf8File $configFile $fixedYaml
    }
}

$configYaml = [System.IO.File]::ReadAllText($configFile)
$adminKey = Get-YamlValue $configYaml "secret-key"
$apiKey = Get-FirstApiKey $configYaml
$port = Get-YamlValue $configYaml "port"
if ($port -notmatch '^\d+$') { $port = $defaultPort }

# 6. Command Launcher and PATH Registration
Write-Host "[6/6] 🔗 Registering CLI command launcher and PATH..." -ForegroundColor Cyan

# 6a. Generate PowerShell CLI Controller
$ps1Launcher = Join-Path $binDir "cliproxyapi.ps1"
$ps1Script = @'
<#
.SYNOPSIS
    CLIProxyAPI Management Utility for Windows (PowerShell & CMD)
    Generated by cliproxyapi-installer.
#>
$baseDir   = Join-Path $env:USERPROFILE ".cliproxyapi"
$binDir    = Join-Path $baseDir "bin"
$bin       = Join-Path $binDir "cli-proxy-api.exe"
$config    = Join-Path $baseDir "config.yaml"
$logDir    = Join-Path $baseDir "logs"
$logFile   = Join-Path $logDir "service.log"
$staticDir = Join-Path $baseDir "static"
$installerUrl = "https://raw.githubusercontent.com/tsaQB/cliproxyapi-installer/main/install.ps1"

$env:MANAGEMENT_STATIC_PATH = $staticDir

function Get-DaemonProcess {
    Get-Process -Name "cli-proxy-api" -ErrorAction SilentlyContinue |
        Where-Object { -not $_.Path -or $_.Path -eq $bin } |
        Select-Object -First 1
}

function Get-Port {
    $m = Select-String -Path $config -Pattern '^\s*port:\s*["'']?(\d+)' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($m) { return $m.Matches[0].Groups[1].Value }
    return "8317"
}

function Show-Endpoints {
    $port = Get-Port
    Write-Host "    Endpoint  : http://127.0.0.1:$port" -ForegroundColor Cyan
    Write-Host "    Dashboard : http://127.0.0.1:$port/management.html" -ForegroundColor Cyan
}

function Start-Daemon {
    $p = Get-DaemonProcess
    if ($p) {
        Write-Host "[!] CLIProxyAPI is already running (PID: $($p.Id))." -ForegroundColor Yellow
        return $true
    }
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    Write-Host "[*] Starting CLIProxyAPI background daemon..." -ForegroundColor Cyan
    $cmdArg = "/c `"`"$bin`" -config `"$config`" >> `"$logFile`" 2>&1`""
    Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArg -WorkingDirectory $baseDir -WindowStyle Hidden
    Start-Sleep -Seconds 1
    $p = Get-DaemonProcess
    if ($p) {
        Write-Host "[v] CLIProxyAPI is running! (PID: $($p.Id))" -ForegroundColor Green
        Show-Endpoints
        return $true
    }
    Write-Host "[x] Failed to start. Check logs: $logFile" -ForegroundColor Red
    if (Test-Path $logFile) {
        Write-Host "`nLast log entries:" -ForegroundColor DarkGray
        Get-Content -Path $logFile -Tail 5 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    }
    return $false
}

function Stop-Daemon {
    $p = Get-DaemonProcess
    if (-not $p) {
        Write-Host "[!] CLIProxyAPI is not running." -ForegroundColor Yellow
        return
    }
    Get-Process -Name "cli-proxy-api" -ErrorAction SilentlyContinue |
        Where-Object { -not $_.Path -or $_.Path -eq $bin } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "[v] CLIProxyAPI daemon stopped." -ForegroundColor Green
}

if ($args.Count -gt 0 -and "$($args[0])".StartsWith("-")) {
    & $bin -config $config @args
    exit $LASTEXITCODE
}

$cmd = if ($args.Count -gt 0) { "$($args[0])".ToLower() } else { "help" }

switch ($cmd) {
    "start" {
        if (Start-Daemon) { exit 0 } else { exit 1 }
    }
    "stop" {
        Stop-Daemon
        exit 0
    }
    "restart" {
        Stop-Daemon
        Start-Sleep -Seconds 1
        if (Start-Daemon) { exit 0 } else { exit 1 }
    }
    "status" {
        $p = Get-DaemonProcess
        if ($p) {
            $mem = [math]::Round($p.WorkingSet64 / 1MB, 2)
            Write-Host "[v] CLIProxyAPI is running" -ForegroundColor Green
            Write-Host "    PID       : $($p.Id)" -ForegroundColor White
            Write-Host "    Memory    : $mem MB" -ForegroundColor White
            Show-Endpoints
            exit 0
        }
        Write-Host "[x] CLIProxyAPI is not running." -ForegroundColor Red
        exit 1
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
        Write-Host "[*] Updating CLIProxyAPI via official installer..." -ForegroundColor Cyan
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]'Tls13'
        } catch {}
        try {
            $installer = Invoke-RestMethod -Uri $installerUrl -UseBasicParsing
        } catch {
            Write-Host "[x] Failed to download the installer from $installerUrl" -ForegroundColor Red
            exit 1
        }
        Invoke-Expression $installer
        exit 0
    }
    "run" {
        $remaining = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }
        & $bin -config $config @remaining
        exit $LASTEXITCODE
    }
    "help" {
        Write-Host "CLIProxyAPI Management Commands:" -ForegroundColor White
        Write-Host "  cliproxyapi start      - Start service in background" -ForegroundColor Cyan
        Write-Host "  cliproxyapi stop       - Stop background service" -ForegroundColor Cyan
        Write-Host "  cliproxyapi restart    - Restart service" -ForegroundColor Cyan
        Write-Host "  cliproxyapi status     - View service status, PID, and endpoints" -ForegroundColor Cyan
        Write-Host "  cliproxyapi logs       - Stream real-time service logs" -ForegroundColor Cyan
        Write-Host "  cliproxyapi update     - Upgrade binary and WebUI to latest release" -ForegroundColor Cyan
        Write-Host "  cliproxyapi run        - Run in foreground console" -ForegroundColor Cyan
        Write-Host "  cliproxyapi <options>  - Pass flags directly (e.g. -antigravity-login)" -ForegroundColor Cyan
        exit 0
    }
    default {
        & $bin -config $config @args
        exit $LASTEXITCODE
    }
}
'@
Write-Utf8File $ps1Launcher $ps1Script

# 6b. Generate Command Prompt Forwarder (.cmd)
$cmdLauncher = Join-Path $binDir "cliproxyapi.cmd"
$cmdScript = "@echo off`r`nsetlocal`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0cliproxyapi.ps1`" %*`r`nexit /b %errorlevel%`r`n"
[System.IO.File]::WriteAllText($cmdLauncher, $cmdScript, [System.Text.Encoding]::ASCII)

# 6c. Generate Git Bash / MSYS2 Forwarder (extensionless, LF line endings)
$shLauncher = Join-Path $binDir "cliproxyapi"
$shScript = @'
#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
PS1_PATH="${SCRIPT_DIR}/cliproxyapi.ps1"
# powershell.exe needs a Windows path, not an MSYS path like /c/Users/...
if command -v cygpath >/dev/null 2>&1; then
    PS1_PATH="$(cygpath -w "$PS1_PATH")"
fi
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS1_PATH" "$@"
'@
[System.IO.File]::WriteAllText($shLauncher, ($shScript -replace "`r`n", "`n"), [System.Text.Encoding]::ASCII)

# Add to User PATH if missing
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$pathEntries = if ($userPath) { $userPath -split ';' | ForEach-Object { $_.TrimEnd('\') } } else { @() }
if ($pathEntries -notcontains $binDir.TrimEnd('\')) {
    $newPath = if ($userPath) { "$binDir;$userPath" } else { $binDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
}
if (($env:Path -split ';') -notcontains $binDir) {
    $env:Path = "$binDir;$env:Path"
}
[Environment]::SetEnvironmentVariable("MANAGEMENT_STATIC_PATH", $staticDir, "User")
$env:MANAGEMENT_STATIC_PATH = $staticDir
Write-Host "      ✔ Command 'cliproxyapi' registered in PATH" -ForegroundColor Green

# Resume process if it was running before upgrade
if ($wasRunning) {
    Write-Host "      🔄 Resuming CLIProxyAPI in background..." -ForegroundColor Cyan
    $resumeArg = "/c `"`"$binPath`" -config `"$configFile`" >> `"$logFile`" 2>&1`""
    Start-Process -FilePath "cmd.exe" -ArgumentList $resumeArg -WorkingDirectory $baseDir -WindowStyle Hidden
    Start-Sleep -Seconds 1
    if (Get-Process -Name "cli-proxy-api" -ErrorAction SilentlyContinue | Where-Object { -not $_.Path -or $_.Path -eq $binPath }) {
        Write-Host "      ✔ Daemon resumed successfully" -ForegroundColor Green
    } else {
        Write-Host "      ⚠️  Could not resume daemon. Check logs: $logFile" -ForegroundColor Yellow
    }
}
Write-Host ""

$apiKeyDisplay = if ($apiKey) { $apiKey } else { "(none configured)" }

Write-Host "────────────────────────────────────────────────────" -ForegroundColor Green
Write-Host "  🎉 Installation Complete!" -ForegroundColor Green
Write-Host "────────────────────────────────────────────────────`n" -ForegroundColor Green
Write-Host "  • WebUI Dashboard : http://127.0.0.1:$port/management.html" -ForegroundColor Cyan
Write-Host "  • Secret Key      : $(Format-Secret $adminKey)" -ForegroundColor Yellow
Write-Host "  • Client API Key  : $apiKeyDisplay" -ForegroundColor White
Write-Host "  • Configuration   : $configFile`n" -ForegroundColor DarkGray
Write-Host "  Quick Start Commands:" -ForegroundColor White
Write-Host "    $ cliproxyapi start   Start service in background" -ForegroundColor Cyan
Write-Host "    $ cliproxyapi status  Check service status" -ForegroundColor Cyan
Write-Host "    $ cliproxyapi logs    Stream live logs" -ForegroundColor Cyan
Write-Host "    $ cliproxyapi update  Upgrade to latest release" -ForegroundColor Cyan
Write-Host "    $ cliproxyapi stop    Stop background service`n" -ForegroundColor Cyan
Write-Host "────────────────────────────────────────────────────" -ForegroundColor Green
