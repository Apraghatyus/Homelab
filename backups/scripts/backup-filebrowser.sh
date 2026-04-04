#!/bin/bash
source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

BACKUP_DIR="/mnt/nas/backups/docker/filebrowser"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MAX_BACKUPS=10

mkdir -p "$BACKUP_DIR"

docker cp filebrowser:/database/filebrowser.db "$BACKUP_DIR/filebrowser_${TIMESTAMP}.db"

if [ $? -eq 0 ]; then
    cd "$BACKUP_DIR" && ls -t filebrowser_*.db | tail -n +$((MAX_BACKUPS + 1)) | xargs -r rm
    notify_backup "FileBrowser" "ok" "filebrowser_${TIMESTAMP}.db"
else
    notify_backup "FileBrowser" "fail" "Error copiando base de datos"
fi
