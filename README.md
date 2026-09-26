# CLIProxyAPI Universal Installer

[![License](https://img.shields.io/github/license/tsaQB/cliproxyapi-installer?style=flat-square&color=f59e0b)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Termux%20%7C%20Windows-emerald?style=flat-square)](#-supported-platforms--architectures)
[![Service](https://img.shields.io/badge/Service-Systemd%20%7C%20Daemon%20%7C%20Windows%20Process-38bdf8?style=flat-square)](#%EF%B8%8F-quick-management-commands)

One-line universal installer, lifecycle service manager, and updater for [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) and the [Management Center WebUI](https://github.com/router-for-me/Cli-Proxy-API-Management-Center).

---

## ⚡ Quick Install

### 🐧 Linux & 📱 Android (Termux)

Run this single command in your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/tsaQB/cliproxyapi-installer/main/install.sh | bash
```
*(On minimal distributions without `bash`, such as Alpine Linux, pipe into `sh` instead).*

The installer automatically detects your operating system, CPU architecture, and environment privileges. It downloads the correct native binary and WebUI dashboard, generates default configuration (or preserves existing profiles), and registers the `cliproxyapi` command into your `PATH`.

---

### 🪟 Windows (PowerShell)

Open PowerShell (Windows 10, 11, or Server) and run:

```powershell
irm https://raw.githubusercontent.com/tsaQB/cliproxyapi-installer/main/install.ps1 | iex
```

The installer detects AMD64 or ARM64, deploys the official Windows executable and WebUI, configures background service controls (`cliproxyapi.cmd`), registers the binary into your User `PATH`, and exports necessary static environment variables.

---

## 🎯 Supported Platforms & Architectures

| Operating System | Architecture | Binary Distribution | Service Manager | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Linux (Ubuntu, Debian, Arch, Fedora, RHEL, Alpine)** | `x86_64` (amd64) | Upstream Official | Systemd (System/User) or Daemon Fallback | ✅ Supported |
| **Linux (Raspberry Pi, Cloud ARM64, Graviton)** | `aarch64` (arm64) | Upstream Official | Systemd (System/User) or Daemon Fallback | ✅ Supported |
| **Android (Termux Non-Root)** | `aarch64` (arm64) | [tsaQB/cliproxyapi-android](https://github.com/tsaQB/cliproxyapi-android) (NDK Bionic) | Background Daemon CLI (`setsid`) | ✅ Supported |
| **Windows 10 / 11 / Server** | `x64` / `ARM64` | Upstream Official | Windows Background Process (`cliproxyapi.cmd`) | ✅ Supported |
| **macOS (Apple Silicon & Intel)** | `arm64` / `x86_64` | Upstream Official | Launchd / User Daemon | ⏳ Coming Soon |

> [!NOTE]
> **Why a dedicated build for Android (Termux)?**  
> Generic Linux static Go binaries fail on Android because `/etc/resolv.conf` does not exist, causing Google OAuth token exchange to fail with connection refused errors. For Android, this installer delegates to our native Android NDK Bionic libc build ([`tsaQB/cliproxyapi-android`](https://github.com/tsaQB/cliproxyapi-android)) for 100% native DNS resolution.

---

## 🛠️ Quick Management Commands

After installation, use the `cliproxyapi` command across all platforms (Linux, Termux, Windows PowerShell/CMD):

```bash
cliproxyapi start        # Start service in background
cliproxyapi status       # View service status, PID, and active ports
cliproxyapi logs         # Stream real-time service logs
cliproxyapi restart      # Restart service daemon
cliproxyapi stop         # Stop background service
cliproxyapi run          # Run in foreground console
cliproxyapi update       # In-place upgrade binary and WebUI dashboard
cliproxyapi <options>    # Pass flags directly to engine (e.g. -antigravity-login)
```

---

## 🔑 Provider Authentication & OAuth Login

Authenticate your model providers directly from the terminal:

```bash
# Antigravity (Google / Gemini)
cliproxyapi -antigravity-login -no-browser

# Claude
cliproxyapi -claude-login -no-browser

# OpenAI / Codex
cliproxyapi -codex-device-login

# Kimi
cliproxyapi -kimi-login -no-browser

# xAI (Grok)
cliproxyapi -xai-login -no-browser
```

*(You can also configure and log in to providers through the Management Center WebUI).*

---

## 📁 System Paths Reference

| Component | Linux (Root) | Linux (User-Space) | Android (Termux) | Windows |
| :--- | :--- | :--- | :--- | :--- |
| **Binary Executable** | `/usr/local/bin/cli-proxy-api` | `~/.local/bin/cli-proxy-api` | `~/.cliproxyapi/bin/cli-proxy-api` | `%USERPROFILE%\.cliproxyapi\bin\cli-proxy-api.exe` |
| **CLI Command** | `/usr/local/bin/cliproxyapi` | `~/.local/bin/cliproxyapi` | `$PREFIX/bin/cliproxyapi` | `%USERPROFILE%\.cliproxyapi\bin\cliproxyapi.cmd` |
| **Configuration** | `/etc/cliproxyapi/config.yaml` | `~/.cliproxyapi/config.yaml` | `~/.cliproxyapi/config.yaml` | `%USERPROFILE%\.cliproxyapi\config.yaml` |
| **WebUI Dashboard** | `/var/lib/cliproxyapi/static/` | `~/.cliproxyapi/static/` | `~/.cliproxyapi/static/` | `%USERPROFILE%\.cliproxyapi\static\` |
| **OAuth Credentials** | `/var/lib/cliproxyapi/auths/` | `~/.cliproxyapi/auths/` | `~/.cliproxyapi/auths/` | `%USERPROFILE%\.cliproxyapi\auths\` |
| **Service Logs** | Systemd Journal / `service.log` | `~/.cliproxyapi/logs/service.log` | `~/.cliproxyapi/logs/service.log` | `%USERPROFILE%\.cliproxyapi\logs\service.log` |

---

## 🌐 WebUI Dashboard & Credentials

* **WebUI URL:** `http://127.0.0.1:8317/management.html`
* **Default Secret (Password):** `admin123` *(Preserved automatically if customized)*
* **Default Port:** `8317`
* **Pre-configured Enhancements:**
  - **Antigravity Sensor Protection:** Pre-filters sensitive words (`Nous`, `Research`) to avoid false HTTP 429 rate limit triggers.
  - **Hermes Tool Calling:** Pre-configured model alias mapping for `gemini-3.8-flash-high` (`gemini-3.8-flash` and `gemini-3.8-flash-customtools`).

---

## 🔄 Updating to Latest Releases

To update your binary and WebUI dashboard to the latest release while strictly preserving existing configuration, API keys, and authenticated OAuth tokens:

```bash
cliproxyapi update
```

Or re-run the one-line installer anytime. Existing profiles and credentials will remain untouched.

---

## 📄 License

Distributed under the [MIT License](LICENSE).  
Maintained by [tsaQB](https://github.com/tsaQB).
