#!/bin/bash

set -e

echo "=== Checking Docker ==="

if command -v docker >/dev/null 2>&1; then
    echo "Docker already installed:"
    docker --version
    exit 0
fi


echo "Installing Docker..."

apt update

apt install -y \
ca-certificates \
curl \
gnupg


curl -fsSL https://get.docker.com | sh


systemctl enable docker
systemctl start docker


echo "Docker installed:"
docker --version