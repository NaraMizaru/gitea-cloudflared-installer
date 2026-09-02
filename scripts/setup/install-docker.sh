#!/bin/bash

set -e

echo "Checking Docker installation..."

if command -v docker >/dev/null 2>&1; then
    echo "Docker is already installed"
else
    echo "Installing Docker..."

    apt-get update
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        gettext-base

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

    chmod a+r /etc/apt/keyrings/docker.asc

    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        gettext-base
fi

if systemctl is-active --quiet docker 2>/dev/null; then
    echo "Docker service is already running"
else
    echo "Starting & enabling Docker service..."
    systemctl enable --now docker 2>/dev/null || true
fi

if [ -n "$SUDO_USER" ]; then
    if ! id -nG "$SUDO_USER" 2>/dev/null | grep -qw docker; then
        echo "Adding $SUDO_USER to docker group..."
        usermod -aG docker "$SUDO_USER" 2>/dev/null || true
    fi
fi

echo "Docker installation check finished"

docker --version 2>/dev/null || true
docker compose version 2>/dev/null || true
