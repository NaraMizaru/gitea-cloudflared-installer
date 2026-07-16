#!/bin/bash

set -e


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