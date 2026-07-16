#!/bin/bash

set -e


echo "Creating server directories..."

mkdir -p /opt/stacks/{gitea,runner,nginx,cloudflared}
mkdir -p "${DATA_DIR}"/{gitea,postgres,runner}
mkdir -p "${BACKUP_DIR}"

echo "Directory setup completed"