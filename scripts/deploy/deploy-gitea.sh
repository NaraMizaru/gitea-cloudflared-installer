#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STACK_DIR="/opt/stacks/gitea"

mkdir -p "$STACK_DIR"

# Generate new .env content in memory
NEW_ENV=$(envsubst < "$PROJECT_ROOT/compose/gitea/.env.template")

# Check if containers are already running
GITEA_RUNNING=$(docker ps --filter "name=^gitea$" --filter "status=running" -q 2>/dev/null || true)
POSTGRES_RUNNING=$(docker ps --filter "name=^postgres$" --filter "status=running" -q 2>/dev/null || true)

# Check if compose & env files match
CONFIG_MATCH=false
if [ -f "$STACK_DIR/docker-compose.yml" ] && [ -f "$STACK_DIR/.env" ]; then
    if cmp -s "$PROJECT_ROOT/compose/gitea/docker-compose.yml" "$STACK_DIR/docker-compose.yml" && \
       [ "$NEW_ENV" = "$(cat "$STACK_DIR/.env" 2>/dev/null)" ]; then
        CONFIG_MATCH=true
    fi
fi

if [ -n "$GITEA_RUNNING" ] && [ -n "$POSTGRES_RUNNING" ] && [ "$CONFIG_MATCH" = true ] && [ "$1" != "--force" ]; then
    echo "Gitea & PostgreSQL sudah terpasang, aktif, dan up-to-date. Melewati instalasi ulang."
    exit 0
fi

echo "Deploying Gitea & PostgreSQL..."

cp "$PROJECT_ROOT/compose/gitea/docker-compose.yml" "$STACK_DIR/docker-compose.yml"
echo "$NEW_ENV" > "$STACK_DIR/.env"

cd "$STACK_DIR"
docker compose up -d

echo ""
echo "Gitea deployment finished"
