#!/bin/bash
source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

BACKUP_DIR="/home/apraghatyus/homelab/backups/uptime-kuma"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

docker cp uptime-kuma:/app/data/kuma.db "$BACKUP_DIR/kuma_${DATE}.db"

if [ $? -eq 0 ]; then
    ls -t "$BACKUP_DIR"/kuma_*.db 2>/dev/null | tail -n +11 | xargs -r rm
    notify_backup "Uptime Kuma" "ok" "kuma_${DATE}.db"
else
    notify_backup "Uptime Kuma" "fail" "Error copiando base de datos"
fi
