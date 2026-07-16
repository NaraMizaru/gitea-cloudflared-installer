#!/bin/bash

set -e

echo "Checking Cloudflare Tunnel configuration..."
if [ -z "$CLOUDFLARE_TOKEN" ]; then
    echo "Cloudflare tunnel token belum tersedia."
    echo "Skipping Cloudflared deployment."
    exit 0
fi

echo "Deploying Cloudflared..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

STACK_DIR="/opt/stacks/cloudflared"

mkdir -p "$STACK_DIR"

cp "$PROJECT_ROOT/compose/cloudflared/docker-compose.yml" \
"$STACK_DIR/docker-compose.yml"

envsubst < "$PROJECT_ROOT/compose/cloudflared/.env.template" \
> "$STACK_DIR/.env"

cd "$STACK_DIR"

docker compose up -d

echo "Cloudflared deployed"
