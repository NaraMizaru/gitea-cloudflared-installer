#!/bin/bash

set -e

echo "Installing backup script"

cp scripts/backup-gitea.sh \
/usr/local/bin/backup-gitea.sh

chmod +x \
/usr/local/bin/backup-gitea.sh

echo "Setting cron"

CRON_JOB="$BACKUP_SCHEDULE /usr/local/bin/backup-gitea.sh"
if crontab -l 2>/dev/null | grep -q "/usr/local/bin/backup-gitea.sh"; then
    (crontab -l 2>/dev/null | grep -v "/usr/local/bin/backup-gitea.sh"; echo "$CRON_JOB") | crontab -
else
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
fi

echo "Backup script installed"