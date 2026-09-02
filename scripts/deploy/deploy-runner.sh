#!/bin/bash

set -e

echo "Checking runner configuration..."

if [ -z "$RUNNER_TOKEN" ]; then
    echo "Runner token belum tersedia (RUNNER_TOKEN kosong di .env)."
    echo "Skipping runner deployment."
    exit 0
fi

# Fallback untuk kompatibilitas konfigurasi
export RUNNER_TYPE="${RUNNER_TYPE:-linux}"
export LINUX_RUNNER_NAME="${LINUX_RUNNER_NAME:-${RUNNER_NAME:-gitea-runner-linux}}"
export LINUX_RUNNER_LABELS="${LINUX_RUNNER_LABELS:-${RUNNER_LABELS:-ubuntu-latest:docker://gitea/runner-images:ubuntu-latest}}"
export WINDOWS_RUNNER_NAME="${WINDOWS_RUNNER_NAME:-gitea-runner-windows-vm}"
export WINDOWS_RUNNER_LABELS="${WINDOWS_RUNNER_LABELS:-windows:host,windows-msbuild:host,windows-latest:host}"
export WINDOWS_VM_RAM_SIZE="${WINDOWS_VM_RAM_SIZE:-4G}"
export WINDOWS_VM_CPU_CORES="${WINDOWS_VM_CPU_CORES:-2}"
export WINDOWS_VM_DISK_SIZE="${WINDOWS_VM_DISK_SIZE:-64G}"
export WINDOWS_VM_VERSION="${WINDOWS_VM_VERSION:-2022}"

echo "Deploying Gitea Runner (Mode: $RUNNER_TYPE)..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

STACK_DIR="/opt/stacks/runner"

mkdir -p "$STACK_DIR"

# Copy compose & oem files
cp "$PROJECT_ROOT/compose/runner/docker-compose.yml" "$STACK_DIR/docker-compose.yml"
cp "$PROJECT_ROOT/compose/runner/docker-compose.linux.yml" "$STACK_DIR/docker-compose.linux.yml"
cp "$PROJECT_ROOT/compose/runner/docker-compose.windows-vm.yml" "$STACK_DIR/docker-compose.windows-vm.yml"
cp -r "$PROJECT_ROOT/compose/runner/oem" "$STACK_DIR/oem"

# Generate .env file di folder stack
envsubst < "$PROJECT_ROOT/compose/runner/.env.template" > "$STACK_DIR/.env"

# Setup folder & config sesuai RUNNER_TYPE
if [ "$RUNNER_TYPE" = "linux" ] || [ "$RUNNER_TYPE" = "both" ]; then
    mkdir -p "$DATA_DIR/runner-linux"
    envsubst '$DOCKER_NETWORK' < "$PROJECT_ROOT/compose/runner/config.yaml" \
    > "$DATA_DIR/runner-linux/config.yaml"
fi

if [ "$RUNNER_TYPE" = "windows" ] || [ "$RUNNER_TYPE" = "windows-vm" ] || [ "$RUNNER_TYPE" = "both" ]; then
    mkdir -p "$DATA_DIR/runner-windows-vm"
    
    # Cek ketersediaan KVM
    if [ ! -e /dev/kvm ]; then
        echo "========================================================================="
        echo "CATATAN / PERHATIAN:"
        echo "Perangkat /dev/kvm tidak ditemukan di server Linux ini."
        echo "dockur/windows memerlukan KVM hardware virtualization untuk jalankan Windows VM."
        echo "Pastikan KVM diaktifkan pada BIOS atau VPS provider Anda."
        echo "========================================================================="
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
