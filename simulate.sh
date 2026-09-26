#!/bin/sh
# ==============================================================================
# CLIProxyAPI Installer Visual Simulator
# Demonstrates installer terminal UI across Termux, Linux, and Windows
# ==============================================================================
set -eu

# Color palette
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_CYAN="\033[1;36m"
C_GREEN="\033[1;32m"
C_YELLOW="\033[1;33m"
C_PURPLE="\033[1;35m"
C_WHITE="\033[1;37m"

banner() {
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
}

delay() {
    sleep 0.25
}

sim_termux() {
    clear 2>/dev/null || true
    banner
    printf "%b       Android Non-Root Service Installer (Termux Native)%b\n" "${C_DIM}" "${C_RESET}"
    printf "%b                    Maintained by tsaQB%b\n\n" "${C_PURPLE}" "${C_RESET}"
    delay

    printf "%b[1/6]%b %b🔍 Checking platform and CPU architecture...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    delay
    printf "      %b✔ Compatible Android architecture: aarch64 (ARM64)%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[2/6]%b %b📦 Verifying required utilities...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    delay
    printf "      %b✔ Required utilities ready (curl, tar, jq)%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[3/6]%b %b📁 Configuring workspace directories...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    delay
    printf "      %b✔ Directory structure ready%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[4/6]%b %b🌐 Fetching latest Android NDK native release...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    delay
    printf "      %b• Detected release: %b%s%b\n" "${C_DIM}" "${C_WHITE}" "v7.3.17" "${C_RESET}"
    printf "      %b⬇ Downloading cliproxyapi-android-arm64.tar.gz...%b\n" "${C_DIM}" "${C_RESET}"
    delay
    printf "      %b✔ Android Bionic libc binary and dashboard deployed%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[5/6]%b %b⚙️  Configuring service profile...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    delay
    printf "      %b✔ Config created (Secret: %b%s%b)%b\n\n" "${C_GREEN}" "${C_YELLOW}" "admin123" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[6/6]%b %b🔗 Installing CLI command launcher...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    delay
    printf "      %b✔ Command 'cliproxyapi' registered in PATH%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay
    printf "      %b🚀 Starting CLIProxyAPI background daemon...%b\n" "${C_CYAN}" "${C_RESET}"
    delay
    printf "      %b✔ Service daemon active (PID: 14205)%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b────────────────────────────────────────────────────%b\n" "${C_GREEN}" "${C_RESET}"
    printf "  %b🎉 Installation Complete!%b\n" "${C_BOLD}" "${C_RESET}"
    printf "%b────────────────────────────────────────────────────%b\n\n" "${C_GREEN}" "${C_RESET}"

    printf "  %b• WebUI Dashboard%b : %bhttp://127.0.0.1:8317/management.html%b\n" "${C_BOLD}" "${C_RESET}" "${C_CYAN}" "${C_RESET}"
    printf "  %b• Secret Key%b      : %b%s%b\n" "${C_BOLD}" "${C_RESET}" "${C_YELLOW}" "admin123" "${C_RESET}"
    printf "  %b• Client API Key%b  : %b%s%b\n" "${C_BOLD}" "${C_RESET}" "${C_WHITE}" "e7a9c8b41f2349d8c0b561e934a78120" "${C_RESET}"
    printf "  %b• Configuration%b   : %b~/.cliproxyapi/config.yaml%b\n\n" "${C_BOLD}" "${C_RESET}" "${C_DIM}" "${C_RESET}"

    printf "  %bQuick Start Commands:%b\n" "${C_BOLD}" "${C_RESET}"
    printf "    %b$ cliproxyapi start%b   Start service in background\n" "${C_CYAN}" "${C_RESET}"
    printf "    %b$ cliproxyapi status%b  Check server status\n" "${C_CYAN}" "${C_RESET}"
    printf "    %b$ cliproxyapi logs%b    Stream live logs\n" "${C_CYAN}" "${C_RESET}"
    printf "    %b$ cliproxyapi update%b  Upgrade to latest release\n" "${C_CYAN}" "${C_RESET}"
    printf "    %b$ cliproxyapi stop%b    Stop background daemon\n\n" "${C_CYAN}" "${C_RESET}"
    printf "%b────────────────────────────────────────────────────%b\n" "${C_GREEN}" "${C_RESET}"
}

sim_linux_user() {
    clear 2>/dev/null || true
    banner
    printf "%b           Native Linux Service Installer%b\n" "${C_DIM}" "${C_RESET}"
    printf "%b              Maintained by tsaQB%b\n\n" "${C_PURPLE}" "${C_RESET}"
    delay

    printf "%b[1/6]%b %b🔍 Checking platform and CPU architecture...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    delay
    printf "      %b✔ Compatible Linux platform: x86_64 (amd64)%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[2/6]%b %b📦 Verifying required utilities...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    delay
    printf "      %b✔ Required utilities ready (curl, tar)%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[3/6]%b %b📁 Configuring environment layout...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    delay
    printf "      %b• Running in user space (Local install: ~/.cliproxyapi)%b\n" "${C_DIM}" "${C_RESET}"
    printf "      %b✔ Directory structure ready%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[4/6]%b %b🌐 Fetching official upstream binary & dashboard...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    delay
    printf "      %b• Upstream release: %b%s%b\n" "${C_DIM}" "${C_WHITE}" "v7.3.17" "${C_RESET}"
    printf "      %b⬇ Downloading CLIProxyAPI binary bundle...%b\n" "${C_DIM}" "${C_RESET}"
    delay
    printf "      %b⬇ Downloading Management Center WebUI dashboard...%b\n" "${C_DIM}" "${C_RESET}"
    delay
    printf "      %b✔ Native binary and WebUI dashboard deployed%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[5/6]%b %b⚙️  Configuring service profile...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    delay
    printf "      %b✔ Config created (Secret: %b%s%b)%b\n\n" "${C_GREEN}" "${C_YELLOW}" "admin123" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[6/6]%b %b🔗 Registering service daemon and CLI command...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    delay
    printf "      %b✔ Systemd user service enabled and started%b\n" "${C_GREEN}" "${C_RESET}"
    printf "      %b✔ Command 'cliproxyapi' registered at ~/.local/bin/cliproxyapi%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b────────────────────────────────────────────────────%b\n" "${C_GREEN}" "${C_RESET}"
    printf "  %b🎉 Installation Complete!%b\n" "${C_BOLD}" "${C_RESET}"
    printf "%b────────────────────────────────────────────────────%b\n\n" "${C_GREEN}" "${C_RESET}"

    printf "  %b• WebUI Dashboard%b : %bhttp://127.0.0.1:8317/management.html%b\n" "${C_BOLD}" "${C_RESET}" "${C_CYAN}" "${C_RESET}"
    printf "  %b• Secret Key%b      : %b%s%b\n" "${C_BOLD}" "${C_RESET}" "${C_YELLOW}" "admin123" "${C_RESET}"
    printf "  %b• Client API Key%b  : %b%s%b\n" "${C_BOLD}" "${C_RESET}" "${C_WHITE}" "9f21d4c82b0147ae8a4b37f190c2e45a" "${C_RESET}"
    printf "  %b• Configuration%b   : %b~/.cliproxyapi/config.yaml%b\n\n" "${C_BOLD}" "${C_RESET}" "${C_DIM}" "${C_RESET}"

    printf "  %bQuick Start Commands:%b\n" "${C_BOLD}" "${C_RESET}"
    printf "    %b$ cliproxyapi start%b   Start service in background\n" "${C_CYAN}" "${C_RESET}"
    printf "    %b$ cliproxyapi status%b  Check server status & systemd\n" "${C_CYAN}" "${C_RESET}"
    printf "    %b$ cliproxyapi logs%b    Stream live logs\n" "${C_CYAN}" "${C_RESET}"
    printf "    %b$ cliproxyapi update%b  Upgrade to latest upstream release\n" "${C_CYAN}" "${C_RESET}"
    printf "    %b$ cliproxyapi stop%b    Stop background daemon\n\n" "${C_CYAN}" "${C_RESET}"
    printf "%b────────────────────────────────────────────────────%b\n" "${C_GREEN}" "${C_RESET}"
}

sim_windows() {
    clear 2>/dev/null || true
    banner
    printf "%b            Windows Native Service Installer               %b\n" "${C_DIM}" "${C_RESET}"
    printf "%b                  Maintained by tsaQB                      %b\n\n" "${C_PURPLE}" "${C_RESET}"
    delay

    printf "%b[1/6] 🔍 Checking platform architecture...%b\n" "${C_CYAN}" "${C_RESET}"
    delay
    printf "      %b✔ Compatible Windows architecture: amd64%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[2/6] 📁 Configuring workspace directories...%b\n" "${C_CYAN}" "${C_RESET}"
    delay
    printf "      %b✔ Directory layout ready at C:\\Users\\Developer\\.cliproxyapi%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[3/6] 🌐 Resolving latest upstream release...%b\n" "${C_CYAN}" "${C_RESET}"
    delay
    printf "      %b• Upstream release: %s%b\n" "${C_DIM}" "v7.3.17" "${C_RESET}"
    delay

    printf "%b[4/6] ⬇ Downloading official binary bundle and WebUI...%b\n" "${C_CYAN}" "${C_RESET}"
    delay
    printf "      %b✔ Windows binary and WebUI dashboard deployed%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[5/6] ⚙️  Configuring service profile...%b\n" "${C_CYAN}" "${C_RESET}"
    delay
    printf "      %b✔ Config created (Secret: %s)%b\n\n" "${C_GREEN}" "admin123" "${C_RESET}"
    delay

    printf "%b[6/6] 🔗 Registering CLI command launcher and PATH...%b\n" "${C_CYAN}" "${C_RESET}"
    delay
    printf "      %b✔ Command 'cliproxyapi' registered in PATH%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b────────────────────────────────────────────────────%b\n" "${C_GREEN}" "${C_RESET}"
    printf "  %b🎉 Installation Complete!%b\n" "${C_GREEN}" "${C_RESET}"
    printf "%b────────────────────────────────────────────────────%b\n\n" "${C_GREEN}" "${C_RESET}"

    printf "  %b• WebUI Dashboard : %bhttp://127.0.0.1:8317/management.html%b\n" "${C_WHITE}" "${C_CYAN}" "${C_RESET}"
    printf "  %b• Secret Key      : %badmin123%b\n" "${C_WHITE}" "${C_YELLOW}" "${C_RESET}"
    printf "  %b• Configuration   : %bC:\\Users\\Developer\\.cliproxyapi\\config.yaml%b\n\n" "${C_WHITE}" "${C_DIM}" "${C_RESET}"

    printf "  %bQuick Start Commands:%b\n" "${C_WHITE}" "${C_RESET}"
    printf "    %b$ cliproxyapi start%b   Start service in background\n" "${C_CYAN}" "${C_RESET}"
    printf "    %b$ cliproxyapi status%b  Check server status\n" "${C_CYAN}" "${C_RESET}"
    printf "    %b$ cliproxyapi logs%b    Stream live logs\n" "${C_CYAN}" "${C_RESET}"
    printf "    %b$ cliproxyapi update%b  Upgrade to latest release\n" "${C_CYAN}" "${C_RESET}"
    printf "    %b$ cliproxyapi stop%b    Stop background daemon\n\n" "${C_CYAN}" "${C_RESET}"
    printf "%b────────────────────────────────────────────────────%b\n" "${C_GREEN}" "${C_RESET}"
}

sim_upgrade() {
    clear 2>/dev/null || true
    banner
    printf "%b           Native Linux Service Installer%b\n" "${C_DIM}" "${C_RESET}"
    printf "%b              Maintained by tsaQB%b\n\n" "${C_PURPLE}" "${C_RESET}"
    delay

    printf "%b[1/6]%b %b🔍 Checking platform and CPU architecture...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    printf "      %b✔ Compatible Linux platform: x86_64 (amd64)%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[3/6]%b %b📁 Configuring environment layout...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    printf "      %b🛑 Stopping active user systemd service for upgrade...%b\n" "${C_YELLOW}" "${C_RESET}"
    printf "      %b✔ Directory structure ready%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[4/6]%b %b🌐 Fetching official upstream binary & dashboard...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    printf "      %b✔ Native binary and WebUI dashboard deployed%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[5/6]%b %b⚙️  Configuring service profile...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    printf "      %b✔ Existing configuration preserved: ~/.cliproxyapi/config.yaml%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b[6/6]%b %b🔗 Registering service daemon and CLI command...%b\n" "${C_CYAN}" "${C_RESET}" "${C_BOLD}" "${C_RESET}"
    printf "      %b✔ Systemd user service reloaded and restarted%b\n" "${C_GREEN}" "${C_RESET}"
    printf "      %b✔ Command 'cliproxyapi' registered at ~/.local/bin/cliproxyapi%b\n\n" "${C_GREEN}" "${C_RESET}"
    delay

    printf "%b────────────────────────────────────────────────────%b\n" "${C_GREEN}" "${C_RESET}"
    printf "  %b🎉 Installation Complete!%b\n" "${C_BOLD}" "${C_RESET}"
    printf "%b────────────────────────────────────────────────────%b\n\n" "${C_GREEN}" "${C_RESET}"

    printf "  %b• WebUI Dashboard%b : %bhttp://127.0.0.1:8317/management.html%b\n" "${C_BOLD}" "${C_RESET}" "${C_CYAN}" "${C_RESET}"
    printf "  %b• Secret Key%b      : %b%s%b\n" "${C_BOLD}" "${C_RESET}" "${C_YELLOW}" "my_custom_secret_key" "${C_RESET}"
    printf "  %b• Client API Key%b  : %b%s%b\n" "${C_BOLD}" "${C_RESET}" "${C_WHITE}" "e7a9c8b41f2349d8c0b561e934a78120" "${C_RESET}"
    printf "  %b• Configuration%b   : %b~/.cliproxyapi/config.yaml%b\n\n" "${C_BOLD}" "${C_RESET}" "${C_DIM}" "${C_RESET}"
    printf "%b────────────────────────────────────────────────────%b\n" "${C_GREEN}" "${C_RESET}"
}

# Main routing
MODE="${1:-}"
case "$MODE" in
    termux|android)
        sim_termux
        ;;
    linux)
        sim_linux_user
        ;;
    windows|win)
        sim_windows
        ;;
    upgrade)
        sim_upgrade
        ;;
    all)
        printf "%b>>> 1. Simulating Android (Termux)...%b\n" "${C_BOLD}" "${C_RESET}"
        sim_termux
        sleep 1.5
        printf "\n%b>>> 2. Simulating Linux Native (User)...%b\n" "${C_BOLD}" "${C_RESET}"
        sim_linux_user
        sleep 1.5
        printf "\n%b>>> 3. Simulating Windows PowerShell...%b\n" "${C_BOLD}" "${C_RESET}"
        sim_windows
        sleep 1.5
        printf "\n%b>>> 4. Simulating Upgrade Mode...%b\n" "${C_BOLD}" "${C_RESET}"
        sim_upgrade
        ;;
    *)
        echo "=================================================="
        echo "   CLIProxyAPI Installer UI Simulator Menu        "
        echo "=================================================="
        echo "1) Android (Termux Native)"
        echo "2) Linux Native (User-space / Systemd)"
        echo "3) Windows Native (PowerShell)"
        echo "4) In-Place Upgrade Mode (Preserved Keys)"
        echo "5) Play All Simulations sequentially"
        echo "q) Quit"
        echo ""
        printf "Pilih simulasi [1-5]: "
        read -r choice || choice=""
        case "$choice" in
            1) sim_termux ;;
            2) sim_linux_user ;;
            3) sim_windows ;;
            4) sim_upgrade ;;
            5) "$0" all ;;
            *) echo "Exit." ;;
        esac
        ;;
esac
