#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Gitea Cloudflare Tunnel - SSH Client Setup
# ============================================================

SCRIPT_NAME="$(basename "$0")"

CONFIG_START="# >>> Gitea Cloudflare SSH >>>"
CONFIG_END="# <<< Gitea Cloudflare SSH <<<"

SSH_DIR="${HOME}/.ssh"
SSH_CONFIG="${SSH_DIR}/config"

ENABLE_HOST_SSH=false
UNINSTALL=false
DOMAIN=""

# ============================================================
# Colors
# ============================================================

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    RESET=''
fi

# ============================================================
# Logging
# ============================================================

info() {
    echo -e "${BLUE}INFO${RESET}  $*"
}

success() {
    echo -e "${GREEN}OK${RESET}    $*"
}

warning() {
    echo -e "${YELLOW}WARN${RESET}  $*"
}

error() {
    echo -e "${RED}ERROR${RESET} $*" >&2
}

die() {
    error "$*"
    exit 1
}

# ============================================================
# Help
# ============================================================

show_help() {
    cat <<EOF

Gitea Cloudflare Tunnel - SSH Client Setup

Usage:
    ${SCRIPT_NAME}
    ${SCRIPT_NAME} <domain>
    ${SCRIPT_NAME} --host-ssh
    ${SCRIPT_NAME} --host-ssh <domain>
    ${SCRIPT_NAME} --uninstall
    ${SCRIPT_NAME} --help

Options:
    --host-ssh
        Enable SSH access to the server host.

        Without this option, only Git SSH is configured.

    --uninstall
        Remove the SSH configuration created by this script.

        cloudflared itself will NOT be uninstalled.

    -h, --help
        Show this help message.

Examples:

    ${SCRIPT_NAME}

        Interactive domain setup.
        Configures Git SSH only.

    ${SCRIPT_NAME} example.com

        Configures:
            git-ssh.example.com

    ${SCRIPT_NAME} --host-ssh

        Interactive domain setup.
        Configures:
            git-ssh.example.com
            ssh.example.com

    ${SCRIPT_NAME} --host-ssh example.com

        Configures Git SSH and Host SSH.

EOF
}

# ============================================================
# Argument Parsing
# ============================================================

while [[ $# -gt 0 ]]; do
    case "$1" in

        --host-ssh)
            ENABLE_HOST_SSH=true
            shift
            ;;

        --uninstall)
            UNINSTALL=true
            shift
            ;;

        -h|--help)
            show_help
            exit 0
            ;;

        -*)
            die "Unknown option: $1

Run '${SCRIPT_NAME} --help' for usage."

            ;;

        *)
            if [[ -n "$DOMAIN" ]]; then
                die "Only one domain can be specified."
            fi

            DOMAIN="$1"
            shift
            ;;
    esac
done

# ============================================================
# OS Detection
# ============================================================

OS="unknown"
DISTRO="unknown"
ARCH="unknown"

detect_os() {
    case "$(uname -s)" in

        Linux*)
            OS="linux"

            if [[ -f /etc/os-release ]]; then
                # shellcheck disable=SC1091
                source /etc/os-release
                DISTRO="${ID:-unknown}"
            fi
            ;;

        Darwin*)
            OS="macos"
            ;;

        MINGW*|MSYS*|CYGWIN*)
            OS="windows"
            ;;

        *)
            OS="unknown"
            ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)
            ARCH="amd64"
            ;;

        aarch64|arm64)
            ARCH="arm64"
            ;;

        armv7l)
            ARCH="arm"
            ;;

        *)
            ARCH="$(uname -m)"
            ;;
    esac
}

# ============================================================
# Command Helpers
# ============================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================
# PATH Helpers
# ============================================================

path_contains() {
    local directory="$1"

    case ":${PATH}:" in
        *:"${directory}":*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

add_path_to_file() {
    local directory="$1"
    local file="$2"

    [[ -d "$directory" ]] || return 0

    # Avoid duplicate PATH entries.
    if [[ -f "$file" ]] && grep -Fq "PATH=.*${directory}" "$file"; then
        return 0
    fi

    {
        echo
        echo "# Added by Gitea Cloudflare SSH setup"
        echo "export PATH=\"${directory}:\$PATH\""
    } >> "$file"
}

get_shell_rc() {
    local shell_name

    shell_name="$(basename "${SHELL:-}")"

    case "$shell_name" in
        zsh)
            echo "${HOME}/.zshrc"
            ;;

        bash)
            echo "${HOME}/.bashrc"
            ;;

        fish)
            echo "${HOME}/.config/fish/config.fish"
            ;;

        *)
            echo "${HOME}/.profile"
            ;;
    esac
}

persist_unix_path() {
    local directory="$1"

    [[ -d "$directory" ]] || return 0

    # Already available in current shell.
    if path_contains "$directory"; then
        return 0
    fi

    local rc
    rc="$(get_shell_rc)"

    info "Adding ${directory} to PATH..."

    add_path_to_file "$directory" "$rc"

    # Also add to ~/.profile for login shells.
    if [[ "$rc" != "${HOME}/.profile" ]]; then
        add_path_to_file "$directory" "${HOME}/.profile"
    fi

    export PATH="${directory}:${PATH}"

    success "PATH updated."
}

# ============================================================
# Windows PATH
# ============================================================

windows_add_to_path() {
    local directory="$1"

    [[ -d "$directory" ]] || return 0

    info "Checking Windows User PATH..."

    # Ask PowerShell for the current User PATH.
    local current_path

    current_path="$(
        powershell.exe -NoProfile -Command \
        '[Environment]::GetEnvironmentVariable("Path","User")' \
        2>/dev/null \
        | tr -d '\r'
    )" || true

    if [[ ":${current_path}:" == *:"${directory}":* ]]; then
        success "Windows PATH already contains ${directory}."
        return 0
    fi

    info "Adding ${directory} to Windows User PATH..."

    powershell.exe -NoProfile -Command \
        "\$p=[Environment]::GetEnvironmentVariable('Path','User'); if ([string]::IsNullOrWhiteSpace(\$p)) { \$p='' }; if (\$p -notlike '*${directory}*') { \$new=if ([string]::IsNullOrWhiteSpace(\$p)) { '${directory}' } else { \$p + ';${directory}' }; [Environment]::SetEnvironmentVariable('Path',\$new,'User') }"

    success "Windows User PATH updated."

    # Make it available to the current Git Bash process.
    export PATH="${directory}:${PATH}"
}

# ============================================================
# Find cloudflared
# ============================================================

find_cloudflared_binary() {

    if command_exists cloudflared; then
        command -v cloudflared
        return 0
    fi

    case "$OS" in

        linux)
            for path in \
                /usr/bin/cloudflared \
                /usr/local/bin/cloudflared \
                "${HOME}/.local/bin/cloudflared"
            do
                if [[ -x "$path" ]]; then
                    echo "$path"
                    return 0
                fi
            done
            ;;

        macos)
            for path in \
                /opt/homebrew/bin/cloudflared \
                /usr/local/bin/cloudflared \
                "${HOME}/.local/bin/cloudflared"
            do
                if [[ -x "$path" ]]; then
                    echo "$path"
                    return 0
                fi
            done
            ;;

        windows)
            # Git Bash can use Windows where.exe.
            if command_exists where.exe; then
                local result

                result="$(where.exe cloudflared.exe 2>/dev/null | head -n 1 | tr -d '\r')" || true

                if [[ -n "$result" ]]; then
                    echo "$result"
                    return 0
                fi
            fi

            for path in \
                "/c/Program Files/cloudflared/cloudflared.exe" \
                "/c/Program Files (x86)/cloudflared/cloudflared.exe"
            do
                if [[ -f "$path" ]]; then
                    echo "$path"
                    return 0
                fi
            done
            ;;
    esac

    return 1
}

# ============================================================
# cloudflared Version
# ============================================================

cloudflared_version() {
    if ! command_exists cloudflared; then
        return 1
    fi

    cloudflared --version 2>/dev/null | head -n 1
}

# ============================================================
# Install cloudflared - Linux
# ============================================================

install_cloudflared_linux() {

    case "$DISTRO" in

        ubuntu|debian|linuxmint|pop)
            if ! command_exists apt; then
                die "apt was not found."
            fi

            info "Installing cloudflared using apt..."

            sudo apt update
            sudo apt install -y cloudflared
            ;;

        arch|manjaro|endeavouros)
            if ! command_exists pacman; then
                die "pacman was not found."
            fi

            info "Installing cloudflared using pacman..."

            sudo pacman -Sy --needed cloudflared
            ;;

        fedora)
            if ! command_exists dnf; then
                die "dnf was not found."
            fi

            info "Installing cloudflared using dnf..."

            sudo dnf install -y cloudflared
            ;;

        rhel|centos|rocky|almalinux)
            if command_exists dnf; then
                info "Installing cloudflared using dnf..."
                sudo dnf install -y cloudflared

            elif command_exists yum; then
                info "Installing cloudflared using yum..."
                sudo yum install -y cloudflared

            else
                die "Neither dnf nor yum was found."
            fi
            ;;

        *)
            die "Unsupported Linux distribution: ${DISTRO}

Supported distributions:
    Debian
    Ubuntu
    Arch
    Fedora
    RHEL
    CentOS
    Rocky
    AlmaLinux
"
            ;;
    esac
}

# ============================================================
# Install cloudflared - macOS
# ============================================================

install_cloudflared_macos() {

    if ! command_exists brew; then
        die "Homebrew is not installed.

Install Homebrew first, then run this script again."
    fi

    info "Installing cloudflared using Homebrew..."

    brew install cloudflare/cloudflare/cloudflared
}

# ============================================================
# Install cloudflared - Windows
# ============================================================

install_cloudflared_windows() {

    if command_exists winget; then

        info "Installing cloudflared using winget..."

        winget install \
            --id Cloudflare.cloudflared \
            --exact \
            --accept-source-agreements \
            --accept-package-agreements

        return
    fi

    if command_exists choco; then

        info "Installing cloudflared using Chocolatey..."

        choco install cloudflared -y

        return
    fi

    die "Neither winget nor Chocolatey was found.

Install cloudflared manually and run this script again."
}

# ============================================================
# Install cloudflared
# ============================================================

install_cloudflared() {

    case "$OS" in

        linux)
            install_cloudflared_linux
            ;;

        macos)
            install_cloudflared_macos
            ;;

        windows)
            install_cloudflared_windows
            ;;

        *)
            die "Unsupported operating system."
            ;;
    esac
}

# ============================================================
# Ensure cloudflared
# ============================================================

ensure_cloudflared() {

    info "Checking cloudflared..."

    if command_exists cloudflared; then
        success "cloudflared detected: $(cloudflared_version)"
        return
    fi

    warning "cloudflared is not installed."

    echo

    install_cloudflared

    echo

    # --------------------------------------------------------
    # Find binary after installation.
    # --------------------------------------------------------

    local binary=""

    binary="$(find_cloudflared_binary || true)"

    if [[ -z "$binary" ]]; then

        warning "cloudflared was installed, but its executable could not be located."

        echo
        echo "Please restart your terminal and run:"
        echo
        echo "    cloudflared --version"
        echo
        echo "Then run this setup script again."
        echo

        exit 1
    fi

    info "cloudflared binary:"
    echo "    ${binary}"

    # --------------------------------------------------------
    # Determine binary directory.
    # --------------------------------------------------------

    local binary_dir
    binary_dir="$(dirname "$binary")"

    case "$OS" in

        windows)
            windows_add_to_path "$binary_dir"
            ;;

        *)
            persist_unix_path "$binary_dir"
            ;;
    esac

    # --------------------------------------------------------
    # Refresh command lookup.
    # --------------------------------------------------------

    hash -r 2>/dev/null || true

    echo

    if command_exists cloudflared; then
        success "cloudflared is ready."
        success "$(cloudflared_version)"
    else
        warning "cloudflared is installed but is not available in the current shell."

        echo
        echo "Open a new terminal and run:"
        echo
        echo "    cloudflared --version"
        echo
        echo "Then run this script again."
        echo

        exit 1
    fi
}

# ============================================================
# SSH
# ============================================================

ensure_ssh() {

    if command_exists ssh; then
        success "SSH client detected."
        return
    fi

    die "OpenSSH client was not found.

Please install OpenSSH and run this script again."
}

# ============================================================
# SSH Directory
# ============================================================

ensure_ssh_directory() {

    if [[ ! -d "$SSH_DIR" ]]; then
        info "Creating SSH directory..."

        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
    fi
}

# ============================================================
# Domain
# ============================================================

validate_domain() {

    local domain="$1"

    # Remove trailing dot.
    domain="${domain%.}"

    if [[ -z "$domain" ]]; then
        die "Domain cannot be empty."
    fi

    if [[ "$domain" == *"://"* ]]; then
        die "Enter the domain only.

Example:
    example.com

Not:
    https://example.com"
    fi

    if [[ "$domain" == */* ]]; then
        die "Domain must not contain a path."
    fi

    if [[ "$domain" == *" "* ]]; then
        die "Domain must not contain spaces."
    fi

    echo "$domain"
}

get_domain() {

    if [[ -n "$DOMAIN" ]]; then
        DOMAIN="$(validate_domain "$DOMAIN")"
        return
    fi

    echo
    echo "Cloudflare Tunnel Domain"
    echo "─────────────────────────"
    echo
    echo "Example:"
    echo "    example.com"
    echo

    if [[ -t 0 ]]; then
        read -r -p "Domain: " DOMAIN
    elif [[ -e /dev/tty ]]; then
        read -r -p "Domain: " DOMAIN < /dev/tty
    else
        die "Interactive prompt requires terminal input. Please specify domain: <script> <domain>"
    fi

    DOMAIN="$(validate_domain "$DOMAIN")"
}

# ============================================================
# Generate SSH Config
# ============================================================

generate_config() {

    local domain="$1"

    local git_host="git-ssh.${domain}"

    cat <<EOF
${CONFIG_START}

# Gitea Git SSH via Cloudflare Tunnel
Host ${git_host}
    ProxyCommand cloudflared access ssh --hostname %h
EOF

    if [[ "$ENABLE_HOST_SSH" == true ]]; then

        local host_ssh="ssh.${domain}"

        cat <<EOF

# Server Host SSH via Cloudflare Tunnel
Host ${host_ssh}
    User %r
    ProxyCommand cloudflared access ssh --hostname %h
EOF

    fi

    cat <<EOF

${CONFIG_END}
EOF
}

# ============================================================
# Remove Generated Config
# ============================================================

remove_config_block() {

    [[ ! -f "$SSH_CONFIG" ]] && return 0

    local temp_file

    temp_file="$(mktemp)"

    awk \
        -v start="$CONFIG_START" \
        -v end="$CONFIG_END" '
        $0 == start {
            inside=1
            next
        }

        $0 == end {
            inside=0
            next
        }

        !inside {
            print
        }
    ' "$SSH_CONFIG" > "$temp_file"

    mv "$temp_file" "$SSH_CONFIG"

    chmod 600 "$SSH_CONFIG"
}

# ============================================================
# Write SSH Config
# ============================================================

write_config() {

    ensure_ssh_directory

    touch "$SSH_CONFIG"

    chmod 600 "$SSH_CONFIG"

    # Remove old configuration generated by this script.
    remove_config_block

    local config_block

    config_block="$(generate_config "$DOMAIN")"

    {
        echo
        echo "$config_block"
        echo
    } >> "$SSH_CONFIG"

    chmod 600 "$SSH_CONFIG"
}

# ============================================================
# Validate SSH Config
# ============================================================

test_ssh_config() {

    local git_host="git-ssh.${DOMAIN}"

    if ! command_exists ssh; then
        return
    fi

    if ssh -G "$git_host" >/dev/null 2>&1; then
        success "Git SSH configuration is valid."
    else
        warning "Git SSH configuration validation failed."
    fi

    if [[ "$ENABLE_HOST_SSH" == true ]]; then

        local host_ssh="ssh.${DOMAIN}"

        if ssh -G "$host_ssh" >/dev/null 2>&1; then
            success "Host SSH configuration is valid."
        else
            warning "Host SSH configuration validation failed."
        fi
    fi
}

# ============================================================
# Uninstall
# ============================================================

uninstall() {

    echo
    echo "Gitea Cloudflare SSH Uninstaller"
    echo "────────────────────────────────"
    echo

    if [[ ! -f "$SSH_CONFIG" ]]; then
        info "SSH config does not exist."
        exit 0
    fi

    if ! grep -qF "$CONFIG_START" "$SSH_CONFIG"; then
        info "No configuration created by this script was found."
        exit 0
    fi

    remove_config_block

    success "Cloudflare SSH configuration removed."

    echo
    echo "cloudflared was NOT uninstalled."
    echo
    echo "To remove cloudflared, use your OS package manager."
    echo
}

# ============================================================
# Main
# ============================================================

main() {

    detect_os
    detect_arch

    if [[ "$OS" == "unknown" ]]; then
        die "Unsupported operating system: $(uname -s)"
    fi

    if [[ "$UNINSTALL" == true ]]; then
        uninstall
        exit 0
    fi

    echo
    echo "============================================================"
    echo " Gitea Cloudflare Tunnel - SSH Client Setup"
    echo "============================================================"
    echo

    info "OS           : ${OS}"
    info "Architecture : ${ARCH}"

    if [[ "$OS" == "linux" ]]; then
        info "Distribution : ${DISTRO}"
    fi

    echo

    # --------------------------------------------------------
    # Cloudflared
    # --------------------------------------------------------

    ensure_cloudflared

    echo

    # --------------------------------------------------------
    # SSH
    # --------------------------------------------------------

    ensure_ssh

    echo

    # --------------------------------------------------------
    # Domain
    # --------------------------------------------------------

    get_domain

    echo

    local git_host="git-ssh.${DOMAIN}"
    local host_ssh="ssh.${DOMAIN}"

    echo "Configuration"
    echo "────────────────────────────────────────"

    echo
    echo "✓ Git SSH"
    echo "    ${git_host}"

    if [[ "$ENABLE_HOST_SSH" == true ]]; then
        echo
        echo "✓ Host SSH"
        echo "    ${host_ssh}"
    fi

    echo

    # --------------------------------------------------------
    # Write SSH configuration
    # --------------------------------------------------------

    info "Updating SSH configuration..."

    write_config

    success "SSH configuration updated."

    # --------------------------------------------------------
    # Validate
    # --------------------------------------------------------

    echo

    test_ssh_config

    # --------------------------------------------------------
    # Done
    # --------------------------------------------------------

    echo
    echo "============================================================"
    echo " Setup completed!"
    echo "============================================================"
    echo

    echo "Git SSH:"
    echo
    echo "    git clone git@${git_host}:USERNAME/REPOSITORY.git"
    echo

    if [[ "$ENABLE_HOST_SSH" == true ]]; then
        echo "Host SSH:"
        echo
        echo "    ssh USERNAME@${host_ssh}"
        echo
    fi

    echo "SSH config:"
    echo
    echo "    ${SSH_CONFIG}"
    echo

    echo "cloudflared:"
    echo
    echo "    cloudflared --version"
    echo

    echo "NOTE:"
    echo "cloudflared does not run as a client-side tunnel service."
    echo "SSH/Git automatically invokes cloudflared through ProxyCommand."
    echo
}

main "$@"
