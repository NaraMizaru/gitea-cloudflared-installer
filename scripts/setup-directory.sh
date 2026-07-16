#!/bin/bash

set -e

echo "=== Creating directories ==="


mkdir -p /srv/data/gitea
mkdir -p /srv/data/postgres
mkdir -p /srv/data/runner

mkdir -p /srv/backups
mkdir -p /srv/compose


mkdir -p /opt/stacks/gitea
mkdir -p /opt/stacks/runner
mkdir -p /opt/stacks/nginx/conf.d
mkdir -p /opt/stacks/cloudflared


echo "Directory created"


tree /srv || true
tree /opt/stacks || true