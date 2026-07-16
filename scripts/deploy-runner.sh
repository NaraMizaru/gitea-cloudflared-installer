#!/bin/bash

set -e

echo "Checking runner configuration..."

if [ -z "$RUNNER_TOKEN" ]; then
    echo "Runner token belum tersedia."
    echo "Skipping runner deployment."

    exit 0
fi

echo "Deploying Gitea Runner..."

STACK_DIR="/opt/stacks/runner"

mkdir -p "$STACK_DIR"
mkdir -p "$DATA_DIR/runner"

cp compose/runner/docker-compose.yml \
$STACK_DIR/docker-compose.yml

envsubst '$DOCKER_NETWORK' < compose/runner/config.yaml \
> "$DATA_DIR/runner/config.yaml"

envsubst < compose/runner/.env.template \
> $STACK_DIR/.env

cd $STACK_DIR

docker compose up -d

echo "Runner deployed"