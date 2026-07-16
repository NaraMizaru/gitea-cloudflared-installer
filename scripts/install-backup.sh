#!/bin/bash

set -e

echo "Installing backup script"

cp scripts/backup-gitea.sh \
/usr/local/bin/backup-gitea.sh

chmod +x \
/usr/local/bin/backup-gitea.sh

echo "Setting cron"

(crontab -l 2>/dev/null; \
echo "$BACKUP_SCHEDULE BACKUP_DIR=$BACKUP_DIR BACKUP_RETENTION_DAYS=$BACKUP_RETENTION_DAYS /usr/local/bin/backup-gitea.sh") \
| crontab -

echo "Backup script installed"