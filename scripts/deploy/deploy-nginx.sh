#!/bin/bash

set -e

echo "Deploying Nginx..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

STACK_DIR="/opt/stacks/nginx"

mkdir -p "$STACK_DIR"

cp -r "$PROJECT_ROOT"/compose/nginx/* "$STACK_DIR"

envsubst < "$PROJECT_ROOT/compose/nginx/.env.template" \
> "$STACK_DIR/.env"

envsubst '$DOMAIN' < "$PROJECT_ROOT/compose/nginx/conf.d/gitea.conf" \
> "$STACK_DIR/conf.d/gitea.conf"

cd "$STACK_DIR"

docker compose up -d

echo "Nginx deployed"
