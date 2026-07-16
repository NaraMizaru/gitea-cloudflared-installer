#!/bin/bash

set -e

NETWORK_NAME="git-network"
SUBNET="172.19.0.0/16"

echo "=== Setting Docker Network ==="


if docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"
then
    echo "Network ${NETWORK_NAME} already exists"
    exit 0
fi


docker network create \
    --driver bridge \
    --subnet ${SUBNET} \
    ${NETWORK_NAME}


echo "Network ${NETWORK_NAME} created"