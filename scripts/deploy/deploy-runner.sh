#!/bin/bash

set -e

echo "Checking runner configuration..."

if [ -z "$RUNNER_TOKEN" ]; then
    echo "Runner token belum tersedia."
    echo "Skipping runner deployment."

    exit 0
fi

echo "Deploying Gitea Runner..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

STACK_DIR="/opt/stacks/runner"

mkdir -p "$STACK_DIR"
mkdir -p "$DATA_DIR/runner"

cp "$PROJECT_ROOT/compose/runner/docker-compose.yml" \
"$STACK_DIR/docker-compose.yml"

envsubst '$DOCKER_NETWORK' < "$PROJECT_ROOT/compose/runner/config.yaml" \
> "$DATA_DIR/runner/config.yaml"

envsubst < "$PROJECT_ROOT/compose/runner/.env.template" \
> "$STACK_DIR/.env"

cd "$STACK_DIR"

docker compose up -d

echo "Runner deployed"
