#!/bin/bash

set -e

echo "Deploying Gitea ..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

STACK_DIR="/opt/stacks/gitea"

cp "$PROJECT_ROOT/compose/gitea/docker-compose.yml" \
"$STACK_DIR/docker-compose.yml"

envsubst < "$PROJECT_ROOT/compose/gitea/.env.template" \
> "$STACK_DIR/.env"

cd "$STACK_DIR"

docker compose up -d

echo ""
echo "Gitea deployment finished"
