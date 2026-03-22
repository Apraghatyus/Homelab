#!/bin/bash
source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

BACKUP_DIR="/home/apraghatyus/homelab/backups/npm"
SOURCE_DB="/home/apraghatyus/homelab/npm/data/database.sqlite"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

sudo cp "$SOURCE_DB" "$BACKUP_DIR/database_${DATE}.sqlite"
sudo chown apraghatyus:apraghatyus "$BACKUP_DIR/database_${DATE}.sqlite"

if [ $? -eq 0 ]; then
    cd "$BACKUP_DIR" && ls -t database_*.sqlite | tail -n +11 | xargs -r rm --
    notify_backup "NPM" "ok" "database_${DATE}.sqlite"
else
    notify_backup "NPM" "fail" "Error copiando base de datos"
fi
