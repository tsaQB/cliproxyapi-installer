#!/bin/sh
# ==============================================================================
# CLIProxyAPI Termux (Android Non-Root) Installer Delegation
# Delegates to the official Android NDK Bionic distribution
# Repository: https://github.com/tsaQB/cliproxyapi-android
# ==============================================================================
set -eu

SH_BIN=$(command -v bash 2>/dev/null || command -v sh 2>/dev/null || echo "sh")
curl -fsSL https://raw.githubusercontent.com/tsaQB/cliproxyapi-android/main/install.sh | "$SH_BIN" -s -- "$@"
