#!/bin/bash

set -e


DATE=$(date +"%Y-%m-%d_%H-%M")
BACKUP_DIR="${BACKUP_DIR:-/srv/backups}"

echo "Starting backup $DATE"

mkdir -p \
"$BACKUP_DIR/gitea" \
"$BACKUP_DIR/postgres" \
"$BACKUP_DIR/compose"

echo "Backup Gitea data"

tar czf \
"$BACKUP_DIR/gitea/gitea_$DATE.tar.gz" \
/srv/data/gitea

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