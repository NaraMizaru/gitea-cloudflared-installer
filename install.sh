#!/bin/bash

set -e
MODE=${1:-all}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Missing .env file"
    echo "copy .env.example menjadi .env dulu"
    exit 1
fi

set -a
source "$CONFIG_FILE"
set +a

bash "$SCRIPT_DIR/scripts/utils/check-config.sh"

echo "================================="
echo " Gitea + Cloudflared Installer"
echo "================================="


echo ""
echo "[1] Install Docker"
bash "$SCRIPT_DIR/scripts/setup/install-docker.sh"


echo ""
echo "[2] Setup directories"
bash "$SCRIPT_DIR/scripts/setup/setup-directory.sh"


echo ""
echo "[3] Setup Docker network"
bash "$SCRIPT_DIR/scripts/setup/setup-network.sh"

if [ "$MODE" = "all" ] || [ "$MODE" = "gitea" ]; then
    echo ""
    echo "[4] Deploy Gitea"
    bash "$SCRIPT_DIR/scripts/deploy/deploy-gitea.sh"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "runner" ]; then
    echo ""
    echo "[5] Deploy Runner"
    bash "$SCRIPT_DIR/scripts/deploy/deploy-runner.sh"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "proxy" ]; then
    echo ""
    echo "[6] Deploy Nginx"
    bash "$SCRIPT_DIR/scripts/deploy/deploy-nginx.sh"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "tunnel" ]; then
    echo ""
    echo "[7] Deploy Cloudflared"
    bash "$SCRIPT_DIR/scripts/deploy/deploy-cloudflared.sh"
fi

if [ "$MODE" = "all" ]; then
    echo ""
    echo "[8] Install Backup"
    bash "$SCRIPT_DIR/scripts/backup/install-backup.sh"
fi

echo ""
echo "Base server setup complete!"