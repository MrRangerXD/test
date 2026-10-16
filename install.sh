
#!/usr/bin/env bash
set -Eeuo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# SVM V6 • PREMIUM INSTALLER
# Made by AnkitCoder
# ══════════════════════════════════════════════════════════════════════════════

R='\033[38;5;196m'
O='\033[38;5;208m'
Y='\033[38;5;226m'
G='\033[38;5;46m'
B='\033[38;5;33m'
P='\033[38;5;129m'
C='\033[38;5;51m'
W='\033[97m'
RESET='\033[0m'

APP_NAME="SVM Panel"
VERSION="V6"
AUTHOR="AnkitCoder"
PORT="${PORT:-3000}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ZIP_FILE="${SCRIPT_DIR}/Svm-v6.zip"
INSTALL_DIR="/opt/svm-v6"
APP_DIR="${INSTALL_DIR}/app"
SERVICE_NAME="svm-panel"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Set APP_ARGS="--port 3000" if your application supports this argument.
# Set APP_ARGS="" if your application configures its own port.
APP_ARGS="${APP_ARGS:---port ${PORT}}"

BACKUP=""
STAGE_DIR=""
COMMITTED=0

cleanup() {
    [[ -z "$STAGE_DIR" ]] || rm -rf -- "$STAGE_DIR"
}

on_error() {
    local code=$?
    echo
    echo -e "${R}[✖] Installation failed (exit code ${code}).${RESET}"

    if [[ -n "$BACKUP" && -d "$BACKUP" && "$COMMITTED" -eq 0 ]]; then
        echo -e "${Y}[!] Previous installation backup: ${BACKUP}${RESET}"
        echo -e "${Y}[!] The backup has been preserved for recovery.${RESET}"
    fi

    echo -e "${Y}[!] Check the error above and the service logs below.${RESET}"

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --no-pager --full status "$SERVICE_NAME" 2>/dev/null || true
        journalctl -u "$SERVICE_NAME" -n 40 --no-pager 2>/dev/null || true
    fi

    exit "$code"
}

trap cleanup EXIT
trap on_error ERR

show_header() {
    clear 2>/dev/null || true
    echo -e "${R}################################################################################${RESET}"
    echo -e "${O}   ███████╗██╗   ██╗███╗   ███╗    ██╗   ██╗ ██████╗${RESET}"
    echo -e "${Y}   ██╔════╝██║   ██║████╗ ████║    ██║   ██║██╔════╝${RESET}"
    echo -e "${G}   ███████╗██║   ██║██╔████╔██║    ██║   ██║██║${RESET}"
    echo -e "${B}   ╚════██║╚██╗ ██╔╝██║╚██╔╝██║    ╚██╗ ██╔╝██║${RESET}"
    echo -e "${P}   ███████║ ╚████╔╝ ██║ ╚═╝ ██║     ╚████╔╝ ╚██████╗${RESET}"
    echo -e "${C}   ╚══════╝  ╚═══╝  ╚═╝     ╚═╝      ╚═══╝   ╚═════╝${RESET}"
    echo -e "${R}################################################################################${RESET}"
    echo -e "${P}          SVM PANEL ${VERSION} • PREMIUM EDITION • MADE BY ${AUTHOR}${RESET}"
    echo -e "${R}################################################################################${RESET}"
    echo
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "${Y}[!] Run this installer as root:${RESET}"
        echo -e "${C}sudo bash install.sh${RESET}"
        exit 1
    fi
}

check_license() {
    while true; do
        show_header
        echo -e "${Y}        [!] AUTHENTICATION REQUIRED [!]${RESET}"
        echo
        read -r -s -p "        Enter License Key: " KEY
        echo

        if [[ "$KEY" == 'MrRanger@XD#OP1' ]]; then
            unset KEY
            echo
            echo -e "${G}        [✔] License verified! Access granted.${RESET}"
            sleep 1
            return
        fi

        unset KEY
        echo
        echo -e "${R}        [✖] Invalid license key.${RESET}"
        sleep 2
    done
}

check_platform() {
    if [[ ! -f /etc/os-release ]]; then
        echo -e "${R}[✖] Cannot identify the operating system.${RESET}"
        exit 1
    fi

    . /etc/os-release

    case "${ID:-}" in
        ubuntu|debian) ;;
        *)
            echo -e "${R}[✖] This installer supports Ubuntu and Debian.${RESET}"
            echo -e "${Y}Detected: ${PRETTY_NAME:-unknown}${RESET}"
            exit 1
            ;;
    esac

    command -v apt-get >/dev/null 2>&1 || {
        echo -e "${R}[✖] apt-get is required.${RESET}"
        exit 1
    }
}

check_zip() {
    if [[ ! -f "$ZIP_FILE" ]]; then
        echo -e "${R}[✖] Svm-v6.zip was not found.${RESET}"
        echo -e "${Y}Expected: ${ZIP_FILE}${RESET}"
        exit 1
    fi

    command -v unzip >/dev/null 2>&1 || {
        echo -e "${R}[✖] unzip is not installed.${RESET}"
        exit 1
    }

    if ! unzip -tq "$ZIP_FILE" >/dev/null; then
        echo -e "${R}[✖] The ZIP archive is damaged or invalid.${RESET}"
        exit 1
    fi
}

prepare_system() {
    echo -e "${C}--> [1/6] Updating package index...${RESET}"
    apt-get update

    echo -e "${C}--> [2/6] Installing required packages...${RESET}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        unzip curl wget ca-certificates \
        python3 python3-pip python3-venv python3-dev \
        build-essential snapd

    echo -e "${G}[✔] Core packages installed.${RESET}"
}

install_lxd() {
    echo -e "${C}--> [3/6] Preparing LXD...${RESET}"

    # LXD is optional for installing the Python panel itself.
    if [[ "${INSTALL_LXD:-0}" != "1" ]]; then
        echo -e "${Y}[!] Skipping optional LXD installation.${RESET}"
        echo -e "${Y}    Set INSTALL_LXD=1 if your panel requires LXD.${RESET}"
        return
    fi

    if ! command -v lxc >/dev/null 2>&1; then
        snap install lxd
    fi

    if ! command -v lxd >/dev/null 2>&1; then
        echo -e "${R}[✖] LXD installation did not provide the lxd command.${RESET}"
        exit 1
    fi

    if ! lxc info >/dev/null 2>&1; then
        lxd init --auto
    fi

    echo -e "${G}[✔] LXD preparation complete.${RESET}"
}

detect_entrypoint() {
    local candidate
    local -a candidates=(
        "Svm.py"
        "svm.py"
        "app.py"
        "main.py"
    )

    for candidate in "${candidates[@]}"; do
        if [[ -f "${STAGE_DIR}/${candidate}" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    echo -e "${R}[✖] No Python entrypoint found.${RESET}" >&2
    echo -e "${Y}Expected: Svm.py, svm.py, app.py, or main.py${RESET}" >&2
    return 1
}

extract_panel() {
    echo -e "${C}--> [4/6] Extracting SVM Panel ${VERSION}...${RESET}"

    mkdir -p "$INSTALL_DIR"

    STAGE_DIR="$(mktemp -d "${INSTALL_DIR}/.staging.XXXXXX")"

    unzip -oq "$ZIP_FILE" -d "${STAGE_DIR}/extracted"

    # Support ZIP archives containing one wrapper directory.
    local extracted="${STAGE_DIR}/extracted"
    local -a entries=("$extracted"/* "$extracted"/.[!.]* "$extracted"/..?*)

    local -a valid_entries=()
    local item

    for item in "${entries[@]}"; do
        [[ -e "$item" ]] && valid_entries+=("$item")
    done

    if [[ ${#valid_entries[@]} -eq 1 && -d "${valid_entries[0]}" ]]; then
        local root="${valid_entries[0]}"
    else
        local root="$extracted"
    fi

    # Reject unexpected archive layouts before touching the current app.
    local detected
    detected="$(find "$root" -maxdepth 1 -type f \
        \( -name 'Svm.py' -o -name 'svm.py' -o -name 'app.py' -o -name 'main.py' \) \
        -print -quit)"

    if [[ -z "$detected" ]]; then
        echo -e "${R}[✖] Could not find the Python entrypoint at the archive root.${RESET}"
        echo -e "${Y}Inspect Svm-v6.zip and ensure the app files are in its root folder.${RESET}"
        exit 1
    fi

    mkdir -p "${STAGE_DIR}/app"
    cp -a "${root}/." "${STAGE_DIR}/app/"

    # Preserve the current installation before replacing it.
    if [[ -d "$APP_DIR" ]]; then
        BACKUP="/opt/svm-v6-backup-$(date +%Y%m%d-%H%M%S)"
        echo -e "${Y}[!] Backing up current installation to ${BACKUP}${RESET}"
        cp -a "$APP_DIR" "$BACKUP"
    fi

    echo -e "${G}[✔] Panel files extracted and validated.${RESET}"
}

prepare_python() {
    echo -e "${C}--> [5/6] Preparing Python environment...${RESET}"

    cd "${STAGE_DIR}/app"

    python3 -m venv venv
    "${STAGE_DIR}/app/venv/bin/python" -m pip install \
        --upgrade pip setuptools wheel

    if [[ -f requirements.txt ]]; then
        "${STAGE_DIR}/app/venv/bin/python" -m pip install \
            -r requirements.txt
    else
        echo -e "${Y}[!] requirements.txt not found.${RESET}"
    fi

    # Catch Python syntax errors before installation.
    local entrypoint
    entrypoint="$(detect_entrypoint)"
    "${STAGE_DIR}/app/venv/bin/python" -m py_compile "$entrypoint"

    echo -e "${G}[✔] Python environment prepared.${RESET}"
}

create_service() {
    echo -e "${C}--> [6/6] Installing systemd service...${RESET}"

    local entrypoint
    entrypoint="$(detect_entrypoint)"

    # Quote arguments safely for systemd's command-line parser.
    local args=""
    if [[ -n "$APP_ARGS" ]]; then
        local -a parsed_args
        read -r -a parsed_args <<< "$APP_ARGS"
        printf -v args ' %q' "${parsed_args[@]}"
    fi

    # Move the validated app into place on the same filesystem.
    local new_app="${INSTALL_DIR}/app.new.$$"
    rm -rf "$new_app"
    cp -a "${STAGE_DIR}/app" "$new_app"

    if [[ -d "$APP_DIR" ]]; then
        mv "$APP_DIR" "${INSTALL_DIR}/app.previous.$$"
    fi

    if ! mv "$new_app" "$APP_DIR"; then
        if [[ -d "${INSTALL_DIR}/app.previous.$$" ]]; then
            mv "${INSTALL_DIR}/app.previous.$$" "$APP_DIR"
        fi
        exit 1
    fi

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=SVM Panel ${VERSION} - ${AUTHOR}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
ExecStart=${APP_DIR}/venv/bin/python ${APP_DIR}/${entrypoint}${args}
Restart=on-failure
RestartSec=5
Environment=PYTHONUNBUFFERED=1
Environment=SVM_VERSION=${VERSION}
Environment=SVM_AUTHOR=${AUTHOR}
Environment=PORT=${PORT}
User=root

[Install]
WantedBy=multi-user.target
EOF

    chmod 0644 "$SERVICE_FILE"
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl restart "$SERVICE_NAME"

    sleep 3

    if systemctl is-active --quiet "$SERVICE_NAME"; then
        COMMITTED=1

        # Remove the temporary previous copy after successful startup.
        rm -rf "${INSTALL_DIR}/app.previous.$$"

        echo
        echo -e "${G}########################################################${RESET}"
        echo -e "${G}[✔] SVM Panel ${VERSION} installed successfully!${RESET}"
        echo -e "${G}########################################################${RESET}"
        echo -e "${C}Service: ${SERVICE_NAME}${RESET}"
        echo -e "${C}Status:  RUNNING${RESET}"
        echo -e "${C}Port:    ${PORT} (if supported by the application)${RESET}"
        echo
        echo -e "${Y}Useful commands:${RESET}"
        echo -e "${W}systemctl status ${SERVICE_NAME}${RESET}"
        echo -e "${W}journalctl -u ${SERVICE_NAME} -f${RESET}"
        echo -e "${W}systemctl restart ${SERVICE_NAME}${RESET}"
        echo
    else
        echo -e "${R}[✖] Service failed to start.${RESET}"
        journalctl -u "$SERVICE_NAME" -n 60 --no-pager || true
        exit 1
    fi
}

main() {
    require_root
    check_platform
    check_zip
    check_license
    prepare_system
    install_lxd
    extract_panel
    prepare_python
    create_service
}

main "$@"
