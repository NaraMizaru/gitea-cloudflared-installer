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

cp compose/runner/docker-compose.yml \
$STACK_DIR/docker-compose.yml

cp compose/runner/config.yaml \
/srv/data/runner/config.yaml

envsubst < compose/runner/.env.template \
> $STACK_DIR/.env

cd $STACK_DIR

docker compose up -d

echo "Runner deployed"