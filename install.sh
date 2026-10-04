#!/bin/sh
# ==============================================================================
# CLIProxyAPI Universal Multiplatform Installer
# Supports: Linux (x86_64, aarch64), Android (Termux ARM64), Windows (x64, ARM64)
# macOS: In development
# Repository: https://github.com/tsaQB/cliproxyapi-installer
# ==============================================================================
set -eu

REPO_RAW="https://raw.githubusercontent.com/tsaQB/cliproxyapi-installer/main"
ANDROID_RAW="https://raw.githubusercontent.com/tsaQB/cliproxyapi-android/main"

# Resolve the directory of this script only when it runs from a real file.
# When piped (curl ... | sh), $0 is the shell name and must not be trusted.
SCRIPT_DIR=""
case "$0" in
    */install.sh|install.sh)
        if [ -f "$0" ]; then
            SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"
        fi
        ;;
esac

SH_BIN=$(command -v bash 2>/dev/null || command -v sh 2>/dev/null || echo "sh")

# Download a remote script to a temporary file, then run it. Piping curl
# straight into a shell would silently "succeed" on a failed download.
run_remote() {
    url="$1"
    shift
    if ! command -v curl >/dev/null 2>&1; then
        printf "\033[1;31m[X] curl is required but not installed.\033[0m\n" >&2
        exit 1
    fi
    tmp_script=$(mktemp 2>/dev/null || mktemp -t cpa_install)
    trap 'rm -f "$tmp_script"' EXIT
    trap 'rm -f "$tmp_script"; exit 130' HUP INT TERM
    if ! curl -fsSL "$url" -o "$tmp_script"; then
        printf "\033[1;31m[X] Failed to download installer from %s\033[0m\n" "$url" >&2
        exit 1
    fi
    status=0
    "$SH_BIN" "$tmp_script" "$@" || status=$?
    exit "$status"
}

OS=$(uname -s 2>/dev/null || echo "Unknown")

# 1. Android (Termux Native) - must be checked before generic Linux
if [ -n "${TERMUX_VERSION:-}" ] || [ -d "/data/data/com.termux" ]; then
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/scripts/install-termux.sh" ]; then
        exec "$SH_BIN" "$SCRIPT_DIR/scripts/install-termux.sh" "$@"
    fi
    run_remote "$ANDROID_RAW/install.sh" "$@"
fi

# 2. Linux Native (Debian, Ubuntu, Arch, Fedora, RHEL, Alpine, etc.)
if [ "$OS" = "Linux" ]; then
    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/scripts/install-linux.sh" ]; then
        exec "$SH_BIN" "$SCRIPT_DIR/scripts/install-linux.sh" "$@"
    fi
    run_remote "$REPO_RAW/scripts/install-linux.sh" "$@"
fi

# 3. macOS (Darwin)
if [ "$OS" = "Darwin" ]; then
    printf "\033[1;33m[!] macOS native installer is scheduled for the next release.\033[0m\n"
    printf "    In the meantime, you can download prebuilt Darwin binaries directly from:\n"
    printf "    https://github.com/router-for-me/CLIProxyAPI/releases/latest\n\n"
    exit 1
fi

# 4. Windows (Git Bash / MSYS2 / Cygwin)
case "$OS" in
    CYGWIN*|MINGW*|MSYS*)
        printf "\033[1;36m[!] For Windows, please run this command in PowerShell:\033[0m\n"
        printf "    \033[1mirm %s/install.ps1 | iex\033[0m\n\n" "$REPO_RAW"
        exit 1
        ;;
esac

printf "\033[1;31m[X] Unsupported Operating System: %s\033[0m\n" "$OS" >&2
exit 1
