#!/bin/bash
source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

BACKUP_DIR="/mnt/nas/backups/docker/ntfy"
SOURCE_DIR="/home/apraghatyus/homelab/ntfy/data"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

cp "$SOURCE_DIR/lib/user.db" "$BACKUP_DIR/user_${DATE}.db"

if [ $? -eq 0 ]; then
    cd "$BACKUP_DIR" && ls -t user_*.db | tail -n +11 | xargs -r rm --
    notify_backup "ntfy" "ok" "user_${DATE}.db"
else
    notify_backup "ntfy" "fail" "Error copiando base de datos"
fi
