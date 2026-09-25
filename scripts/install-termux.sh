#!/bin/sh
# ==============================================================================
# CLIProxyAPI Termux (Android Non-Root) Installer Delegation
# Delegates to the official Android NDK Bionic distribution
# Repository: https://github.com/tsaQB/cliproxyapi-android
# ==============================================================================
set -eu

exec curl -fsSL https://raw.githubusercontent.com/tsaQB/cliproxyapi-android/main/install.sh | bash "$@"
