#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.env"
EXAMPLE_CONFIG="$SCRIPT_DIR/.env.example"

# ANSI Colors
CLR_BLUE="\e[38;5;39m"
CLR_CYAN="\e[38;5;81m"
CLR_GREEN="\e[32;1m"
CLR_YELLOW="\e[33;1m"
CLR_RED="\e[31;1m"
CLR_GRAY="\e[38;5;244m"
CLR_RESET="\e[0m"

DO_GIT_PULL=true
DO_PULL_IMAGES=false
PASSTHROUGH_ARGS=()

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --no-pull)
            DO_GIT_PULL=false
            shift
            ;;
        --pull-images)
            DO_PULL_IMAGES=true
            shift
            ;;
        -h|--help)
            echo -e "${CLR_CYAN}Gitea Stack Updater${CLR_RESET}"
            echo "Usage: ./update.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --no-pull        Lewati 'git pull' (hanya re-deploy konfigurasi lokal)"
            echo "  --pull-images    Tarik Docker image versi terbaru saat update"
            echo "  --all            Update & re-deploy seluruh stack (default)"
            echo "  --gitea          Update & re-deploy Gitea & PostgreSQL"
            echo "  --runner         Update & re-deploy Gitea Runner"
            echo "  --proxy          Update & re-deploy Nginx Reverse Proxy"
            echo "  --tunnel         Update & re-deploy Cloudflared Tunnel"
            echo "  --backup         Update skrip backup otomatis"
            echo "  -h, --help       Menampilkan panduan ini"
            exit 0
            ;;
        *)
            PASSTHROUGH_ARGS+=("$1")
            shift
            ;;
    esac
done

echo -e "${CLR_BLUE}===============================================${CLR_RESET}"
echo -e "${CLR_CYAN}         Gitea Stack - Update Manager          ${CLR_RESET}"
echo -e "${CLR_BLUE}===============================================${CLR_RESET}"
echo ""

# 1. Git Pull
if [ "$DO_GIT_PULL" = true ]; then
    echo -e "${CLR_CYAN}==> [1/3] Mengambil pembaruan repositori dari Git...${CLR_RESET}"
    if [ -d "$SCRIPT_DIR/.git" ]; then
        git pull || {
            echo -e "${CLR_YELLOW}Peringatan: Gagal menjalankan git pull. Melanjutkan dengan file lokal...${CLR_RESET}"
        }
    else
        echo -e "${CLR_GRAY}Bukan repositori git (.git tidak ditemukan), melewati git pull.${CLR_RESET}"
    fi
else
    echo -e "${CLR_GRAY}==> Melewati git pull (--no-pull diaktifkan)${CLR_RESET}"
fi

echo ""

# 2. Check .env vs .env.example
echo -e "${CLR_CYAN}==> [2/3] Memeriksa kelengkapan konfigurasi .env...${CLR_RESET}"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${CLR_RED}ERROR: Berkas .env belum ada.${CLR_RESET}"
    echo "Silakan salin .env.example menjadi .env lalu isi nilainya:"
    echo "  cp .env.example .env"
    exit 1
fi

if [ -f "$EXAMPLE_CONFIG" ]; then
    MISSING_KEYS=()
    while IFS='=' read -r key value || [ -n "$key" ]; do
        # Trim leading/trailing whitespace
        key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        # Skip comments and empty lines
        [[ -z "$key" || "$key" =~ ^# ]] && continue
        
        # Check if key exists in .env
        if ! grep -q "^[[:space:]]*$key=" "$CONFIG_FILE" && ! grep -q "^[[:space:]]*$key[[:space:]]*=" "$CONFIG_FILE"; then
            MISSING_KEYS+=("$key")
        fi
    done < "$EXAMPLE_CONFIG"

    if [ ${#MISSING_KEYS[@]} -gt 0 ]; then
        echo -e "${CLR_YELLOW}Perhatian: Ditemukan variabel baru di .env.example yang belum ada di .env Anda:${CLR_RESET}"
        for k in "${MISSING_KEYS[@]}"; do
            echo -e "  - ${CLR_YELLOW}$k${CLR_RESET}"
        done
        echo -e "${CLR_GRAY}Anda mungkin ingin memeriksa .env.example untuk melihat opsi baru tersebut.${CLR_RESET}"
        echo ""
    else
        echo -e "${CLR_GREEN}✔ Konfigurasi .env sinkron dengan template terbaru.${CLR_RESET}"
    fi
fi

echo ""

# 3. Pull Images (Optional)
if [ "$DO_PULL_IMAGES" = true ]; then
    echo -e "${CLR_CYAN}==> Menarik docker images versi terbaru...${CLR_RESET}"
    for stack in gitea nginx cloudflared runner; do
        if [ -f "/opt/stacks/$stack/docker-compose.yml" ]; then
            echo -e "  Pulling images for $stack..."
            docker compose -f "/opt/stacks/$stack/docker-compose.yml" pull || true
        fi
    done
    echo ""
fi

# 4. Re-deploy using install.sh
echo -e "${CLR_CYAN}==> [3/3] Menerapkan konfigurasi & memperbarui stack...${CLR_RESET}"
bash "$SCRIPT_DIR/install.sh" "${PASSTHROUGH_ARGS[@]}"

echo ""
echo -e "${CLR_GREEN}✔ Pembaruan stack berhasil diselesaikan!${CLR_RESET}"
