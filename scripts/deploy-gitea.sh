#!/bin/bash

set -e

echo "=== Deploy Gitea ==="


STACK_DIR="/opt/stacks/gitea"


cp compose/gitea/docker-compose.yml \
$STACK_DIR/docker-compose.yml


cp config.env.example \
$STACK_DIR/.env


cd $STACK_DIR


docker compose up -d


echo ""
echo "Gitea deployment finished"