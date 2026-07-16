#!/bin/bash

set -e

# Load configuration if available
CONFIG_FILE="/opt/stacks/gitea/.env"
if [ -f "$CONFIG_FILE" ]; then
    set -a
    source "$CONFIG_FILE"
    set +a
fi

DATE=$(date +"%Y-%m-%d_%H-%M")
BACKUP_DIR="${BACKUP_DIR:-/srv/backups}"
DATA_DIR="${DATA_DIR:-/srv/data}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

echo "Starting backup $DATE"

mkdir -p \
"$BACKUP_DIR/gitea" \
"$BACKUP_DIR/postgres" \
"$BACKUP_DIR/compose"

echo "Backup Gitea data"

tar czf \
"$BACKUP_DIR/gitea/gitea_$DATE.tar.gz" \
"$DATA_DIR/gitea"

echo "Backup PostgreSQL"

docker exec postgres \
pg_dump \
-U "$POSTGRES_USER" \
"$POSTGRES_DB" \
> "$BACKUP_DIR/postgres/gitea_$DATE.sql"

echo "Backup compose files"

tar czf \
"$BACKUP_DIR/compose/stacks_$DATE.tar.gz" \
/opt/stacks

echo "Cleaning old backups"

find "$BACKUP_DIR" \
-type f \
-mtime +"${BACKUP_RETENTION_DAYS}" \
-delete

echo "Backup finished"
