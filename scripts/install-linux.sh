#!/bin/sh
# ==============================================================================
# CLIProxyAPI Native Linux Installer (x86_64 / aarch64)
# Automated Binary, WebUI Dashboard, and Systemd Service Deployment
# Repository: https://github.com/tsaQB/cliproxyapi-installer
# ==============================================================================
set -eu

INSTALLER_URL="https://raw.githubusercontent.com/tsaQB/cliproxyapi-installer/main/scripts/install-linux.sh"
UPSTREAM_REPO="router-for-me/CLIProxyAPI"
DASHBOARD_REPO="router-for-me/Cli-Proxy-API-Management-Center"
FALLBACK_TAG="v8.0.13"
DEFAULT_PORT="8317"
DEFAULT_SECRET="admin123"

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

step() { printf "%b[%s/6]%b %b%s%b\n" "${C_CYAN}" "$1" "${C_RESET}" "${C_BOLD}" "$2" "${C_RESET}"; }
ok()   { printf "      %b✔ %s%b\n" "${C_GREEN}" "$1" "${C_RESET}"; }
info() { printf "      %b• %s%b\n" "${C_DIM}" "$1" "${C_RESET}"; }
warn() { printf "      %b⚠️  %s%b\n" "${C_YELLOW}" "$1" "${C_RESET}"; }
die()  { printf "      %b❌ %s%b\n\n" "${C_RED}" "$1" "${C_RESET}" >&2; exit 1; }

# List PIDs whose command line starts with the given executable path.
# Uses /proc directly so it works without procps (pgrep) installed.
find_pids() {
    for d in /proc/[0-9]*; do
        [ -r "$d/cmdline" ] || continue
        cmd=$(tr '\000' ' ' < "$d/cmdline" 2>/dev/null) || continue
        case "$cmd" in
            "$1"|"$1 "*) printf "%s\n" "${d#/proc/}" ;;
        esac
    done
}

stop_pids() {
    pids=$(find_pids "$1")
    [ -n "$pids" ] || return 0
    # shellcheck disable=SC2086
    kill $pids 2>/dev/null || true
    i=0
    while [ $i -lt 10 ] && [ -n "$(find_pids "$1")" ]; do
        sleep 0.5 2>/dev/null || sleep 1
        i=$((i + 1))
    done
    pids=$(find_pids "$1")
    # shellcheck disable=SC2086
    [ -z "$pids" ] || kill -9 $pids 2>/dev/null || true
}

# Config readers (support both the legacy and the v8 config layout)
strip_yaml_value() {
    sed -e 's/[[:space:]]#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
        -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/"
}

read_secret() {
    grep -E '^[[:space:]]*secret-key:' "$1" 2>/dev/null | head -n 1 | sed 's/^[^:]*://' | strip_yaml_value
}

read_port() {
    p=$(grep -E '^[[:space:]]*port:[[:space:]]*[0-9]+' "$1" 2>/dev/null | head -n 1 | sed 's/^[^:]*://' | strip_yaml_value)
    printf "%s" "${p:-$DEFAULT_PORT}"
}

read_api_key() {
    awk '
        /^[[:space:]]*api-keys:[[:space:]]*$/ { inlist = 1; next }
        inlist && /^[[:space:]]*-/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); print; exit }
        inlist && /^[[:space:]]*[A-Za-z0-9_-]+:/ { inlist = 0 }
    ' "$1" 2>/dev/null | strip_yaml_value
}

describe_secret() {
    # shellcheck disable=SC2016 # literal bcrypt prefixes, not expansions
    case "$1" in
        "") printf "(empty - Management API disabled)" ;;
        '$2a$'*|'$2b$'*|'$2y$'*) printf "(hashed - use the secret you set earlier)" ;;
        *) printf "%s" "$1" ;;
    esac
}

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
printf "%b            Native Linux Service Installer%b\n" "${C_DIM}" "${C_RESET}"
printf "%b                  Maintained by tsaQB%b\n\n" "${C_PURPLE}" "${C_RESET}"

# 1. Platform & Architecture Validation
step 1 "🔍 Checking platform and CPU architecture..."
OS=$(uname -s 2>/dev/null || echo "Unknown")
[ "$OS" = "Linux" ] || die "This installer is intended for Linux. Detected: $OS"

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
        die "Unsupported architecture '$RAW_ARCH'. Supported: x86_64, aarch64"
        ;;
esac

# The default upstream Linux build is glibc-based (>= 2.17). musl systems such
# as Alpine need the portable "no-plugin" build instead.
BUILD_SUFFIX=""
LIBC_LABEL="glibc"
if ls /lib/ld-musl-* >/dev/null 2>&1 || (ldd --version 2>&1 | grep -qi musl); then
    BUILD_SUFFIX="_no-plugin"
    LIBC_LABEL="musl (portable no-plugin build)"
fi
ok "Compatible Linux platform: $ARCH_LABEL, $LIBC_LABEL"
echo

# 2. Dependency Verification
step 2 "📦 Verifying required utilities..."
need_cmd=""
for c in curl tar gzip; do
    command -v "$c" >/dev/null 2>&1 || need_cmd="$need_cmd $c"
done
[ -z "$need_cmd" ] || die "Missing required tools:$need_cmd. Please install them using your package manager."
ok "Required utilities ready (curl, tar, gzip)"
echo

# 3. Environment & Workspace Layout Setup
step 3 "📁 Configuring environment layout..."

if [ "$(id -u 2>/dev/null || echo 1000)" -eq 0 ]; then
    IS_ROOT=1
    BIN_DIR="/usr/local/bin"
    DATA_DIR="/var/lib/cliproxyapi"
    CONFIG_DIR="/etc/cliproxyapi"
    LOG_DIR="/var/log/cliproxyapi"
    SYSTEMD_DIR="/etc/systemd/system"
    TARGET_WANTED="multi-user.target"
    info "Running with root privileges (system-wide install)"
else
    IS_ROOT=0
    BIN_DIR="${HOME}/.local/bin"
    DATA_DIR="${HOME}/.cliproxyapi"
    CONFIG_DIR="${HOME}/.cliproxyapi"
    LOG_DIR="${HOME}/.cliproxyapi/logs"
    SYSTEMD_DIR="${HOME}/.config/systemd/user"
    TARGET_WANTED="default.target"
    info "Running in user space (local install: ${DATA_DIR})"
fi

BIN_PATH="${BIN_DIR}/cli-proxy-api"
WRAPPER_PATH="${BIN_DIR}/cliproxyapi"
STATIC_DIR="${DATA_DIR}/static"
AUTH_DIR="${DATA_DIR}/auths"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
DASHBOARD_FILE="${STATIC_DIR}/management.html"
LOG_FILE="${LOG_DIR}/service.log"
SYSTEMD_SERVICE_FILE="${SYSTEMD_DIR}/cliproxyapi.service"

mkdir -p "${BIN_DIR}" "${DATA_DIR}" "${CONFIG_DIR}" "${LOG_DIR}" "${STATIC_DIR}" "${AUTH_DIR}"
chmod 700 "${AUTH_DIR}" 2>/dev/null || true

# Detect a usable systemd instance (system bus for root, user bus otherwise)
HAS_SYSTEMD=0
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    if [ "$IS_ROOT" -eq 1 ]; then
        HAS_SYSTEMD=1
    elif systemctl --user show-environment >/dev/null 2>&1; then
        HAS_SYSTEMD=1
    else
        info "systemd user session not reachable; using background daemon mode"
    fi
fi

if [ "$IS_ROOT" -eq 1 ]; then
    SYSTEMCTL="systemctl"
else
    SYSTEMCTL="systemctl --user"
fi

WAS_RUNNING=0
if [ "$HAS_SYSTEMD" -eq 1 ] && $SYSTEMCTL is-active --quiet cliproxyapi 2>/dev/null; then
    WAS_RUNNING=1
    printf "      %b🛑 Stopping active systemd service for upgrade...%b\n" "${C_YELLOW}" "${C_RESET}"
    $SYSTEMCTL stop cliproxyapi 2>/dev/null || true
fi
if [ -n "$(find_pids "${BIN_PATH}")" ]; then
    WAS_RUNNING=1
    printf "      %b🛑 Stopping active process before upgrade...%b\n" "${C_YELLOW}" "${C_RESET}"
    stop_pids "${BIN_PATH}"
fi

ok "Directory structure ready"
echo

# 4. Fetch and Deploy Upstream Binary & WebUI Dashboard
step 4 "🌐 Fetching official upstream binary & dashboard..."

TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'cpa_linux')
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT
trap 'cleanup; exit 130' HUP INT TERM

# Rate-limit-free tag resolution via release redirect, fallback to GitHub API
LATEST_TAG=$(curl -fsSI "https://github.com/${UPSTREAM_REPO}/releases/latest" 2>/dev/null \
    | tr -d '\r' | grep -i '^location:' | head -n 1 | sed -n 's#.*/tag/##p' || true)
if [ -z "$LATEST_TAG" ]; then
    LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest" 2>/dev/null \
        | grep '"tag_name":' | head -n 1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)
fi
if [ -z "$LATEST_TAG" ]; then
    LATEST_TAG="$FALLBACK_TAG"
    warn "Could not resolve the latest release; using fallback ${FALLBACK_TAG}"
fi
CLEAN_TAG="${LATEST_TAG#v}"
printf "      %b• Upstream release: %b%s%b\n" "${C_DIM}" "${C_WHITE}" "$LATEST_TAG" "${C_RESET}"

ASSET_BASE="https://github.com/${UPSTREAM_REPO}/releases/download/${LATEST_TAG}/CLIProxyAPI_${CLEAN_TAG}_linux_${UPSTREAM_ARCH}"
DASHBOARD_URL="https://github.com/${DASHBOARD_REPO}/releases/latest/download/management.html"

info "Downloading CLIProxyAPI binary bundle..."
if ! curl -fsSL "${ASSET_BASE}${BUILD_SUFFIX}.tar.gz" -o "$TMP_DIR/cliproxyapi.tar.gz"; then
    if [ -z "$BUILD_SUFFIX" ] && curl -fsSL "${ASSET_BASE}_no-plugin.tar.gz" -o "$TMP_DIR/cliproxyapi.tar.gz"; then
        warn "Default build unavailable; installed the portable no-plugin build"
    else
        die "Failed to download binary archive from ${ASSET_BASE}${BUILD_SUFFIX}.tar.gz"
    fi
fi

mkdir -p "$TMP_DIR/extract"
tar -xzf "$TMP_DIR/cliproxyapi.tar.gz" -C "$TMP_DIR/extract" || die "Downloaded archive is corrupted"
EXTRACTED_BIN=$(find "$TMP_DIR/extract" -type f -name 'cli-proxy-api' | head -n 1)
[ -n "$EXTRACTED_BIN" ] || die "Binary 'cli-proxy-api' not found inside the release archive"
chmod 755 "$EXTRACTED_BIN"
mv -f "$EXTRACTED_BIN" "${BIN_PATH}"

info "Downloading Management Center WebUI dashboard..."
if curl -fsSL "$DASHBOARD_URL" -o "$TMP_DIR/management.html" && [ -s "$TMP_DIR/management.html" ]; then
    mv -f "$TMP_DIR/management.html" "${DASHBOARD_FILE}"
elif [ -s "${DASHBOARD_FILE}" ]; then
    warn "Dashboard download failed. Keeping the existing dashboard."
else
    warn "Dashboard download failed. Creating fallback placeholder..."
    cat << 'HTML' > "${DASHBOARD_FILE}"
<!DOCTYPE html><html><head><meta charset="utf-8"><title>CLIProxyAPI</title></head><body><h1>CLIProxyAPI Dashboard</h1><p>Please update your dashboard from <a href="https://github.com/router-for-me/Cli-Proxy-API-Management-Center">Management Center</a>.</p></body></html>
HTML
fi
chmod 644 "${DASHBOARD_FILE}"

ok "Native binary and WebUI dashboard deployed"
echo

# 5. Configuration Setup
step 5 "⚙️  Configuring service profile..."
if [ -f "${CONFIG_FILE}" ]; then
    ok "Existing configuration preserved: ${CONFIG_FILE}"
else
    # Import an existing configuration from a previous manual setup, if any
    LEGACY_CONFIG=""
    for cand in "/root/config.yaml" "${HOME}/config.yaml" "${HOME}/.cli-proxy-api/config.yaml" "${HOME}/.cliproxyapi/config.yaml"; do
        if [ -f "$cand" ] && [ "$cand" != "${CONFIG_FILE}" ]; then
            LEGACY_CONFIG="$cand"
            break
        fi
    done

    if [ -n "$LEGACY_CONFIG" ]; then
        cp -f "$LEGACY_CONFIG" "${CONFIG_FILE}"
        ok "Existing configuration imported from ${LEGACY_CONFIG}"
    else
        NEW_API_KEY=$(dd if=/dev/urandom bs=16 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')
        cat << EOF > "${CONFIG_FILE}"
# CLIProxyAPI Linux Configuration
host: "0.0.0.0"
port: ${DEFAULT_PORT}

api-keys:
  - "${NEW_API_KEY}"

remote-management:
  allow-remote: true
  secret-key: "${DEFAULT_SECRET}"
  disable-control-panel: false
  panel-github-repository: "https://github.com/${DASHBOARD_REPO}"

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
        ok "Config created: ${CONFIG_FILE}"
    fi
fi
chmod 600 "${CONFIG_FILE}"

ADMIN_KEY=$(read_secret "${CONFIG_FILE}")
API_KEY=$(read_api_key "${CONFIG_FILE}")
PORT=$(read_port "${CONFIG_FILE}")
echo

# 6. Service Management (Systemd & CLI Helper)
step 6 "🔗 Registering service daemon and CLI command..."

# Write CLI management wrapper: a small generated header plus a static body
SHELL_BIN=$(command -v sh 2>/dev/null || echo "/bin/sh")
cat << EOF > "${WRAPPER_PATH}.tmp"
#!${SHELL_BIN}
# CLIProxyAPI management wrapper (generated by cliproxyapi-installer)
BIN="${BIN_PATH}"
CONFIG="${CONFIG_FILE}"
DATA_DIR="${DATA_DIR}"
LOG_FILE="${LOG_FILE}"
STATIC_DIR="${STATIC_DIR}"
HAS_SYSTEMD="${HAS_SYSTEMD}"
IS_ROOT="${IS_ROOT}"
INSTALLER_URL="${INSTALLER_URL}"
EOF
cat << 'EOF' >> "${WRAPPER_PATH}.tmp"
export MANAGEMENT_STATIC_PATH="$STATIC_DIR"
UID_NOW=$(id -u 2>/dev/null || echo 1000)

find_pids() {
  for d in /proc/[0-9]*; do
    [ -r "$d/cmdline" ] || continue
    cmd=$(tr '\000' ' ' < "$d/cmdline" 2>/dev/null) || continue
    case "$cmd" in
      "$BIN"|"$BIN "*) printf "%s\n" "${d#/proc/}" ;;
    esac
  done
}

first_pid() { find_pids | head -n 1; }

get_port() {
  p=$(grep -E '^[[:space:]]*port:[[:space:]]*[0-9]+' "$CONFIG" 2>/dev/null | head -n 1 | sed 's/^[^:]*:[[:space:]]*//; s/[^0-9].*$//')
  printf "%s" "${p:-8317}"
}

# Run a command as root when this is a system-wide install
as_root() {
  if [ "$IS_ROOT" -eq 1 ] && [ "$UID_NOW" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo "$@"
    else
      echo "❌ This is a system-wide install. Re-run as root."
      return 1
    fi
  else
    "$@"
  fi
}

# State-changing systemctl calls (need root for a system-wide install)
sys_cmd() {
  if [ "$IS_ROOT" -eq 1 ]; then
    as_root systemctl "$@" cliproxyapi
  else
    systemctl --user "$@" cliproxyapi
  fi
}

# Read-only systemctl queries (never need sudo)
sys_query() {
  if [ "$IS_ROOT" -eq 1 ]; then
    systemctl "$@" cliproxyapi
  else
    systemctl --user "$@" cliproxyapi
  fi
}

print_endpoints() {
  port=$(get_port)
  echo "🔗 Server URL : http://127.0.0.1:${port}"
  echo "🌐 Dashboard  : http://127.0.0.1:${port}/management.html"
}

start_daemon() {
  if [ "$IS_ROOT" -eq 1 ] && [ "$UID_NOW" -ne 0 ]; then
    echo "❌ This is a system-wide install. Run 'sudo cliproxyapi start' instead."
    return 1
  fi
  mkdir -p "$(dirname "$LOG_FILE")"
  cd "$DATA_DIR" 2>/dev/null || true
  if command -v setsid >/dev/null 2>&1; then
    setsid "$BIN" -config "$CONFIG" < /dev/null >> "$LOG_FILE" 2>&1 &
  else
    nohup "$BIN" -config "$CONFIG" < /dev/null >> "$LOG_FILE" 2>&1 &
  fi
  sleep 1
}

start_proc() {
  if [ -n "$(first_pid)" ]; then
    echo "⚠️  CLIProxyAPI is already running (PID: $(first_pid))."
    return 0
  fi
  if [ "$HAS_SYSTEMD" -eq 1 ]; then
    if sys_cmd start 2>/dev/null; then
      echo "🟢 Service started via systemd."
      print_endpoints
      return 0
    fi
    echo "⚠️  Systemd start failed, falling back to background daemon..."
  fi
  echo "🚀 Starting CLIProxyAPI background daemon..."
  start_daemon || return 1
  if [ -n "$(first_pid)" ]; then
    echo "✅ CLIProxyAPI is running (PID: $(first_pid))"
    print_endpoints
  else
    echo "❌ Failed to start. Check logs: $LOG_FILE"
    return 1
  fi
}

stop_proc() {
  if [ "$HAS_SYSTEMD" -eq 1 ]; then
    sys_cmd stop 2>/dev/null || true
  fi
  pids=$(find_pids)
  if [ -n "$pids" ]; then
    # shellcheck disable=SC2086
    as_root kill $pids 2>/dev/null || true
    i=0
    while [ $i -lt 10 ] && [ -n "$(first_pid)" ]; do
      sleep 0.5 2>/dev/null || sleep 1
      i=$((i + 1))
    done
    pids=$(find_pids)
    # shellcheck disable=SC2086
    [ -z "$pids" ] || as_root kill -9 $pids 2>/dev/null || true
  fi
  if [ -n "$(first_pid)" ]; then
    echo "❌ Could not stop CLIProxyAPI (PID: $(first_pid))."
    if [ "$IS_ROOT" -eq 1 ] && [ "$UID_NOW" -ne 0 ]; then
      echo "   This is a system-wide install. Try: sudo cliproxyapi stop"
    fi
    return 1
  fi
  echo "🛑 CLIProxyAPI stopped."
}

status_proc() {
  pid=$(first_pid)
  if [ -n "$pid" ]; then
    echo "🟢 CLIProxyAPI is running (PID: $pid)"
    print_endpoints
  else
    echo "🔴 CLIProxyAPI is not running."
  fi
  if [ "$HAS_SYSTEMD" -eq 1 ]; then
    echo
    sys_query status --no-pager 2>/dev/null || true
  fi
  [ -n "$pid" ]
}

logs_proc() {
  if [ "$HAS_SYSTEMD" -eq 1 ] && sys_query is-active --quiet 2>/dev/null; then
    if [ "$IS_ROOT" -eq 1 ]; then
      journalctl -u cliproxyapi -n 50 -f
    else
      journalctl --user -u cliproxyapi -n 50 -f
    fi
    return
  fi
  if [ -f "$LOG_FILE" ]; then
    tail -n 50 -f "$LOG_FILE"
  else
    echo "ℹ️  No logs found yet at $LOG_FILE"
  fi
}

update_proc() {
  if [ "$IS_ROOT" -eq 0 ] && [ "$UID_NOW" -eq 0 ]; then
    echo "❌ This is a user-space install. Run 'cliproxyapi update' as its owner, not as root."
    return 1
  fi
  echo "🌐 Updating CLIProxyAPI via official installer..."
  tmp=$(mktemp 2>/dev/null || mktemp -t cpa_update) || return 1
  if ! curl -fsSL "$INSTALLER_URL" -o "$tmp"; then
    rm -f "$tmp"
    echo "❌ Failed to download the installer from $INSTALLER_URL"
    return 1
  fi
  status=0
  as_root sh "$tmp" || status=$?
  rm -f "$tmp"
  return "$status"
}

usage() {
  echo "CLIProxyAPI Management Commands:"
  echo "  cliproxyapi start      - Start service in background"
  echo "  cliproxyapi stop       - Stop background service"
  echo "  cliproxyapi restart    - Restart service"
  echo "  cliproxyapi status     - View service status, PID, and endpoints"
  echo "  cliproxyapi logs       - Stream real-time service logs"
  echo "  cliproxyapi update     - Upgrade binary and WebUI to latest release"
  echo "  cliproxyapi run        - Run in foreground console"
  echo "  cliproxyapi <options>  - Pass flags directly (e.g. -antigravity-login)"
}

case "${1:-}" in
  start)          start_proc ;;
  stop)           stop_proc ;;
  restart)        stop_proc; sleep 1; start_proc ;;
  status)         status_proc ;;
  logs|log)       logs_proc ;;
  update|upgrade) update_proc ;;
  run)            shift; exec "$BIN" -config "$CONFIG" "$@" ;;
  help)           usage ;;
  "")             usage ;;
  *)              exec "$BIN" -config "$CONFIG" "$@" ;;
esac
EOF
chmod 755 "${WRAPPER_PATH}.tmp"
mv -f "${WRAPPER_PATH}.tmp" "${WRAPPER_PATH}"
ok "Command 'cliproxyapi' registered at ${WRAPPER_PATH}"

SERVICE_ACTIVE=0
if [ "$HAS_SYSTEMD" -eq 1 ]; then
    mkdir -p "${SYSTEMD_DIR}"
    cat << EOF > "${SYSTEMD_SERVICE_FILE}"
[Unit]
Description=CLIProxyAPI AI Gateway Service
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
WorkingDirectory=${DATA_DIR}
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

    $SYSTEMCTL daemon-reload 2>/dev/null || true
    $SYSTEMCTL enable cliproxyapi >/dev/null 2>&1 || true
    $SYSTEMCTL restart cliproxyapi >/dev/null 2>&1 || true
    sleep 1
    if $SYSTEMCTL is-active --quiet cliproxyapi 2>/dev/null; then
        SERVICE_ACTIVE=1
        ok "Systemd service enabled and started"
        if [ "$IS_ROOT" -eq 0 ] && command -v loginctl >/dev/null 2>&1; then
            if [ "$(loginctl show-user "$(id -un)" -p Linger --value 2>/dev/null || echo no)" != "yes" ]; then
                info "Tip: run 'sudo loginctl enable-linger $(id -un)' to keep it running after logout"
            fi
        fi
    else
        warn "Systemd service failed to start; falling back to background daemon"
    fi
fi

# Launch the background daemon when systemd is unavailable or failed
if [ "$SERVICE_ACTIVE" -eq 0 ]; then
    if [ "$WAS_RUNNING" -eq 1 ]; then
        printf "      %b🔄 Resuming CLIProxyAPI background daemon...%b\n" "${C_CYAN}" "${C_RESET}"
    else
        printf "      %b🚀 Launching CLIProxyAPI background daemon...%b\n" "${C_CYAN}" "${C_RESET}"
    fi
    export MANAGEMENT_STATIC_PATH="${STATIC_DIR}"
    (
        cd "${DATA_DIR}" || exit 0
        if command -v setsid >/dev/null 2>&1; then
            setsid "${BIN_PATH}" -config "${CONFIG_FILE}" < /dev/null >> "${LOG_FILE}" 2>&1 &
        else
            nohup "${BIN_PATH}" -config "${CONFIG_FILE}" < /dev/null >> "${LOG_FILE}" 2>&1 &
        fi
    )
    sleep 1
    DAEMON_PID=$(find_pids "${BIN_PATH}" | head -n 1)
    if [ -n "$DAEMON_PID" ]; then
        ok "Daemon active (PID: ${DAEMON_PID})"
    else
        warn "Could not start background daemon. Check logs: ${LOG_FILE}"
    fi
fi
echo

# PATH guidance
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
    "$HOME"/*) DISPLAY_CONFIG="~${DISPLAY_CONFIG#"$HOME"}" ;;
esac

printf "%b────────────────────────────────────────────────────%b\n" "${C_GREEN}" "${C_RESET}"
printf "  %b🎉 Installation Complete!%b\n" "${C_BOLD}" "${C_RESET}"
printf "%b────────────────────────────────────────────────────%b\n\n" "${C_GREEN}" "${C_RESET}"

printf "  %b• WebUI Dashboard%b : %bhttp://127.0.0.1:%s/management.html%b\n" "${C_BOLD}" "${C_RESET}" "${C_CYAN}" "${PORT}" "${C_RESET}"
printf "  %b• Secret Key%b      : %b%s%b\n" "${C_BOLD}" "${C_RESET}" "${C_YELLOW}" "$(describe_secret "${ADMIN_KEY}")" "${C_RESET}"
printf "  %b• Client API Key%b  : %b%s%b\n" "${C_BOLD}" "${C_RESET}" "${C_WHITE}" "${API_KEY:-(none configured)}" "${C_RESET}"
printf "  %b• Configuration%b   : %b%s%b\n\n" "${C_BOLD}" "${C_RESET}" "${C_DIM}" "${DISPLAY_CONFIG}" "${C_RESET}"

printf "  %bQuick Start Commands:%b\n" "${C_BOLD}" "${C_RESET}"
printf "    %b$ cliproxyapi start%b   Start service in background\n" "${C_CYAN}" "${C_RESET}"
printf "    %b$ cliproxyapi status%b  Check service status\n" "${C_CYAN}" "${C_RESET}"
printf "    %b$ cliproxyapi logs%b    Stream live logs\n" "${C_CYAN}" "${C_RESET}"
printf "    %b$ cliproxyapi update%b  Upgrade to latest release\n" "${C_CYAN}" "${C_RESET}"
printf "    %b$ cliproxyapi stop%b    Stop background service\n\n" "${C_CYAN}" "${C_RESET}"
printf "%b────────────────────────────────────────────────────%b\n\n" "${C_GREEN}" "${C_RESET}"
