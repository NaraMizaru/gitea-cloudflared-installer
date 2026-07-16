#!/bin/bash

set -e

APP_NAME="Gitea + Cloudflared Installer"

echo "================================="
echo "$APP_NAME"
echo "================================="

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


echo "[1/2] Installing Docker"
bash "$SCRIPT_DIR/scripts/install-docker.sh"


echo "[2/2] Setup directory"
bash "$SCRIPT_DIR/scripts/setup-directory.sh"

echo ""
echo "[3/3] Setup Docker network"
bash "$SCRIPT_DIR/scripts/setup-network.sh"