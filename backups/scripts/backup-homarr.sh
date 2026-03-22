#!/bin/bash
source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

BACKUP_DIR="/home/apraghatyus/homelab/backups/homarr"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

docker cp homarr:/appdata/db/db.sqlite "$BACKUP_DIR/homarr_${DATE}.db"

if [ $? -eq 0 ]; then
    cd "$BACKUP_DIR" && ls -t homarr_*.db 2>/dev/null | tail -n +11 | xargs -r rm --
    notify_backup "Homarr" "ok" "homarr_${DATE}.db"
else
    notify_backup "Homarr" "fail" "Error copiando base de datos"
fi
