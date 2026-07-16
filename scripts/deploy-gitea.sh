#!/bin/bash

set -e

echo "Deploying Gitea ..."

STACK_DIR="/opt/stacks/gitea"

cp compose/gitea/docker-compose.yml \
$STACK_DIR/docker-compose.yml

envsubst < compose/gitea/.env.template \
> $STACK_DIR/.env

cd $STACK_DIR

docker compose up -d

echo ""
echo "Gitea deployment finished"