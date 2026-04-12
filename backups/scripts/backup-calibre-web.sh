#!/bin/bash
source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh
BACKUP_DIR="/mnt/nas/backups/docker/calibre-web"
DATA_DIR="/home/apraghatyus/homelab/calibre-web/config"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"
if tar -czf "${BACKUP_DIR}/calibre-web_config_${DATE}.tar.gz" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")" 2>/dev/null; then
    cd "$BACKUP_DIR" && ls -t calibre-web_config_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm --
    notify_backup "Calibre-Web" "ok" "calibre-web_config_${DATE}.tar.gz"
else
    notify_backup "Calibre-Web" "fail" "Error creando backup de config"
fi
