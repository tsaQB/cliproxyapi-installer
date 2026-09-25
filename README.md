# CLIProxyAPI Universal Installer

[![License](https://img.shields.io/github/license/tsaQB/cliproxyapi-installer?style=flat-square&color=f59e0b)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Termux%20%7C%20Windows-emerald?style=flat-square)](#supported-platforms)
[![Service](https://img.shields.io/badge/Service-Systemd%20%7C%20Daemon%20CLI-38bdf8?style=flat-square)](#quick-management-commands)

One-line universal installer and service manager for [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) and the [Management Center WebUI](https://github.com/router-for-me/Cli-Proxy-API-Management-Center).

---

## ⚡ Quick Install

### 🐧 Linux & 📱 Android (Termux)

Run this single command in your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/tsaQB/cliproxyapi-installer/main/install.sh | bash
```

The script automatically detects your operating system and CPU architecture, downloads the correct binary and WebUI dashboard, generates default configuration, and registers the `cliproxyapi` CLI service command.

---

### 🪟 Windows (PowerShell)

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/tsaQB/cliproxyapi-installer/main/install.ps1 | iex
```

---

## 🎯 Supported Platforms & Architectures

| Operating System | Architecture | Binary Distribution | Service Type | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Linux (Ubuntu, Debian, Arch, CentOS, Fedora, etc.)** | `x86_64` (amd64) | Upstream Official | Systemd (System / User) | ✅ Supported |
| **Linux (Raspberry Pi, Cloud ARM, Graviton)** | `aarch64` (arm64) | Upstream Official | Systemd (System / User) | ✅ Supported |
| **Android (Termux Non-Root)** | `aarch64` (arm64) | [tsaQB/cliproxyapi-android](https://github.com/tsaQB/cliproxyapi-android) (NDK Bionic) | Background Daemon CLI | ✅ Supported |
| **Windows 10 / 11 / Server** | `x64` / `ARM64` | Upstream Official | Windows Launcher & PATH | ✅ Supported |
| **macOS (Apple Silicon & Intel)** | `arm64` / `x86_64` | Upstream Official | Launchd / User Daemon | ⏳ Coming Soon |

> **Why a custom build for Android?**  
> Generic Linux static Go binaries fail on Android because `/etc/resolv.conf` does not exist, causing Google OAuth token exchange to fail with connection refused. For Android, the installer deploys our native Android NDK Bionic libc build with 100% native DNS resolution.

---

## 🛠️ Quick Management Commands

After installation, use the `cliproxyapi` command to control your proxy service:

```bash
cliproxyapi start      # Start background service
cliproxyapi status     # Check service health and running port
cliproxyapi logs       # Follow live service logs
cliproxyapi update     # In-place upgrade binary & dashboard
cliproxyapi restart    # Restart service daemon
cliproxyapi stop       # Stop background service
cliproxyapi run        # Run in foreground console
```

---

## 🌐 WebUI Dashboard & Credentials

* **WebUI URL:** `http://127.0.0.1:8317/management.html`
* **Default Secret:** `admin123`
* **Port:** `8317`
* **Pre-configured Fixes:**
  - **Antigravity Sensor:** Pre-filtered sensitive words (`Nous`, `Research`) to avoid false HTTP 429 rate limit triggers.
  - **Hermes Tool Calling:** Pre-configured model alias mapping for `gemini-3.8-flash-high`.

---

## 🔄 Updating to Latest Releases

To update your binary and WebUI dashboard without losing existing keys, tokens, or configuration:

```bash
cliproxyapi update
```

Or simply re-run the one-line installer anytime.

---

## 📄 License

Distributed under the [MIT License](LICENSE).
Maintained by [tsaQB](https://github.com/tsaQB).
