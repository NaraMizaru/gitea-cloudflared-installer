#!/bin/bash

set -e

echo "Deploying Nginx..."

STACK_DIR="/opt/stacks/nginx"

mkdir -p "$STACK_DIR"

cp -r compose/nginx/* "$STACK_DIR"

envsubst < compose/nginx/.env.template \
> "$STACK_DIR/.env"

envsubst '$DOMAIN' < compose/nginx/conf.d/gitea.conf \
> "$STACK_DIR/conf.d/gitea.conf"

cd "$STACK_DIR"

docker compose up -d

echo "Nginx deployed"