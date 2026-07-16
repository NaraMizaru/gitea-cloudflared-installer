#!/bin/bash

set -e

echo "Checking Docker network..."

if docker network ls \
    --format "{{.Name}}" \
    | grep -q "^${DOCKER_NETWORK}$"
then
    echo "Network ${DOCKER_NETWORK} already exists"
else
    echo "Creating ${DOCKER_NETWORK}"

    docker network create \
        --driver bridge \
        --subnet ${DOCKER_SUBNET} \
        ${DOCKER_NETWORK}
fi

echo "Docker network ready"
