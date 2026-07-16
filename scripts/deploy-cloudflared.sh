#!/bin/bash

set -e


echo "Checking Cloudflare Tunnel configuration..."
if [ -z "$CLOUDFLARE_TOKEN" ]; then

    echo "Cloudflare tunnel token belum tersedia."
    echo "Skipping Cloudflared deployment."

    exit 0

fi

echo "Deploying Cloudflared..."

STACK_DIR="/opt/stacks/cloudflared"

mkdir -p "$STACK_DIR"

cp compose/cloudflared/docker-compose.yml \
"$STACK_DIR/docker-compose.yml"

envsubst < compose/cloudflared/.env.template \
> $STACK_DIR/.env

cd "$STACK_DIR"

docker compose up -d

echo "Cloudflared deployed"