#!/bin/bash

set -e


echo "Creating server directories..."


mkdir -p /opt/stacks/{gitea,runner,nginx,cloudflared}
mkdir -p /srv/data/{gitea,postgres,runner}
mkdir -p /srv/backups


echo "Directory setup completed"