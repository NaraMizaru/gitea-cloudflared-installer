.PHONY: help install force-install install-gitea install-runner install-proxy install-tunnel install-backup update update-pull-images pull pull-images up down restart status ps logs logs-gitea logs-runner logs-proxy logs-tunnel backup reset-runner check-env setup-ssh

.DEFAULT_GOAL := help

# ANSI Color codes
CLR_RESET   = \033[0m
CLR_BOLD    = \033[1m
CLR_CYAN    = \033[36m
CLR_GREEN   = \033[32m
CLR_YELLOW  = \033[33m
CLR_BLUE    = \033[34m

help: ## Menampilkan panduan daftar perintah yang tersedia
	@printf "$(CLR_BOLD)$(CLR_BLUE)===================================================$(CLR_RESET)\n"
	@printf "$(CLR_BOLD)$(CLR_CYAN)    Gitea + Cloudflared Stack - Management CLI    $(CLR_RESET)\n"
	@printf "$(CLR_BOLD)$(CLR_BLUE)===================================================$(CLR_RESET)\n"
	@printf "$(CLR_BOLD)Penggunaan:$(CLR_RESET) make $(CLR_CYAN)<target>$(CLR_RESET)\n\n"
	@printf "$(CLR_BOLD)Daftar Perintah:$(CLR_RESET)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@printf "\n"

# -----------------------------------------------------------------------------
# Instalasi & Update
# -----------------------------------------------------------------------------

install: ## Install seluruh stack (otomatis melewati komponen yang sudah terpasang & up-to-date)
	@bash install.sh --all

force-install: ## Paksa install / deploy ulang seluruh stack tanpa melewati komponen yang sudah aktif
	@bash install.sh --all --force

install-gitea: ## Install / deploy Gitea & PostgreSQL saja
	@bash install.sh --gitea

install-runner: ## Install / deploy Gitea Runner saja
	@bash install.sh --runner

install-proxy: ## Install / deploy Nginx Reverse Proxy saja
	@bash install.sh --proxy

install-tunnel: ## Install / deploy Cloudflared Tunnel saja
	@bash install.sh --tunnel

install-backup: ## Pasang cron script backup otomatis saja
	@bash install.sh --backup

update: ## Ambil update terbaru dari Git dan re-deploy seluruh konfigurasi stack
	@bash update.sh

update-pull-images: ## Ambil update dari Git + tarik Docker image terbaru lalu re-deploy
	@bash update.sh --pull-images

pull: ## Jalankan git pull saja
	@git pull

pull-images: ## Tarik update versi Docker image terbaru untuk semua stack
	@echo "Menarik Docker image terbaru..."
	@[ -f /opt/stacks/gitea/docker-compose.yml ] && docker compose -f /opt/stacks/gitea/docker-compose.yml pull || true
	@[ -f /opt/stacks/nginx/docker-compose.yml ] && docker compose -f /opt/stacks/nginx/docker-compose.yml pull || true
	@[ -f /opt/stacks/cloudflared/docker-compose.yml ] && docker compose -f /opt/stacks/cloudflared/docker-compose.yml pull || true
	@[ -f /opt/stacks/runner/docker-compose.yml ] && docker compose -f /opt/stacks/runner/docker-compose.yml pull || true

check-env: ## Periksa kelengkapan konfigurasi .env terhadap template .env.example
	@bash -c 'source scripts/utils/ui.sh; bash update.sh --no-pull'

# -----------------------------------------------------------------------------
# Manajemen Service Docker
# -----------------------------------------------------------------------------

up: ## Jalankan / aktifkan seluruh container service di background
	@[ -f /opt/stacks/gitea/docker-compose.yml ] && docker compose -f /opt/stacks/gitea/docker-compose.yml up -d || true
	@[ -f /opt/stacks/nginx/docker-compose.yml ] && docker compose -f /opt/stacks/nginx/docker-compose.yml up -d || true
	@[ -f /opt/stacks/cloudflared/docker-compose.yml ] && docker compose -f /opt/stacks/cloudflared/docker-compose.yml up -d || true
	@[ -f /opt/stacks/runner/docker-compose.yml ] && docker compose -f /opt/stacks/runner/docker-compose.yml up -d || true

down: ## Hentikan seluruh container service
	@[ -f /opt/stacks/runner/docker-compose.yml ] && docker compose -f /opt/stacks/runner/docker-compose.yml down || true
	@[ -f /opt/stacks/cloudflared/docker-compose.yml ] && docker compose -f /opt/stacks/cloudflared/docker-compose.yml down || true
	@[ -f /opt/stacks/nginx/docker-compose.yml ] && docker compose -f /opt/stacks/nginx/docker-compose.yml down || true
	@[ -f /opt/stacks/gitea/docker-compose.yml ] && docker compose -f /opt/stacks/gitea/docker-compose.yml down || true

restart: ## Restart seluruh container service
	@[ -f /opt/stacks/gitea/docker-compose.yml ] && docker compose -f /opt/stacks/gitea/docker-compose.yml restart || true
	@[ -f /opt/stacks/nginx/docker-compose.yml ] && docker compose -f /opt/stacks/nginx/docker-compose.yml restart || true
	@[ -f /opt/stacks/cloudflared/docker-compose.yml ] && docker compose -f /opt/stacks/cloudflared/docker-compose.yml restart || true
	@[ -f /opt/stacks/runner/docker-compose.yml ] && docker compose -f /opt/stacks/runner/docker-compose.yml restart || true

status: ps ## Cek status container semua service (alias: ps)

ps: ## Cek status running seluruh container stack
	@docker ps --filter "label=com.docker.compose.project" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

logs: ## Pantau log container (cth: make logs s=gitea atau make logs-gitea)
	@if [ -n "$(s)" ]; then \
		docker compose -f /opt/stacks/$(s)/docker-compose.yml logs -f --tail=100; \
	else \
		echo "Silakan gunakan format: make logs s=<stack_name> (gitea/nginx/cloudflared/runner)"; \
		echo "atau gunakan shorthand: make logs-gitea, make logs-runner, make logs-proxy, make logs-tunnel"; \
	fi

logs-gitea: ## Pantau log Gitea & PostgreSQL
	@docker compose -f /opt/stacks/gitea/docker-compose.yml logs -f --tail=100

logs-runner: ## Pantau log Gitea Runner
	@docker compose -f /opt/stacks/runner/docker-compose.yml logs -f --tail=100

logs-proxy: ## Pantau log Nginx Reverse Proxy
	@docker compose -f /opt/stacks/nginx/docker-compose.yml logs -f --tail=100

logs-tunnel: ## Pantau log Cloudflared Tunnel
	@docker compose -f /opt/stacks/cloudflared/docker-compose.yml logs -f --tail=100

# -----------------------------------------------------------------------------
# Utilitas & Backup
# -----------------------------------------------------------------------------

backup: ## Jalankan proses pencadangan (backup) Gitea & database secara manual
	@if [ -f /usr/local/bin/backup-gitea.sh ]; then \
		sudo /usr/local/bin/backup-gitea.sh; \
	else \
		bash scripts/backup/backup-gitea.sh; \
	fi

reset-runner: ## Hentikan & hapus seluruh data runner (Linux & Windows VM) untuk reset bersih
	@echo "Menghentikan seluruh container runner..."
	@[ -f /opt/stacks/runner/docker-compose.yml ] && docker compose -f /opt/stacks/runner/docker-compose.yml down -v 2>/dev/null || true
	@docker rm -f gitea-runner-linux gitea-runner-windows gitea-runner-windows-vm 2>/dev/null || true
	@echo "Membersihkan folder data runner..."
	@sudo rm -rf /srv/data/runner-linux /srv/data/runner-windows-vm /opt/stacks/runner/oem
	@echo "Data runner berhasil dibersihkan dan siap dideploy ulang!"

setup-ssh: ## Jalankan panduan konfigurasi SSH client
	@bash setup-ssh.sh
