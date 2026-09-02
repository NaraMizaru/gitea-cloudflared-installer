#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STACK_DIR="/opt/stacks/nginx"

mkdir -p "$STACK_DIR/conf.d"

NEW_ENV=$(envsubst < "$PROJECT_ROOT/compose/nginx/.env.template")
NEW_CONF=$(envsubst '$DOMAIN' < "$PROJECT_ROOT/compose/nginx/conf.d/gitea.conf")

NGINX_RUNNING=$(docker ps --filter "name=^nginx$" --filter "status=running" -q 2>/dev/null || true)

CONFIG_MATCH=false
if [ -f "$STACK_DIR/docker-compose.yml" ] && [ -f "$STACK_DIR/.env" ] && [ -f "$STACK_DIR/conf.d/gitea.conf" ]; then
    if cmp -s "$PROJECT_ROOT/compose/nginx/docker-compose.yml" "$STACK_DIR/docker-compose.yml" && \
       [ "$NEW_ENV" = "$(cat "$STACK_DIR/.env" 2>/dev/null)" ] && \
       [ "$NEW_CONF" = "$(cat "$STACK_DIR/conf.d/gitea.conf" 2>/dev/null)" ]; then
        CONFIG_MATCH=true
    fi
fi

if [ -n "$NGINX_RUNNING" ] && [ "$CONFIG_MATCH" = true ] && [ "$1" != "--force" ]; then
    echo "Nginx Reverse Proxy sudah terpasang, aktif, dan up-to-date. Melewati instalasi ulang."
    exit 0
fi

echo "Deploying Nginx..."

cp -r "$PROJECT_ROOT"/compose/nginx/* "$STACK_DIR"
echo "$NEW_ENV" > "$STACK_DIR/.env"
echo "$NEW_CONF" > "$STACK_DIR/conf.d/gitea.conf"

cd "$STACK_DIR"
docker compose up -d

echo "Nginx deployed"
