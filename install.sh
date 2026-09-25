#!/bin/sh
# ==============================================================================
# CLIProxyAPI Universal Multiplatform Installer
# Supports: Linux (x86_64, aarch64), Android (Termux ARM64)
# Windows & macOS: In development
# Repository: https://github.com/tsaQB/cliproxyapi-installer
# ==============================================================================
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"
SH_BIN=$(command -v bash 2>/dev/null || command -v sh 2>/dev/null || echo "sh")

# 1. Android (Termux Native)
if [ -n "${TERMUX_VERSION:-}" ] || [ -d "/data/data/com.termux" ]; then
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/scripts/install-termux.sh" ]; then
        exec "$SCRIPT_DIR/scripts/install-termux.sh" "$@"
    fi
    curl -fsSL https://raw.githubusercontent.com/tsaQB/cliproxyapi-android/main/install.sh | "$SH_BIN" -s -- "$@"
    exit $?
fi

# 2. Linux Native (Debian, Ubuntu, Arch, Fedora, RHEL, Alpine, etc.)
OS=$(uname -s 2>/dev/null || echo "Unknown")
if [ "$OS" = "Linux" ]; then
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/scripts/install-linux.sh" ]; then
        exec "$SCRIPT_DIR/scripts/install-linux.sh" "$@"
    fi
    curl -fsSL https://raw.githubusercontent.com/tsaQB/cliproxyapi-installer/main/scripts/install-linux.sh | "$SH_BIN" -s -- "$@"
    exit $?
fi

# 3. macOS (Darwin)
if [ "$OS" = "Darwin" ]; then
    printf "\033[1;33m[!] macOS native installer is scheduled for the next release.\033[0m\n"
    printf "    In the meantime, you can download prebuilt Darwin binaries directly from:\n"
    printf "    https://github.com/router-for-me/CLIProxyAPI/releases/latest\n\n"
    exit 0
fi

# 4. Windows
case "$OS" in
    CYGWIN*|MINGW*|MSYS*)
        printf "\033[1;36m[!] For Windows, please run this command in PowerShell:\033[0m\n"
        printf "    \033[1mirm https://raw.githubusercontent.com/tsaQB/cliproxyapi-installer/main/install.ps1 | iex\033[0m\n\n"
        exit 0
        ;;
esac

printf "\033[1;31m[X] Unsupported Operating System: %s\033[0m\n" "$OS" >&2
exit 1
