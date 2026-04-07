#!/bin/bash
source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh

BACKUP_DIR="/mnt/nas/backups/docker/navidrome"
DATA_DIR="/home/apraghatyus/homelab/navidrome/data"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

if tar -czf "${BACKUP_DIR}/navidrome_data_${DATE}.tar.gz" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")" 2>/dev/null; then
    cd "$BACKUP_DIR" && ls -t navidrome_data_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm --
    notify_backup "Navidrome" "ok" "navidrome_data_${DATE}.tar.gz"
else
    notify_backup "Navidrome" "fail" "Error creando backup de data"
fi
