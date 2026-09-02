#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="/usr/local/bin/backup-gitea.sh"
CRON_JOB="$BACKUP_SCHEDULE $TARGET_SCRIPT"

# Check if script already exists and content is identical, and cron is set
SCRIPT_MATCH=false
if [ -f "$TARGET_SCRIPT" ] && cmp -s "$SCRIPT_DIR/backup-gitea.sh" "$TARGET_SCRIPT"; then
    SCRIPT_MATCH=true
fi

CRON_MATCH=false
if crontab -l 2>/dev/null | grep -Fxq "$CRON_JOB"; then
    CRON_MATCH=true
fi

if [ "$SCRIPT_MATCH" = true ] && [ "$CRON_MATCH" = true ] && [ "$1" != "--force" ]; then
    echo "Skrip backup dan jadwal cron sudah terpasang dan up-to-date. Melewati instalasi ulang."
    exit 0
fi

echo "Installing backup script..."

cp "$SCRIPT_DIR/backup-gitea.sh" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"

echo "Setting cron job..."

if crontab -l 2>/dev/null | grep -q "$TARGET_SCRIPT"; then
    (crontab -l 2>/dev/null | grep -v "$TARGET_SCRIPT"; echo "$CRON_JOB") | crontab -
else
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
fi

echo "Backup script installed"
