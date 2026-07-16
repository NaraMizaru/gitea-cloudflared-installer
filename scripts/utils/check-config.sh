#!/bin/bash

set -e

echo "Checking configuration..."

REQUIRED_VARS=(
DOMAIN
GITEA_VERSION
POSTGRES_VERSION
POSTGRES_DB
POSTGRES_USER
POSTGRES_PASSWORD
DOCKER_NETWORK
DOCKER_SUBNET
DATA_DIR
)

for VAR in "${REQUIRED_VARS[@]}"
do
    VALUE=${!VAR}
    if [ -z "$VALUE" ]; then
        echo "ERROR: $VAR belum diisi"
        exit 1
    fi
done

echo "Configuration OK"
