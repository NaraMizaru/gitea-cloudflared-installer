#!/bin/bash

set -e

APP_NAME="Gitea + Cloudflared Installer"

echo "================================="
echo "$APP_NAME"
echo "================================="

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

echo "Running as root"