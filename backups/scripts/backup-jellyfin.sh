#!/bin/bash
source /home/apraghatyus/homelab/backups/scripts/ntfy-notify.sh
BACKUP_DIR="/mnt/nas/backups/docker/jellyfin"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"
docker cp jellyfin:/config "$BACKUP_DIR/jellyfin_config_${DATE}"
if [ $? -eq 0 ]; then
    cd "$BACKUP_DIR" && tar czf "jellyfin_config_${DATE}.tar.gz" "jellyfin_config_${DATE}" && rm -rf "jellyfin_config_${DATE}"
    ls -t jellyfin_config_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm --
    notify_backup "Jellyfin" "ok" "jellyfin_config_${DATE}.tar.gz"
else
    notify_backup "Jellyfin" "fail" "Error copiando configuración"
fi
