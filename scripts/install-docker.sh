#!/bin/bash

set -e


echo "Checking Docker installation..."

if command -v docker >/dev/null 2>&1
then
    echo "Docker already installed"
else
    echo "Installing Docker..."

    apt update
    apt install -y \
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

    apt update
    apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        gettext-base
fi

echo "Enable Docker service"

systemctl enable docker
systemctl start docker

echo "Add current user to docker group"

if ! groups $SUDO_USER | grep -q docker
then
    usermod -aG docker $SUDO_USER
fi

echo "Docker installation finished"

docker --version
docker compose version