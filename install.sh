#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Missing config.env"
    echo "copy config.env.example menjadi config.env dulu"
    exit 1
fi

source "$CONFIG_FILE"


echo "================================="
echo " Gitea + Cloudflared Installer"
echo "================================="


echo ""
echo "[1] Install Docker"
bash "$SCRIPT_DIR/scripts/install-docker.sh"


echo ""
echo "[2] Setup directories"
bash "$SCRIPT_DIR/scripts/setup-directory.sh"


echo ""
echo "[3] Setup Docker network"
bash "$SCRIPT_DIR/scripts/setup-network.sh"

echo ""
echo "[4] Deploy Gitea"
bash "$SCRIPT_DIR/scripts/deploy-gitea.sh"

echo ""
echo "[5] Deploy Runner"
bash "$SCRIPT_DIR/scripts/deploy-runner.sh"

echo ""
echo "[6] Deploy Nginx"
bash "$SCRIPT_DIR/scripts/deploy-nginx.sh"

echo ""
echo "Base server setup complete!"