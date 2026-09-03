#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STACK_DIR="/opt/stacks/runner"

# Load environment file jika ada
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Fallback untuk kompatibilitas konfigurasi
export RUNNER_TYPE="${RUNNER_TYPE:-linux}"
export LINUX_RUNNER_NAME="${LINUX_RUNNER_NAME:-${RUNNER_NAME:-gitea-runner-linux}}"
export LINUX_RUNNER_LABELS="${LINUX_RUNNER_LABELS:-${RUNNER_LABELS:-ubuntu-latest:docker://gitea/runner-images:ubuntu-latest}}"
export LINUX_RUNNER_TOKEN="${LINUX_RUNNER_TOKEN:-${RUNNER_TOKEN}}"

export WINDOWS_RUNNER_NAME="${WINDOWS_RUNNER_NAME:-gitea-runner-windows-vm}"
export WINDOWS_RUNNER_LABELS="${WINDOWS_RUNNER_LABELS:-windows:host,windows-msbuild:host,windows-latest:host,windows-node:host,windows-dotnet:host}"
export WINDOWS_RUNNER_TOKEN="${WINDOWS_RUNNER_TOKEN:-${RUNNER_TOKEN}}"
export WINDOWS_VM_RAM_SIZE="${WINDOWS_VM_RAM_SIZE:-4G}"
export WINDOWS_VM_CPU_CORES="${WINDOWS_VM_CPU_CORES:-2}"
export WINDOWS_VM_DISK_SIZE="${WINDOWS_VM_DISK_SIZE:-100G}"
export WINDOWS_VM_VERSION="${WINDOWS_VM_VERSION:-2022}"
export WINDOWS_VM_VNC_PORT="${WINDOWS_VM_VNC_PORT:-127.0.0.1:8006}"

export DATA_DIR="${DATA_DIR:-/srv/data}"
export DOCKER_NETWORK="${DOCKER_NETWORK:-git-network}"
export DOMAIN="${DOMAIN:-localhost}"

# Validasi token sesuai RUNNER_TYPE yang dipilih
case "$RUNNER_TYPE" in
    linux)
        if [ -z "$LINUX_RUNNER_TOKEN" ]; then
            echo "LINUX_RUNNER_TOKEN (atau RUNNER_TOKEN) belum tersedia di .env."
            echo "Skipping runner deployment."
            exit 0
        fi
        ;;
    windows|windows-vm)
        if [ -z "$WINDOWS_RUNNER_TOKEN" ]; then
            echo "WINDOWS_RUNNER_TOKEN (atau RUNNER_TOKEN) belum tersedia di .env."
            echo "Skipping runner deployment."
            exit 0
        fi
        ;;
    both|both-vm)
        if [ -z "$LINUX_RUNNER_TOKEN" ] && [ -z "$WINDOWS_RUNNER_TOKEN" ]; then
            echo "Runner token (LINUX_RUNNER_TOKEN / WINDOWS_RUNNER_TOKEN / RUNNER_TOKEN) belum tersedia di .env."
            echo "Skipping runner deployment."
            exit 0
        fi
        ;;
esac

mkdir -p "$STACK_DIR"

# Check if target runner containers are already running
LINUX_RUNNING=$(docker ps --filter "name=^${LINUX_RUNNER_NAME}$" --filter "status=running" -q 2>/dev/null || true)
WINDOWS_RUNNING=$(docker ps --filter "name=^${WINDOWS_RUNNER_NAME}$" --filter "status=running" -q 2>/dev/null || true)

ALL_RUNNING=false
case "$RUNNER_TYPE" in
    linux)
        [ -n "$LINUX_RUNNING" ] && ALL_RUNNING=true
        ;;
    windows|windows-vm)
        [ -n "$WINDOWS_RUNNING" ] && ALL_RUNNING=true
        ;;
    both|both-vm)
        [ -n "$LINUX_RUNNING" ] && [ -n "$WINDOWS_RUNNING" ] && ALL_RUNNING=true
        ;;
esac

NEW_ENV=$(envsubst < "$PROJECT_ROOT/compose/runner/.env.template")

CONFIG_MATCH=false
if [ -f "$STACK_DIR/docker-compose.yml" ] && [ -f "$STACK_DIR/.env" ]; then
    if cmp -s "$PROJECT_ROOT/compose/runner/docker-compose.yml" "$STACK_DIR/docker-compose.yml" && \
       [ "$NEW_ENV" = "$(cat "$STACK_DIR/.env" 2>/dev/null)" ]; then
        CONFIG_MATCH=true
    fi
fi

if [ "$ALL_RUNNING" = true ] && [ "$CONFIG_MATCH" = true ] && [ "$1" != "--force" ]; then
    echo "Gitea Runner ($RUNNER_TYPE) sudah terpasang, aktif, dan up-to-date. Melewati instalasi ulang."
    exit 0
fi

echo "Deploying Gitea Runner (Mode: $RUNNER_TYPE)..."

# Copy compose & oem files cleanly
cp "$PROJECT_ROOT/compose/runner/docker-compose.yml" "$STACK_DIR/docker-compose.yml"
cp "$PROJECT_ROOT/compose/runner/docker-compose.linux.yml" "$STACK_DIR/docker-compose.linux.yml"
cp "$PROJECT_ROOT/compose/runner/docker-compose.windows-vm.yml" "$STACK_DIR/docker-compose.windows-vm.yml"

rm -rf "$STACK_DIR/oem"
mkdir -p "$STACK_DIR/oem"
cp -r "$PROJECT_ROOT/compose/runner/oem/." "$STACK_DIR/oem/"

echo "$NEW_ENV" > "$STACK_DIR/.env"

# Setup folder & config sesuai RUNNER_TYPE
if [ "$RUNNER_TYPE" = "linux" ] || [ "$RUNNER_TYPE" = "both" ] || [ "$RUNNER_TYPE" = "both-vm" ]; then
    mkdir -p "$DATA_DIR/runner-linux"
    CONFIG_SRC="$PROJECT_ROOT/compose/runner/config.linux.yaml"
    if [ ! -f "$CONFIG_SRC" ]; then CONFIG_SRC="$PROJECT_ROOT/compose/runner/config.yaml"; fi
    envsubst '$DOCKER_NETWORK' < "$CONFIG_SRC" > "$DATA_DIR/runner-linux/config.yaml"
    
    # Hapus .runner jika file kosong/korup agar container otomatis meregistrasi ulang
    if [ -f "$DATA_DIR/runner-linux/.runner" ] && [ ! -s "$DATA_DIR/runner-linux/.runner" ]; then
        rm -f "$DATA_DIR/runner-linux/.runner"
    fi
fi

if [ "$RUNNER_TYPE" = "windows" ] || [ "$RUNNER_TYPE" = "windows-vm" ] || [ "$RUNNER_TYPE" = "both" ] || [ "$RUNNER_TYPE" = "both-vm" ]; then
    mkdir -p "$DATA_DIR/runner-windows-vm"
    
    ACTUAL_GITEA_URL="https://${DOMAIN}"
    ACTUAL_TOKEN="${WINDOWS_RUNNER_TOKEN:-${RUNNER_TOKEN}}"
    ACTUAL_RUNNER_NAME="${WINDOWS_RUNNER_NAME:-gitea-runner-windows-vm}"
    ACTUAL_LABELS="${WINDOWS_RUNNER_LABELS:-windows:host,windows-msbuild:host,windows-latest:host}"

    # Generate runner-env.ps1 dengan token dan domain sebenarnya
    cat <<EOF > "$STACK_DIR/oem/runner-env.ps1"
\$GiteaUrl = "${ACTUAL_GITEA_URL}"
\$Token = "${ACTUAL_TOKEN}"
\$RunnerName = "${ACTUAL_RUNNER_NAME}"
\$Labels = "${ACTUAL_LABELS}"
EOF

    # Salin template config windows ke oem
    if [ -f "$PROJECT_ROOT/compose/runner/config.windows-vm.yaml" ]; then
        cp "$PROJECT_ROOT/compose/runner/config.windows-vm.yaml" "$STACK_DIR/oem/config.windows-vm.yaml"
    fi

    # Pre-download binary gitea-runner.exe ke folder OEM agar VM tidak perlu download dari internet
    if [ ! -f "$STACK_DIR/oem/gitea-runner.exe" ]; then
        echo "Mengunduh binary gitea-runner.exe untuk disuntikkan ke Windows VM..."
        curl -fsSL --connect-timeout 10 -m 120 "https://gitea.com/gitea/runner/releases/download/v3.3.2/gitea-runner-3.3.2-windows-amd64.exe" -o "$STACK_DIR/oem/gitea-runner.exe" 2>/dev/null || rm -f "$STACK_DIR/oem/gitea-runner.exe"
    fi

    # Cek ketersediaan KVM
    if [ ! -e /dev/kvm ]; then
        echo "========================================================================="
        echo "CATATAN / PERHATIAN:"
        echo "Perangkat /dev/kvm tidak ditemukan di server Linux ini."
        echo "Menonaktifkan mapping device /dev/kvm agar kontainer tetap bisa berjalan..."
        echo "========================================================================="
        sed -i '/\/dev\/kvm/d' "$STACK_DIR/docker-compose.yml"
        sed -i '/devices:/d' "$STACK_DIR/docker-compose.yml"
    fi
fi

cd "$STACK_DIR"

if [ "$RUNNER_TYPE" = "linux" ]; then
    docker compose --profile linux up -d
elif [ "$RUNNER_TYPE" = "windows" ] || [ "$RUNNER_TYPE" = "windows-vm" ]; then
    docker compose --profile windows up -d
elif [ "$RUNNER_TYPE" = "both" ] || [ "$RUNNER_TYPE" = "both-vm" ]; then
    docker compose --profile both up -d
else
    echo "Peringatan: RUNNER_TYPE '$RUNNER_TYPE' tidak dikenal. Menggunakan mode default (linux)."
    docker compose --profile linux up -d
fi

echo "Gitea Runner deployment completed ($RUNNER_TYPE)."
