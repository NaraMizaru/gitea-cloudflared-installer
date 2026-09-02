#!/bin/bash

set -e

echo "Checking Cloudflare Tunnel configuration..."
if [ -z "$CLOUDFLARE_TOKEN" ]; then
    echo "Cloudflare tunnel token belum tersedia."
    echo "Skipping Cloudflared deployment."
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STACK_DIR="/opt/stacks/cloudflared"

mkdir -p "$STACK_DIR"

NEW_ENV=$(envsubst < "$PROJECT_ROOT/compose/cloudflared/.env.template")

CLOUDFLARED_RUNNING=$(docker ps --filter "name=^cloudflared$" --filter "status=running" -q 2>/dev/null || true)

CONFIG_MATCH=false
if [ -f "$STACK_DIR/docker-compose.yml" ] && [ -f "$STACK_DIR/.env" ]; then
    if cmp -s "$PROJECT_ROOT/compose/cloudflared/docker-compose.yml" "$STACK_DIR/docker-compose.yml" && \
       [ "$NEW_ENV" = "$(cat "$STACK_DIR/.env" 2>/dev/null)" ]; then
        CONFIG_MATCH=true
    fi
fi

if [ -n "$CLOUDFLARED_RUNNING" ] && [ "$CONFIG_MATCH" = true ] && [ "$1" != "--force" ]; then
    echo "Cloudflared Tunnel sudah terpasang, aktif, dan up-to-date. Melewati instalasi ulang."
    exit 0
fi

echo "Deploying Cloudflared..."

cp "$PROJECT_ROOT/compose/cloudflared/docker-compose.yml" "$STACK_DIR/docker-compose.yml"
echo "$NEW_ENV" > "$STACK_DIR/.env"

cd "$STACK_DIR"
docker compose up -d

echo "Cloudflared deployed"
