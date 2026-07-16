#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.env"
LOG_FILE="$SCRIPT_DIR/install.log"

# Default mode
MODE="all"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --all) MODE="all"; shift ;;
        --gitea) MODE="gitea"; shift ;;
        --runner) MODE="runner"; shift ;;
        --proxy) MODE="proxy"; shift ;;
        --tunnel) MODE="tunnel"; shift ;;
        --backup) MODE="backup"; shift ;;
        -h|--help)
            echo "Usage: bash install.sh [OPTION]"
            echo ""
            echo "Pilihan Opsi:"
            echo "  --all       Mendeploy semua komponen (Gitea, Runner, Nginx, Tunnel, Backup) (default)"
            echo "  --gitea     Mendeploy Gitea & PostgreSQL database saja"
            echo "  --runner    Mendeploy Gitea Runner saja"
            echo "  --proxy     Mendeploy Nginx Reverse Proxy saja"
            echo "  --tunnel    Mendeploy Cloudflared Tunnel saja"
            echo "  --backup    Memasang skrip backup otomatis saja"
            echo "  -h, --help  Menampilkan bantuan ini"
            exit 0
            ;;
        *)
            echo "Error: Opsi tidak dikenal: $1"
            echo "Gunakan -h atau --help untuk panduan penggunaan."
            exit 1
            ;;
    esac
done

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Missing .env file"
    echo "copy .env.example menjadi .env dulu"
    exit 1
fi

set -a
source "$CONFIG_FILE"
set +a

# Initialize log file
echo "=== Installation Started at $(date) ===" > "$LOG_FILE"

# Source UI helper functions
source "$SCRIPT_DIR/scripts/utils/ui.sh"

# Show header
print_header

# Run validation and setup steps with loading spinner
run_with_spinner "Memvalidasi berkas konfigurasi (.env)" bash "$SCRIPT_DIR/scripts/utils/check-config.sh"

run_with_spinner "Memasang Docker & dependensi sistem" bash "$SCRIPT_DIR/scripts/setup/install-docker.sh"

run_with_spinner "Membuat direktori penyimpanan data" bash "$SCRIPT_DIR/scripts/setup/setup-directory.sh"

run_with_spinner "Menyiapkan docker network" bash "$SCRIPT_DIR/scripts/setup/setup-network.sh"

if [ "$MODE" = "all" ] || [ "$MODE" = "gitea" ]; then
    run_with_spinner "Mendeploy Gitea & PostgreSQL" bash "$SCRIPT_DIR/scripts/deploy/deploy-gitea.sh"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "runner" ]; then
    run_with_spinner "Mendeploy Gitea Runner" bash "$SCRIPT_DIR/scripts/deploy/deploy-runner.sh"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "proxy" ]; then
    run_with_spinner "Mendeploy Nginx Reverse Proxy" bash "$SCRIPT_DIR/scripts/deploy/deploy-nginx.sh"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "tunnel" ]; then
    run_with_spinner "Mendeploy Cloudflared Tunnel" bash "$SCRIPT_DIR/scripts/deploy/deploy-cloudflared.sh"
fi

if [ "$MODE" = "all" ] || [ "$MODE" = "backup" ]; then
    run_with_spinner "Memasang skrip backup otomatis" bash "$SCRIPT_DIR/scripts/backup/install-backup.sh"
fi

echo ""
echo -e "${CLR_GREEN}✔ Seluruh proses setup server selesai dengan sukses!${CLR_RESET}"
echo -e "Detail log jalannya instalasi dapat dilihat di: ${CLR_BLUE}$LOG_FILE${CLR_RESET}"