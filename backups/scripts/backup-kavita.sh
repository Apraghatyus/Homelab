#!/bin/bash
source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh
BACKUP_DIR="/mnt/nas/backups/docker/kavita"
DATA_DIR="/home/apraghatyus/homelab/kavita/config"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"
if tar -czf "${BACKUP_DIR}/kavita_config_${DATE}.tar.gz" -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")" 2>/dev/null; then
    cd "$BACKUP_DIR" && ls -t kavita_config_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm --
    notify_backup "Kavita" "ok" "kavita_config_${DATE}.tar.gz"
else
    notify_backup "Kavita" "fail" "Error creando backup de config"
fi
