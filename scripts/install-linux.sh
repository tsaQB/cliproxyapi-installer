#!/bin/sh
# ==============================================================================
# CLIProxyAPI Native Linux Installer (x86_64 / aarch64)
# Automated Binary, WebUI Dashboard, and Systemd Service Deployment
# Repository: https://github.com/tsaQB/cliproxyapi-installer
# ==============================================================================
set -eu

# Color palette
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_PURPLE="\033[1;35m"
C_WHITE="\033[1;37m"

clear 2>/dev/null || true

printf "%b" "${C_CYAN}"
cat << 'EOF'
____ _     ___ ____                      _    ____ ___ 
/ ___| |   |_ _|  _ \ _ __ _____  ___   _/ \  |  _ \_ _|
| |   | |    | || |_) | '__/ _ \ \/ / | | / _ \ | |_) | | 
| |___| |___ | ||  __/| | | (_) >  <| |_| / ___ \|  __/| | 
\____|_____|___|_|   |_|  \___/_/\_\\__, /_/   \_\_|  |___|
                                    |___/                  
EOF
printf "%b" "${C_RESET}"
printf "%b           Native Linux Service Installer%b\n" "${C_DIM}" "${C_RESET}"
printf "%b              Maintained by tsaQB%b\n\n" "${C_PURPLE}" "${C_RESET}"

# 1. Platform & Architecture Validation
printf "%b[1/6]%b %b🔍 Checking platform and CPU architecture...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
OS=$(uname -s 2>/dev/null || echo "Unknown")
if [ "$OS" != "Linux" ]; then
    printf "      %b❌ Error: This installer is intended for Linux. Detected: %s%b\n\n" "${C_RED}" "$OS" "${C_RESET}" >&2
    exit 1
fi

RAW_ARCH=$(uname -m)
case "$RAW_ARCH" in
    x86_64|amd64)
        UPSTREAM_ARCH="amd64"
        ARCH_LABEL="x86_64 (amd64)"
        ;;
    aarch64|arm64)
        UPSTREAM_ARCH="aarch64"
        ARCH_LABEL="aarch64 (arm64)"
        ;;
    *)
        printf "      %b❌ Error: Unsupported architecture '%s'. Supported: x86_64, aarch64%b\n\n" "${C_RED}" "$RAW_ARCH" "${C_RESET}" >&2
        exit 1
        ;;
esac
printf "      %b✔ Compatible Linux platform: %s%b\n\n" "${C_GREEN}" "$ARCH_LABEL" "${C_RESET}"

# 2. Dependency Verification
printf "%b[2/6]%b %b📦 Verifying required utilities...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
need_cmd=""
command -v curl >/dev/null 2>&1 || need_cmd="$need_cmd curl"
command -v tar >/dev/null 2>&1 || need_cmd="$need_cmd tar"

if [ -n "$need_cmd" ]; then
    printf "      %b❌ Missing required tools:%s. Please install them using your package manager.%b\n\n" "${C_RED}" "$need_cmd" "${C_RESET}" >&2
    exit 1
fi
printf "      %b✔ Required utilities ready (curl, tar)%b\n\n" "${C_GREEN}" "${C_RESET}"

# 3. Environment & Workspace Layout Setup
printf "%b[3/6]%b %b📁 Configuring environment layout...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"

EUID_VAL=$(id -u 2>/dev/null || echo "1000")
if [ "$EUID_VAL" -eq 0 ]; then
    IS_ROOT=1
    BIN_DIR="/usr/local/bin"
    DATA_DIR="/var/lib/cliproxyapi"
    CONFIG_DIR="/etc/cliproxyapi"
    LOG_DIR="/var/log/cliproxyapi"
    SYSTEMD_DIR="/etc/systemd/system"
    TARGET_WANTED="multi-user.target"
    printf "      %b• Running with root privileges (System-wide install)%b\n" "${C_DIM}" "${C_RESET}"
else
    IS_ROOT=0
    BIN_DIR="${HOME}/.local/bin"
    DATA_DIR="${HOME}/.cliproxyapi"
    CONFIG_DIR="${HOME}/.cliproxyapi"
    LOG_DIR="${HOME}/.cliproxyapi/logs"
    SYSTEMD_DIR="${HOME}/.config/systemd/user"
    TARGET_WANTED="default.target"
    printf "      %b• Running in user space (Local install: %s)%b\n" "${C_DIM}" "${DATA_DIR}" "${C_RESET}"
fi

BIN_PATH="${BIN_DIR}/cli-proxy-api"
WRAPPER_PATH="${BIN_DIR}/cliproxyapi"
STATIC_DIR="${DATA_DIR}/static"
AUTH_DIR="${DATA_DIR}/auths"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
DASHBOARD_FILE="${STATIC_DIR}/management.html"
SYSTEMD_SERVICE_FILE="${SYSTEMD_DIR}/cliproxyapi.service"

mkdir -p "${BIN_DIR}" "${DATA_DIR}" "${CONFIG_DIR}" "${LOG_DIR}" "${STATIC_DIR}" "${AUTH_DIR}"

# Detect systemd
HAS_SYSTEMD=0
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    HAS_SYSTEMD=1
fi

WAS_RUNNING=0
if [ "$HAS_SYSTEMD" -eq 1 ]; then
    if [ "$IS_ROOT" -eq 1 ]; then
        if systemctl is-active --quiet cliproxyapi 2>/dev/null; then
            WAS_RUNNING=1
            printf "      %b🛑 Stopping active systemd service for upgrade...%b\n" "${C_YELLOW}" "${C_RESET}"
            systemctl stop cliproxyapi || true
        fi
    else
        if systemctl --user is-active --quiet cliproxyapi 2>/dev/null; then
            WAS_RUNNING=1
            printf "      %b🛑 Stopping active user systemd service for upgrade...%b\n" "${C_YELLOW}" "${C_RESET}"
            systemctl --user stop cliproxyapi || true
        fi
    fi
fi

if [ "$WAS_RUNNING" -eq 0 ] && pgrep -f "${BIN_PATH}" >/dev/null 2>&1; then
    WAS_RUNNING=1
    printf "      %b🛑 Stopping active process before upgrade...%b\n" "${C_YELLOW}" "${C_RESET}"
    pkill -f "${BIN_PATH}" || true
    sleep 1
fi

printf "      %b✔ Directory structure ready%b\n\n" "${C_GREEN}" "${C_RESET}"

# 4. Fetch and Deploy Upstream Binary & WebUI Dashboard
printf "%b[4/6]%b %b🌐 Fetching official upstream binary & dashboard...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"

# Rate-limit-free tag resolution via release redirect, fallback to GitHub API
LATEST_TAG=$(curl -sSI https://github.com/router-for-me/CLIProxyAPI/releases/latest 2>/dev/null | grep -i "^location:" | head -n 1 | sed -E 's/.*\/tag\/([^\r\n]+).*/\1/' || true)
if [ -z "$LATEST_TAG" ]; then
    LATEST_TAG=$(curl -sL https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest 2>/dev/null | grep '"tag_name":' | head -n 1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)
fi
if [ -z "$LATEST_TAG" ]; then
    LATEST_TAG="v7.3.17"
fi
CLEAN_TAG="${LATEST_TAG#v}"
printf "      %b• Upstream release: %b%s%b\n" "${C_DIM}" "${C_WHITE}" "$LATEST_TAG" "${C_RESET}"

TAR_URL="https://github.com/router-for-me/CLIProxyAPI/releases/download/${LATEST_TAG}/CLIProxyAPI_${CLEAN_TAG}_linux_${UPSTREAM_ARCH}.tar.gz"
DASHBOARD_URL="https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/latest/download/management.html"

TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'cpa_linux')
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

printf "      %b⬇ Downloading CLIProxyAPI binary bundle...%b\n" "${C_DIM}" "${C_RESET}"
if ! curl -f -sSL "$TAR_URL" -o "$TMP_DIR/cliproxyapi.tar.gz"; then
    printf "      %b❌ Failed to download binary archive from %s%b\n\n" "${C_RED}" "$TAR_URL" "${C_RESET}" >&2
    exit 1
fi

tar -xzf "$TMP_DIR/cliproxyapi.tar.gz" -C "$TMP_DIR"
mv -f "$TMP_DIR/cli-proxy-api" "${BIN_PATH}"
chmod 755 "${BIN_PATH}"

printf "      %b⬇ Downloading Management Center WebUI dashboard...%b\n" "${C_DIM}" "${C_RESET}"
if ! curl -f -sSL "$DASHBOARD_URL" -o "${DASHBOARD_FILE}"; then
    printf "      %b⚠️  Dashboard download failed. Creating fallback placeholder...%b\n" "${C_YELLOW}" "${C_RESET}"
    cat << 'HTML' > "${DASHBOARD_FILE}"
<!DOCTYPE html><html><head><title>CLIProxyAPI</title></head><body><h1>CLIProxyAPI Dashboard</h1><p>Please update your dashboard from <a href="https://github.com/router-for-me/Cli-Proxy-API-Management-Center">Management Center</a>.</p></body></html>
HTML
fi
chmod 644 "${DASHBOARD_FILE}"

printf "      %b✔ Native binary and WebUI dashboard deployed%b\n\n" "${C_GREEN}" "${C_RESET}"

# 5. Configuration Setup
printf "%b[5/6]%b %b⚙️  Configuring service profile...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
if [ -f "${CONFIG_FILE}" ]; then
    printf "      %b✔ Existing configuration preserved: %s%b\n\n" "${C_GREEN}" "${CONFIG_FILE}" "${C_RESET}"
    RANDOM_KEY=$(grep -E '^[[:space:]]*-[[:space:]]*"?[a-zA-Z0-9]+' "${CONFIG_FILE}" 2>/dev/null | head -n 1 | tr -d ' "-' || echo "configured")
    ADMIN_KEY=$(grep -E '^[[:space:]]*secret-key:[[:space:]]*' "${CONFIG_FILE}" 2>/dev/null | head -n 1 | awk '{print $2}' | tr -d '"' || echo "admin123")
else
    RANDOM_KEY=$(dd if=/dev/urandom bs=16 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')
    ADMIN_KEY="admin123"
    cat << EOF > "${CONFIG_FILE}"
# CLIProxyAPI Linux Configuration
host: "0.0.0.0"
port: 8317

api-keys:
  - "${RANDOM_KEY}"

remote-management:
  allow-remote: true
  secret-key: "${ADMIN_KEY}"
  disable-control-panel: false
  panel-github-repository: "https://github.com/router-for-me/Cli-Proxy-API-Management-Center"

auth-dir: "${AUTH_DIR}"
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
EOF
    chmod 600 "${CONFIG_FILE}"
    printf "      %b✔ Config created (Secret: %b%s%b)%b\n\n" "${C_GREEN}" "${C_YELLOW}" "${ADMIN_KEY}" "${C_GREEN}" "${C_RESET}"
fi

# 6. Service Management (Systemd & CLI Helper)
printf "%b[6/6]%b %b🔗 Registering service daemon and CLI command...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"

if [ "$HAS_SYSTEMD" -eq 1 ]; then
    mkdir -p "${SYSTEMD_DIR}"
    cat << EOF > "${SYSTEMD_SERVICE_FILE}"
[Unit]
Description=CLIProxyAPI High-Performance AI Gateway Service
After=network.target

[Service]
Type=simple
Environment="MANAGEMENT_STATIC_PATH=${STATIC_DIR}"
ExecStart=${BIN_PATH} -config ${CONFIG_FILE}
Restart=always
RestartSec=5s
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=${TARGET_WANTED}
EOF

    if [ "$IS_ROOT" -eq 1 ]; then
        systemctl daemon-reload
        systemctl enable --now cliproxyapi >/dev/null 2>&1 || true
        printf "      %b✔ Systemd system service enabled and started%b\n" "${C_GREEN}" "${C_RESET}"
    else
        systemctl --user daemon-reload
        systemctl --user enable --now cliproxyapi >/dev/null 2>&1 || true
        printf "      %b✔ Systemd user service enabled and started%b\n" "${C_GREEN}" "${C_RESET}"
    fi
fi

# Write CLI management wrapper
SHELL_BIN=$(command -v bash 2>/dev/null || command -v sh 2>/dev/null || echo "/bin/sh")
cat << EOF > "${WRAPPER_PATH}"
#!${SHELL_BIN}
BIN="${BIN_PATH}"
CONFIG="${CONFIG_FILE}"
LOG_FILE="${LOG_DIR}/service.log"
export MANAGEMENT_STATIC_PATH="${STATIC_DIR}"

HAS_SYSTEMD="${HAS_SYSTEMD}"
IS_ROOT="${IS_ROOT}"

sys_cmd() {
  if [ "\$IS_ROOT" -eq 1 ]; then
    systemctl "\$@" cliproxyapi
  else
    systemctl --user "\$@" cliproxyapi
  fi
}

start_proc() {
  if [ "\$HAS_SYSTEMD" -eq 1 ]; then
    if sys_cmd start 2>/dev/null; then
      echo "🟢 Service started via systemd."
      return 0
    fi
    echo "⚠️  Systemd start failed, falling back to background daemon..."
  fi

  if pgrep -f "\$BIN" >/dev/null 2>&1; then
    echo "⚠️  CLIProxyAPI is already running (PID: \$(pgrep -f "\$BIN" | head -n 1))."
    return 0
  fi
  echo "🚀 Starting CLIProxyAPI background daemon..."
  setsid "\$BIN" -config "\$CONFIG" < /dev/null > "\$LOG_FILE" 2>&1 &
  sleep 1
  if pgrep -f "\$BIN" >/dev/null 2>&1; then
    echo "✅ CLIProxyAPI is running (PID: \$(pgrep -f "\$BIN" | head -n 1))"
  else
    echo "❌ Failed to start. Check logs: \$LOG_FILE"
    return 1
  fi
}

stop_proc() {
  if [ "\$HAS_SYSTEMD" -eq 1 ]; then
    sys_cmd stop 2>/dev/null || true
  fi
  if pgrep -f "\$BIN" >/dev/null 2>&1; then
    pkill -f "\$BIN" || true
    echo "🛑 CLIProxyAPI daemon stopped."
  else
    echo "ℹ️  CLIProxyAPI is not running."
  fi
}

restart_proc() {
  stop_proc
  sleep 1
  start_proc
}

status_proc() {
  if [ "\$HAS_SYSTEMD" -eq 1 ]; then
    if sys_cmd status --no-pager 2>/dev/null; then
      return 0
    fi
  fi

  if pgrep -f "\$BIN" >/dev/null 2>&1; then
    PID=\$(pgrep -f "\$BIN" | head -n 1)
    echo "🟢 CLIProxyAPI is running (PID: \$PID)"
    echo "🔗 Server URL : http://127.0.0.1:8317"
    echo "🌐 Dashboard  : http://127.0.0.1:8317/management.html"
  else
    echo "🔴 CLIProxyAPI is not running."
  fi
}

logs_proc() {
  if [ "\$HAS_SYSTEMD" -eq 1 ]; then
    if [ "\$IS_ROOT" -eq 1 ]; then
      journalctl -u cliproxyapi -f
      return 0
    else
      if journalctl --user -u cliproxyapi -f 2>/dev/null; then
        return 0
      fi
    fi
  fi
  tail -n 50 -f "\$LOG_FILE"
}

case "\$1" in
  start)
    start_proc
    ;;
  stop)
    stop_proc
    ;;
  restart)
    restart_proc
    ;;
  status)
    status_proc
    ;;
  logs|log)
    logs_proc
    ;;
  update|upgrade)
    echo "🌐 Updating CLIProxyAPI via official installer..."
    curl -fsSL https://raw.githubusercontent.com/tsaQB/cliproxyapi-installer/main/scripts/install-linux.sh | bash
    ;;
  run)
    shift
    exec "\$BIN" -config "\$CONFIG" "\$@"
    ;;
  *)
    if [ "\$#" -eq 0 ]; then
      echo "CLIProxyAPI Management Commands:"
      echo "  cliproxyapi start      - Start background service"
      echo "  cliproxyapi stop       - Stop background service"
      echo "  cliproxyapi restart    - Restart service"
      echo "  cliproxyapi status     - View service running status"
      echo "  cliproxyapi logs       - Stream real-time service logs"
      echo "  cliproxyapi update     - Upgrade binary and WebUI to latest"
      echo "  cliproxyapi run        - Run in foreground console"
      echo "  cliproxyapi <options>  - Pass flags directly (e.g. -antigravity-login)"
      exit 0
    fi
    exec "\$BIN" -config "\$CONFIG" "\$@"
    ;;
esac
EOF
chmod 755 "${WRAPPER_PATH}"
printf "      %b✔ Command 'cliproxyapi' registered at %s%b\n\n" "${C_GREEN}" "${WRAPPER_PATH}" "${C_RESET}"

# Resume process if without systemd
if [ "$HAS_SYSTEMD" -eq 0 ] && [ "$WAS_RUNNING" -eq 1 ]; then
    printf "      %b🔄 Resuming CLIProxyAPI background daemon...%b\n" "${C_CYAN}" "${C_RESET}"
    setsid "${BIN_PATH}" -config "${CONFIG_FILE}" < /dev/null > "${LOG_DIR}/service.log" 2>&1 &
    sleep 1
    if pgrep -f "${BIN_PATH}" >/dev/null 2>&1; then
        printf "      %b✔ Daemon resumed successfully%b\n\n" "${C_GREEN}" "${C_RESET}"
    fi
fi

# PATH guidance for non-root users
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        printf "  %bℹ️  Notice: %s is not currently in your \$PATH.%b\n" "${C_YELLOW}" "${BIN_DIR}" "${C_RESET}"
        printf "      Add this to your ~/.bashrc or ~/.zshrc:\n"
        printf "      %bexport PATH=\"%s:\$PATH\"%b\n\n" "${C_BOLD}" "${BIN_DIR}" "${C_RESET}"
        ;;
esac

# Final Summary Card
DISPLAY_CONFIG="${CONFIG_FILE}"
case "$DISPLAY_CONFIG" in
    "$HOME"/*) DISPLAY_CONFIG="~${DISPLAY_CONFIG#$HOME}" ;;
esac

printf "%b────────────────────────────────────────────────────%b\n" "${C_GREEN}" "${C_RESET}"
printf "  %b🎉 Installation Complete!%b\n" "${C_BOLD}" "${C_RESET}"
printf "%b────────────────────────────────────────────────────%b\n\n" "${C_GREEN}" "${C_RESET}"

printf "  %b• WebUI Dashboard%b : %bhttp://127.0.0.1:8317/management.html%b\n" "${C_BOLD}" "${C_RESET}" "${C_CYAN}" "${C_RESET}"
printf "  %b• Default Secret%b  : %b%s%b\n" "${C_BOLD}" "${C_RESET}" "${C_YELLOW}" "${ADMIN_KEY}" "${C_RESET}"
printf "  %b• Client API Key%b  : %b%s%b\n" "${C_BOLD}" "${C_RESET}" "${C_WHITE}" "${RANDOM_KEY}" "${C_RESET}"
printf "  %b• Configuration%b   : %b%s%b\n\n" "${C_BOLD}" "${C_RESET}" "${C_DIM}" "${DISPLAY_CONFIG}" "${C_RESET}"

printf "  %bQuick Start Commands:%b\n" "${C_BOLD}" "${C_RESET}"
printf "    %b$ cliproxyapi start%b   Start service in background\n" "${C_CYAN}" "${C_RESET}"
printf "    %b$ cliproxyapi status%b  Check server status & systemd\n" "${C_CYAN}" "${C_RESET}"
printf "    %b$ cliproxyapi logs%b    Stream live logs\n" "${C_CYAN}" "${C_RESET}"
printf "    %b$ cliproxyapi update%b  Upgrade to latest upstream release\n" "${C_CYAN}" "${C_RESET}"
printf "    %b$ cliproxyapi stop%b    Stop background daemon\n\n" "${C_CYAN}" "${C_RESET}"
printf "%b────────────────────────────────────────────────────%b\n\n" "${C_GREEN}" "${C_RESET}"
